# validate.ps1 — graph validation v2 (control flow)
# Implement Session 3.1.
#
# Scope 3.1: validate trên graph chuẩn hoá (cùng mô hình node/edge với graph.ps1), gom MỌI lỗi:
#   - schema root: name; (graph) entry/max_steps/nodes bắt buộc; max_steps > 0
#   - node: id unique + agent/input/output_key; agent .md tồn tại (tương đối projects/<name>/)
#   - edge: from/to trỏ node có thật (dangling → lỗi từng cạnh)
#   - router (type=router): ≥2 cạnh ra, mọi cạnh ra có 'when' không rỗng
#   - node thường: ≤1 cạnh ra, cạnh ra KHÔNG mang 'when'
#   - reachability: mọi node tới được từ entry
#   - key resolve: mọi {{k}} trong input là 'user_request' hoặc khớp 1 output_key
#   - CHO PHÉP control-cycle (loopy hợp lệ); chỉ CẢNH BÁO data-cycle (key có producer nhưng
#     producer không thể chạy trước trên bất kỳ đường nào → key luôn rỗng khi node chạy)
# Tương thích ngược: pipeline cũ → node/edge tuyến tính (type=work, không 'when') → cùng luật.
#
# Test-Workflow trả [ordered]@{ errors=[string[]]; warnings=[string[]] }. Direct-run & run.ps1
# in cả hai; exit = số lỗi (warning không tính vào exit). Giữ hàm thuần testable.

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib/json.ps1')

# Cùng pattern token với bridge.ps1 — cạnh dữ liệu suy ra từ chính các token này.
$script:TokenPattern = '\{\{\s*([A-Za-z0-9_]+)\s*\}\}'

# Charset hợp lệ cho node id (A-13) — đồng bộ token `{{key}}`. id ngoài tập này nhúng thẳng
# vào Mermaid (viz.ps1) sinh cú pháp hỏng câm → chặn tĩnh tại validate.
$script:IdPattern = '^[A-Za-z0-9_]+$'

# kind hợp lệ cho trial[].expect (A-16) — đồng bộ Test-TrialExpect (sandbox.ps1).
$script:TrialKinds = @('non-empty', 'contains', 'matches')

# Key reserved do bridge nạp đầu vòng đời (read-path memory, Phase M) — luôn resolve được,
# không cần producer. Khớp 3 key Get-Memory trả (engine/memory.ps1) + engine_run (wiring 5.3,
# đường tuyệt đối tới run.ps1 cho Builder, Initialize-Context nạp).
$script:ReservedKeys = @('user_request', 'mem_mistakes', 'mem_patterns', 'mem_context', 'engine_run', 'user_answer')

# Enum hợp lệ cho field `pause` trên node worker (Phase K.1). Vắng → 'none' (bất biến).
$script:PauseValues = @('none', 'always', 'ask')

function Get-PromptKeys {
    <#
    .SYNOPSIS Trả về danh sách key {{...}} (unique, giữ thứ tự) trong 1 template.
    #>
    param([Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Template)
    $keys = [System.Collections.Generic.List[string]]::new()
    foreach ($m in [regex]::Matches($Template, $script:TokenPattern)) {
        $k = $m.Groups[1].Value
        if (-not $keys.Contains($k)) { $keys.Add($k) }
    }
    return , $keys.ToArray()
}

# Get-Prop: accessor StrictMode-safe gom vào lib/json.ps1 (A-06) — đã dot-source ở đầu file.

function Get-Reachable {
    <#
    .SYNOPSIS BFS: tập node tới được từ $Start theo adjacency $Adj (id → List[to]).
    #>
    param(
        [Parameter(Mandatory)][string]$Start,
        [Parameter(Mandatory)][hashtable]$Adj
    )
    $seen  = @{}
    $queue = [System.Collections.Generic.Queue[string]]::new()
    $queue.Enqueue($Start); $seen[$Start] = $true
    while ($queue.Count -gt 0) {
        $cur = $queue.Dequeue()
        if (-not $Adj.ContainsKey($cur)) { continue }
        foreach ($to in $Adj[$cur]) {
            if (-not $seen.ContainsKey($to)) { $seen[$to] = $true; $queue.Enqueue($to) }
        }
    }
    return $seen
}

function Test-Workflow {
    <#
    .SYNOPSIS
        Validate projects/<name>/workflow.json trên graph chuẩn hoá. Gom mọi lỗi + cảnh báo.
    .DESCRIPTION
        KHÔNG dùng Get-Graph (nó throw ở lỗi cấu trúc đầu tiên) — tự đọc raw + chuẩn hoá tolerant
        để báo đủ từng lỗi. Cấu trúc node/edge khớp graph.ps1 nên luật áp cho cả pipeline lẫn graph.
    .PARAMETER ProjectDir
        Thư mục project, vd: examples/hello.
    .OUTPUTS
        [ordered]@{ errors = [string[]]; warnings = [string[]] }.
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)

    $errors   = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $done = { return [ordered]@{ errors = $errors.ToArray(); warnings = $warnings.ToArray() } }

    if (-not (Test-Path -LiteralPath $ProjectDir)) {
        $errors.Add("project dir không tồn tại: $ProjectDir")
        return & $done
    }

    $wfPath = Join-Path $ProjectDir 'workflow.json'
    try { $wf = Read-Json $wfPath }
    catch {
        $errors.Add("không đọc được workflow.json — $($_.Exception.Message)")
        return & $done
    }

    # --- name bắt buộc ---
    if ([string]::IsNullOrWhiteSpace((Get-Prop $wf 'name'))) {
        $errors.Add("workflow.json thiếu field bắt buộc 'name'")
    }

    $hasPipeline = $wf.PSObject.Properties.Name -contains 'pipeline'
    $hasNodes    = $wf.PSObject.Properties.Name -contains 'nodes'

    # --- Chuẩn hoá tolerant về {nodes[], edges[], entry, maxSteps} (gom lỗi, không throw) ---
    $nodes = [System.Collections.Generic.List[object]]::new()   # @{ id; agent; type; input; output_key }
    $edges = [System.Collections.Generic.List[object]]::new()   # @{ from; to; when }
    $entry = $null
    $maxStepsProvided = $true   # pipeline luôn có (suy ra)

    if ($hasPipeline) {
        $pipe = @($wf.pipeline)
        if ($pipe.Count -eq 0) {
            $errors.Add("pipeline rỗng — cần ít nhất 1 step")
            return & $done
        }
        $idx = 0
        foreach ($s in $pipe) {
            $id = Get-Prop $s 'step'
            foreach ($f in @('step', 'agent', 'input', 'output_key')) {
                if (-not ($s.PSObject.Properties.Name -contains $f)) {
                    $errors.Add("step #${idx} thiếu field bắt buộc '$f'")
                }
            }
            $nodes.Add([ordered]@{
                id = $id; agent = (Get-Prop $s 'agent'); type = 'work'
                input = (Get-Prop $s 'input'); output_key = (Get-Prop $s 'output_key')
                memory_write = (Get-Prop $s 'memory_write')
            })
            $idx++
        }
        for ($i = 0; $i -lt ($pipe.Count - 1); $i++) {
            $edges.Add([ordered]@{ from = (Get-Prop $pipe[$i] 'step'); to = (Get-Prop $pipe[$i + 1] 'step'); when = $null })
        }
        $entry    = Get-Prop $pipe[0] 'step'
        $maxSteps = $pipe.Count
    }
    elseif ($hasNodes) {
        $entry = Get-Prop $wf 'entry'
        if ([string]::IsNullOrWhiteSpace($entry)) {
            $errors.Add("graph thiếu field bắt buộc 'entry'")
        }
        $rawMax = Get-Prop $wf 'max_steps'
        if ($null -eq $rawMax) {
            $errors.Add("graph thiếu field bắt buộc 'max_steps' (cầu dao chống loop vô hạn)")
            $maxStepsProvided = $false
            $maxSteps = 0
        }
        elseif (-not (($rawMax -is [int]) -or ($rawMax -is [long]) -or ($rawMax -is [double] -and [math]::Floor($rawMax) -eq $rawMax))) {
            $errors.Add("max_steps phải là số nguyên (hiện: '$rawMax')")
            $maxStepsProvided = $false
            $maxSteps = 0
        }
        else {
            $maxSteps = [int]$rawMax
            if ($maxSteps -le 0) { $errors.Add("max_steps phải > 0 (hiện: $maxSteps)") }
        }

        $rawNodes = @(Get-Prop $wf 'nodes')
        if ($rawNodes.Count -eq 0) {
            $errors.Add("nodes rỗng — cần ít nhất 1 node")
            return & $done
        }
        $idx = 0
        foreach ($n in $rawNodes) {
            $id = Get-Prop $n 'id'
            $type = Get-Prop $n 'type'
            if ([string]::IsNullOrWhiteSpace($type)) { $type = 'work' }
            # J2.2: validate type — chấp nhận vắng/null→'work', 'work', 'worker', 'approval'.
            # 'router' bị REJECT (J2: gộp worker+router, routing = tính chất cạnh, không phải node).
            # Type lạ khác → lỗi rõ.
            $nodeLabel = if (-not [string]::IsNullOrWhiteSpace($id)) { "'$id'" } else { "#${idx}" }
            if ($type -eq 'router') {
                $errors.Add("node ${nodeLabel}: type 'router' đã bỏ (J2) — node có ≥2 cạnh ra tự là điểm rẽ; xoá field type")
                $type = 'work'   # treat as worker để tiếp tục validate các luật khác
            }
            elseif ($type -notin @('work', 'worker', 'approval')) {
                $errors.Add("node ${nodeLabel}: type '$type' không hợp lệ (chỉ chấp nhận 'approval' hoặc vắng/worker)")
                $type = 'work'
            }
            # Phase K.1: validate field `pause` (chính sách dừng, chỉ dành cho worker node).
            # approval node đã là gate người-duyệt — cấm gộp pause thêm vào.
            $pauseVal = Get-Prop $n 'pause'
            if ($null -ne $pauseVal -and -not [string]::IsNullOrWhiteSpace($pauseVal)) {
                if ($type -eq 'approval') {
                    $errors.Add("node ${nodeLabel}: 'pause' không được dùng trên node type 'approval' (approval đã là gate người-duyệt; dùng pause trên worker node)")
                }
                elseif ($pauseVal -notin $script:PauseValues) {
                    $errors.Add("node ${nodeLabel}: pause '$pauseVal' không hợp lệ (chỉ chấp nhận: $($script:PauseValues -join ', '))")
                }
            }

            # approval (Phase D) = gate người-duyệt, KHÔNG gọi model → chỉ cần 'id'
            # (agent/input/output_key không bắt buộc). Node khác cần đủ 4 field.
            $required = if ($type -eq 'approval') { @('id') } else { @('id', 'agent', 'input', 'output_key') }
            foreach ($f in $required) {
                if (-not ($n.PSObject.Properties.Name -contains $f)) {
                    $errors.Add("node #${idx} thiếu field bắt buộc '$f'")
                }
            }
            $nodes.Add([ordered]@{
                id = $id; agent = (Get-Prop $n 'agent'); type = $type
                input = (Get-Prop $n 'input'); output_key = (Get-Prop $n 'output_key')
                memory_write = (Get-Prop $n 'memory_write')
                pause = $pauseVal
            })
            $idx++
        }
        foreach ($e in @(Get-Prop $wf 'edges' | Where-Object { $null -ne $_ })) {
            $edges.Add([ordered]@{ from = (Get-Prop $e 'from'); to = (Get-Prop $e 'to'); when = (Get-Prop $e 'when') })
        }
    }
    else {
        $errors.Add("workflow.json phải có 'pipeline' (flat) hoặc 'nodes' (graph)")
        return & $done
    }

    # --- nodeById + id unique + agent tồn tại + thu output_key → producer ---
    $nodeById   = @{}
    $producers  = @{}   # output_key → List[id]
    foreach ($n in $nodes) {
        if ([string]::IsNullOrWhiteSpace($n.id)) { continue }   # field-missing đã báo ở trên
        # A-13: id chỉ [A-Za-z0-9_] (đồng bộ token) — chặn id phá Mermaid câm.
        if ($n.id -notmatch $script:IdPattern) {
            $errors.Add("id node '$($n.id)' chứa ký tự không hợp lệ (chỉ cho phép chữ, số, '_')")
        }
        if ($nodeById.ContainsKey($n.id)) {
            $errors.Add("id node trùng: '$($n.id)'")
        }
        else {
            $nodeById[$n.id] = $n
        }
        # A-04: output_key không được trùng reserved-key (bridge nạp đầu vòng đời) — runtime
        # sẽ ghi đè ngầm (workflow.ps1) khiến token reserved nhận giá trị sai → fail sớm tại đây.
        if ($n.output_key -in $script:ReservedKeys) {
            $errors.Add("node '$($n.id)': output_key '$($n.output_key)' trùng reserved-key (cấm: $($script:ReservedKeys -join ', '))")
        }
        if (-not [string]::IsNullOrWhiteSpace($n.agent)) {
            if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir $n.agent))) {
                $errors.Add("node '$($n.id)' agent không tồn tại: $($n.agent)")
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($n.output_key)) {
            if (-not $producers.ContainsKey($n.output_key)) { $producers[$n.output_key] = [System.Collections.Generic.List[string]]::new() }
            $producers[$n.output_key].Add($n.id)
        }
    }

    # --- entry trỏ node có thật ---
    if (-not [string]::IsNullOrWhiteSpace($entry) -and -not $nodeById.ContainsKey($entry)) {
        $errors.Add("entry '$entry' không khớp node nào")
    }

    # --- edges: dangling + dựng adjacency (chỉ cạnh hợp lệ) + đếm cạnh ra mỗi node ---
    $adj    = @{}
    $outEdg = @{}   # id → List[edge] (cạnh ra hợp lệ)
    foreach ($id in $nodeById.Keys) { $adj[$id] = [System.Collections.Generic.List[string]]::new(); $outEdg[$id] = [System.Collections.Generic.List[object]]::new() }
    foreach ($e in $edges) {
        $okFrom = -not [string]::IsNullOrWhiteSpace($e.from) -and $nodeById.ContainsKey($e.from)
        $okTo   = -not [string]::IsNullOrWhiteSpace($e.to)   -and $nodeById.ContainsKey($e.to)
        if (-not $okFrom) { $errors.Add("cạnh có 'from' không tồn tại: '$($e.from)' (to '$($e.to)')") }
        if (-not $okTo)   { $errors.Add("cạnh có 'to' không tồn tại: '$($e.to)' (from '$($e.from)')") }
        if ($okFrom -and $okTo) { $adj[$e.from].Add($e.to); $outEdg[$e.from].Add($e) }
    }

    # --- Luật cạnh ra (J2: routing = số cạnh ra / outdeg, không phải type) ---
    # approval GIỮ NGUYÊN. Worker (type vắng/'work'/'worker' — type='router' đã bị REJECT ở trên):
    #   outdeg ≥ 2 → điểm rẽ tự động: mọi cạnh ra cần 'when' (engine chọn theo nhãn dòng cuối).
    #   outdeg ≤ 1 → đường thẳng: không bắt buộc 'when'.
    foreach ($id in $nodeById.Keys) {
        $node = $nodeById[$id]
        $outs = $outEdg[$id]
        if ($node.type -eq 'approval') {
            # Gate (Phase D): phải tiếp tục sau khi duyệt → ≥1 cạnh ra. Nếu khai nhiều cạnh
            # (vd approve/reject) thì mỗi cạnh cần nhãn 'when' = quyết định (như router);
            # 1 cạnh ra duy nhất ('tiếp tục') không bắt buộc 'when'.
            if ($outs.Count -lt 1) {
                $errors.Add("approval '$id' cần ≥1 cạnh ra (gate phải tiếp tục sau khi duyệt)")
            }
            elseif ($outs.Count -ge 2) {
                foreach ($e in $outs) {
                    if ([string]::IsNullOrWhiteSpace($e.when)) {
                        $errors.Add("approval '$id' có nhiều cạnh ra — cạnh '$id→$($e.to)' cần nhãn 'when' (quyết định: approve/reject/...)")
                    }
                }
            }
        }
        else {
            # Worker (type vắng/'work'/'worker'): outdeg ≥ 2 → điểm rẽ, mọi cạnh cần 'when'.
            # outdeg ≤ 1 → đường thẳng, không kiểm when.
            if (@($outs).Count -ge 2) {
                foreach ($e in $outs) {
                    if ([string]::IsNullOrWhiteSpace($e.when)) {
                        $errors.Add("node '$id' có $(@($outs).Count) cạnh ra (điểm rẽ) nhưng cạnh '$id→$($e.to)' thiếu nhãn 'when'")
                    }
                }
            }
        }
    }

    # --- memory_write (nếu có) ∈ {mistakes,patterns,global,context} (Phase M-B) ---
    $validMemTypes = @('mistakes', 'patterns', 'global', 'context')
    foreach ($n in $nodes) {
        if ([string]::IsNullOrWhiteSpace($n.memory_write)) { continue }
        if ($n.memory_write -notin $validMemTypes) {
            $errors.Add("node '$($n.id)': memory_write '$($n.memory_write)' không hợp lệ (cần: $($validMemTypes -join ', '))")
        }
    }

    # --- Reachability từ entry ---
    if (-not [string]::IsNullOrWhiteSpace($entry) -and $nodeById.ContainsKey($entry)) {
        $reach = Get-Reachable -Start $entry -Adj $adj
        foreach ($id in $nodeById.Keys) {
            if (-not $reach.ContainsKey($id)) {
                $errors.Add("node '$id' không tới được từ entry '$entry'")
            }
        }
    }

    # --- Key resolve + cảnh báo data-cycle ---
    foreach ($id in $nodeById.Keys) {
        $node = $nodeById[$id]
        if ([string]::IsNullOrWhiteSpace($node.input)) { continue }
        foreach ($k in (Get-PromptKeys $node.input)) {
            if ($k -in $script:ReservedKeys) { continue }
            if (-not $producers.ContainsKey($k)) {
                # J.3 (Phase J): <base>_payload = auto-inject bởi engine cho router nodes (dynamic key).
                # Nếu có router với output_key=<baseKey> → valid (KHÔNG error, KHÔNG warn).
                # Nếu KHÔNG có → WARN (không phá workflow hợp lệ hiện có; exit = 0 như cũ).
                if ($k -match '^(.+)_payload$') {
                    $baseKey = $Matches[1]
                    # J2.1: kiểm bằng outdeg≥2 thay vì type='router' (routing = số cạnh ra).
                    $hasBranchForBase = $false
                    foreach ($n2 in $nodes) {
                        if (-not [string]::IsNullOrWhiteSpace($n2.id) -and
                            $n2.output_key -eq $baseKey -and
                            $outEdg.ContainsKey($n2.id) -and
                            @($outEdg[$n2.id]).Count -ge 2) {
                            $hasBranchForBase = $true; break
                        }
                    }
                    if (-not $hasBranchForBase) {
                        $warnings.Add("node '$id': key '{{$k}}' dùng _payload nhưng không có node rẽ nhánh (outdeg≥2) nào với output_key='$baseKey' — engine sẽ resolve '' (pre-seed); kiểm tra cấu trúc workflow.")
                    }
                    continue   # _payload dynamic — không error, bỏ qua data-cycle check
                }
                $errors.Add("node '$id': key '{{$k}}' không resolve được (không phải 'user_request' và không khớp output_key nào)")
                continue
            }
            # data-cycle: có producer cho key nhưng không producer nào chạy được TRƯỚC node này
            # (không producer P nào có đường P→…→id) → key luôn rỗng khi node chạy. Loop-feedback
            # (loopy: verdict→build) KHÔNG dính vì back-edge cho phép verdict tới build.
            $reachable = $false
            foreach ($p in $producers[$k]) {
                if ($p -eq $id) { continue }   # tự dùng output mình → cần cycle, xét producer khác trước
                $r = Get-Reachable -Start $p -Adj $adj
                if ($r.ContainsKey($id)) { $reachable = $true; break }
            }
            if (-not $reachable) {
                $warnings.Add("node '$id': key '{{$k}}' có thể chưa sẵn — không producer nào chạy trước trên đường đi (data-cycle?)")
            }
        }
    }

    # --- trial[] schema (A-16): bắt tĩnh (mock, free) trước khi trial chạy THẬT đốt token ---
    # observe ∈ output_keys; expect.kind ∈ {non-empty,contains,matches}; value bắt buộc khi contains/matches.
    if ($wf.PSObject.Properties.Name -contains 'trial' -and $null -ne $wf.trial) {
        $tIdx = 0
        foreach ($t in @($wf.trial | Where-Object { $null -ne $_ })) {
            $observe = Get-Prop $t 'observe'
            if ([string]::IsNullOrWhiteSpace($observe)) {
                $errors.Add("trial #${tIdx} thiếu 'observe'")
            }
            elseif (-not $producers.ContainsKey($observe)) {
                $errors.Add("trial #${tIdx}: observe '$observe' không khớp output_key nào")
            }
            $expect = Get-Prop $t 'expect'
            if ($null -eq $expect) {
                $errors.Add("trial #${tIdx} thiếu 'expect'")
            }
            else {
                $kind = Get-Prop $expect 'kind'
                if ([string]::IsNullOrWhiteSpace($kind)) {
                    $errors.Add("trial #${tIdx}: expect thiếu 'kind' (cần: $($script:TrialKinds -join ', '))")
                }
                elseif ($kind -notin $script:TrialKinds) {
                    $errors.Add("trial #${tIdx}: expect.kind '$kind' không hợp lệ (cần: $($script:TrialKinds -join ', '))")
                }
                elseif ($kind -in @('contains', 'matches') -and [string]::IsNullOrEmpty([string](Get-Prop $expect 'value'))) {
                    $errors.Add("trial #${tIdx}: expect.kind '$kind' cần 'value' không rỗng")
                }
            }
            $tIdx++
        }
    }

    return & $done
}

# --- In kết quả + trả exit code (dùng chung cho direct-run và run.ps1) ---
function Write-ValidateResult {
    param(
        [Parameter(Mandatory, Position = 0)]$Result,
        [Parameter(Mandatory, Position = 1)][string]$Label
    )
    $errs  = @($Result.errors)
    $warns = @($Result.warnings)
    foreach ($w in $warns) { Write-Host "  ⚠ $w" -ForegroundColor Yellow }
    if ($errs.Count -eq 0) {
        $suffix = if ($warns.Count -gt 0) { " ($($warns.Count) cảnh báo)" } else { '' }
        Write-Host "✓ workflow hợp lệ: $Label$suffix" -ForegroundColor Green
        return 0
    }
    Write-Host "✗ $($errs.Count) lỗi trong ${Label}:" -ForegroundColor Red
    foreach ($e in $errs) { Write-Host "  - $e" -ForegroundColor Red }
    return $errs.Count
}

# --- Chạy trực tiếp (không dot-source): in lỗi + exit = số lỗi ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 1) {
        Write-Host "Cách dùng: ./validate.ps1 <projectDir>" -ForegroundColor Yellow
        exit 2
    }
    $result = Test-Workflow $args[0]
    exit (Write-ValidateResult $result $args[0])
}

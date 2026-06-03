# workflow.ps1 — executor v2: single-cursor walk theo đồ thị (graph.ps1), state theo lượt thăm.
# Implement Session 1.2 · router edge-select Session 1.3 · loop/merge Phase 2 · resume Session 4.1.
#
# Scope 1.2: thay vòng `for` qua $wf.pipeline bằng CON TRỎ ĐƠN đi theo cạnh (single-cursor walk).
#   - Nguồn nodes/edges/entry/max_steps = Get-Graph (graph.ps1) → một executor cho cả pipeline & graph.
#   - Chọn cạnh kế: lấy cạnh ra ĐẦU TIÊN (adj[id][0]); 0 cạnh ra → terminal → run done.
#     (Router — chọn cạnh theo nhãn `when` — để Session 1.3; ở 1.2 router cũng đi cạnh đầu.)
#   - State v2 (QĐ-4): visits[] = [{ seq, node, iter, status, output_key, error }] + path[] đã đi.
#     Output mới nhất → <output_key>.txt (latest-wins, nguồn bridge); lịch sử → <seq>-<node>.out.txt.
#   - max_steps guard: đếm node đã thực thi; chạm trần mà còn cursor → state `failed`, exit≠0.
#   - Pre-seed mọi output_key = "" → loop-feedback ({{verdict}} trong build trước vòng đầu) resolve
#     được ở entry path (QĐ-3, ghi chú 0.1). Token không khớp output_key nào vẫn throw như cũ.
#   - Tái dùng Invoke-Claude + Resolve-Prompt nguyên trạng.
# Scope 4.1: -Resume nạp lại context từ <output_key>.txt + visits đã 'done', tiếp từ node đang dở;
#   -OnStepFail scriptblock = hook fail-loop cho HQ Tester dùng sau.

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib/json.ps1')
. (Join-Path $here 'lib/log.ps1')
. (Join-Path $here 'lib/claude.ps1')
. (Join-Path $here 'graph.ps1')    # Get-Graph + Get-Prop (StrictMode-safe property access)
. (Join-Path $here 'bridge.ps1')
. (Join-Path $here 'status.ps1')   # Get-LatestRunDir / Get-RunState (resume)
. (Join-Path $here 'memory.ps1')   # Get-Memory (read-path: nạp {{mem_*}} vào context)
. (Join-Path $here 'events.ps1')   # Write-Event (D.1: events.ndjson — kênh quan sát additive)

function Initialize-Context {
    <#
    .SYNOPSIS
        Context khởi đầu: user_request + mọi output_key của graph pre-seed = "".
    .DESCRIPTION
        Pre-seed cho phép loop-feedback ({{verdict}} trong build trước khi verdict chạy lần đầu)
        resolve thành rỗng ở entry path thay vì throw. Token KHÔNG khớp output_key nào (typo)
        vẫn throw trong Resolve-Prompt — net an toàn còn nguyên.

        $ProjectDir (tuỳ chọn): có → merge memory by-type + cap N (Get-Memory) vào context dưới
        key {{mem_mistakes}}/{{mem_patterns}}/{{mem_context}}. OUTPUT_KEY LUÔN THẮNG: nếu workflow
        lỡ đặt output_key trùng `mem_*` (reserved), giữ output_key + cảnh báo, bỏ qua memory.
    #>
    param(
        [Parameter(Mandatory)]$Graph,
        [Parameter(Mandatory)][AllowEmptyString()][string]$UserRequest,
        [string]$ProjectDir
    )
    $ctx = @{ user_request = $UserRequest }
    # Reserved key {{engine_run}} (wiring 5.3): đường dẫn tuyệt đối tới run.ps1 — Builder chạy
    # trong cwd=sandbox (depth biến thiên) cần gọi `pwsh {{engine_run}} build ...` ổn định.
    $ctx['engine_run'] = (Join-Path $PSScriptRoot 'run.ps1')
    foreach ($n in $Graph.nodes) {
        $k = $n.output_key
        if (-not [string]::IsNullOrWhiteSpace($k) -and -not $ctx.ContainsKey($k)) { $ctx[$k] = '' }
        # J.3: Pre-seed <output_key>_payload = "" cho router nodes (loop-feedback an toàn như output_key).
        if ($n.type -eq 'router' -and -not [string]::IsNullOrWhiteSpace($k)) {
            $pk = "${k}_payload"
            if (-not $ctx.ContainsKey($pk)) { $ctx[$pk] = '' }
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($ProjectDir)) {
        $mem = Get-Memory $ProjectDir
        foreach ($key in @($mem.Keys)) {
            if ($ctx.ContainsKey($key)) {
                Write-Warning "Initialize-Context: memory key '$key' trùng output_key (reserved mem_*) — giữ output_key, bỏ qua memory."
                continue
            }
            $ctx[$key] = $mem[$key]
        }
    }
    return $ctx
}

function ConvertTo-RouterLabel {
    <#
    .SYNOPSIS
        Chuẩn hoá output router → nhãn quyết định (QĐ-2): dòng CUỐI không rỗng, trim, lowercase.
    .DESCRIPTION
        Router agent in nhãn ở dòng cuối (vd `gt10000`). Lấy dòng không-trắng cuối cùng để bỏ
        qua dòng trắng đuôi. Output rỗng/toàn trắng → '' (sẽ không khớp `when` nào → fail rõ).
    .OUTPUTS [string] nhãn đã chuẩn hoá.
    #>
    param([AllowEmptyString()][string]$Output)
    $lines = @($Output -split "`r?`n")
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if (-not [string]::IsNullOrWhiteSpace($lines[$i])) {
            # Nhãn router là token đơn [a-z0-9_]; LLM hay bọc markdown/quote (`enough`, **build**,
            # "pass"). Strip ký tự bao non-token ở 2 đầu để khớp `when` (mock label sạch → bất biến).
            $label = $lines[$i].Trim()
            $label = $label -replace '^[^A-Za-z0-9_]+', '' -replace '[^A-Za-z0-9_]+$', ''
            return $label.ToLowerInvariant()
        }
    }
    return ''
}

function Select-NextNode {
    <#
    .SYNOPSIS
        Chọn node kế tiếp từ $NodeId. Node thường: cạnh ra đầu tiên. Router: cạnh khớp nhãn.
    .DESCRIPTION
        - 0 cạnh ra → $null (terminal → run done).
        - Node type 'router' (Session 1.3): chuẩn hoá $Output → nhãn (ConvertTo-RouterLabel),
          khớp với `when` của các cạnh ra (cũng trim/lowercase). Khớp 1 → đi cạnh đó.
          KHÔNG khớp nhãn nào → throw liệt kê `when` hợp lệ (QĐ-2; cùng họ tín hiệu blocked).
          Logic chọn cạnh nằm TRONG engine — agent chỉ trả nhãn.
        - Node thường: cạnh ra đầu tiên (giữ thứ tự khai báo, adj[id][0]).
    .OUTPUTS [string] id node kế, hoặc $null nếu terminal.
    #>
    param(
        [Parameter(Mandatory)]$Graph,
        [Parameter(Mandatory)][string]$NodeId,
        [AllowEmptyString()][string]$Output = ''
    )
    $outs = @($Graph.adj[$NodeId])
    if ($outs.Count -eq 0) { return $null }

    # nodeById/adj giữ node & edge dạng ordered hashtable → truy cập key bằng member access
    # trực tiếp ($node.type / $e.when), KHÔNG dùng Get-Prop (PSObject.Properties không liệt kê
    # key của hashtable, sẽ trả $null nhầm → router rơi xuống nhánh node thường).
    $node = $Graph.nodeById[$NodeId]
    if ($node.type -eq 'router') {
        $label = ConvertTo-RouterLabel $Output
        foreach ($e in $outs) {
            $when = $e.when
            if (-not [string]::IsNullOrWhiteSpace($when) -and $when.Trim().ToLowerInvariant() -eq $label) {
                return $e.to
            }
        }
        $valid = @($outs | ForEach-Object { $_.when } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ', '
        throw "Router '$NodeId' trả nhãn '$label' không khớp 'when' nào trong { $valid }"
    }

    return $outs[0].to
}

function Get-RouterChoices {
    <#
    .SYNOPSIS
        Trả tập nhãn 'when' hợp lệ của cạnh ra từ node $NodeId trong $Graph.
    .DESCRIPTION
        Phase J.1 (CD-2): Nguồn sự thật nhãn router = edges/when từ graph — agent .md KHÔNG
        cần hardcode nhãn. Lọc bỏ blank, lowercase, sort-unique → chuỗi bơm vào suffix real-mode.
        Dot-source-safe: hàm thuần, không tự exec khi dot-source.
    .OUTPUTS [string[]] tập nhãn đã chuẩn hoá (có thể rỗng nếu không có cạnh ra hoặc mọi when blank).
    #>
    param(
        [Parameter(Mandatory)]$Graph,
        [Parameter(Mandatory)][string]$NodeId
    )
    $outs = @($Graph.adj[$NodeId])
    $labels = @(
        $outs |
        ForEach-Object { $_.when } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Sort-Object -Unique
    )
    return $labels
}

function Write-RouteIssue {
    <#
    .SYNOPSIS
        Ghi 1 entry NDJSON vào issue-queue tập trung khi router real-mode trả nhãn sai.
    .DESCRIPTION
        Phase J.2 (CD-2): Deterministic, KHÔNG gọi model. Append 1 dòng JSON vào
        company/issues/route-issues.ndjson (gitignored qua issues/*.ndjson).
        Tạo thư mục nếu chưa có. Fields: ts, run_id, node, raw_output, valid_choices[], label_extracted.
        Dot-source-safe: hàm thuần, không tự exec khi dot-source.
    #>
    param(
        [Parameter(Mandatory)][string]$RunDir,
        [Parameter(Mandatory)][string]$NodeId,
        [Parameter(Mandatory)][AllowEmptyString()][string]$RawOutput,
        [Parameter(Mandatory)][AllowNull()][string[]]$ValidChoices
    )
    $issueFile = Join-Path $PSScriptRoot '../issues/route-issues.ndjson'
    $issueDir  = Split-Path -Parent $issueFile
    if (-not (Test-Path -LiteralPath $issueDir)) {
        New-Item -ItemType Directory -Path $issueDir -Force | Out-Null
    }
    $runId = Split-Path -Leaf $RunDir
    $choicesArr = @(if ($null -ne $ValidChoices) { $ValidChoices } else { @() })
    $entry = [ordered]@{
        ts             = (Get-Date).ToString('o')
        run_id         = [string]$runId
        node           = [string]$NodeId
        raw_output     = [string]$RawOutput
        valid_choices  = $choicesArr
        label_extracted = (ConvertTo-RouterLabel $RawOutput)
    }
    $line = $entry | ConvertTo-Json -Compress -Depth 5
    Add-Content -LiteralPath $issueFile -Value $line -Encoding utf8NoBOM
}

function Get-RouterPayload {
    <#
    .SYNOPSIS
        Tách phần payload từ router output (giao thức 2-phần J.3).
    .DESCRIPTION
        Phase J.3 (CD-2): Router output = payload tự do + dòng cuối = nhãn route.
        Trả phần payload = toàn bộ output TRỪ dòng không-trắng cuối cùng (nhãn route).
        Tương thích ngược: router chỉ in nhãn đơn → payload = "" (pre-seed bình thường).
        Mock router chỉ in nhãn → payload = "" → bất biến.
        Dot-source-safe: hàm thuần, không tự exec khi dot-source.
    .OUTPUTS [string] payload (có thể "" nếu chỉ có 1 dòng không-trắng).
    #>
    param([AllowEmptyString()][string]$Output)
    $lines = @($Output -split "`r?`n")
    # Tìm index của dòng không-trắng cuối cùng (chính là nhãn route)
    $lastIdx = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if (-not [string]::IsNullOrWhiteSpace($lines[$i])) { $lastIdx = $i; break }
    }
    # Không có dòng nào, hoặc nhãn nằm ở dòng đầu tiên → không có payload
    if ($lastIdx -le 0) { return '' }
    # Payload = các dòng trước nhãn, bỏ blank cuối
    return ($lines[0..($lastIdx - 1)] -join "`n").TrimEnd()
}

function Get-AgentFrontmatter {
    <#
    .SYNOPSIS
        Parse YAML frontmatter của 1 agent .md → hashtable @{ allowedTools; permission_mode; model }.
    .DESCRIPTION
        Wiring Phase 5.1 (additive): đọc 3 field cấu hình headless để executor truyền cho claude CLI.
        - `allowedTools`: 3 dạng (A-03, C.9) → string space-joined "Write Edit Read"
          (định dạng `--allowedTools` của claude CLI):
            · inline list `[Write, Edit, Read]`
            · scalar / comma `Write, Edit`
            · YAML multi-line list (value rỗng + các dòng `- item` kế tiếp)
          Value rỗng mà KHÔNG có `- item` nào theo sau → cảnh báo (không rỗng-im-lặng).
        - `permission_mode`, `model`: lấy string thô (trim).
        File KHÔNG có frontmatter (hoặc thiếu field) → field đó = $null → executor giữ hành vi cũ
        (Invoke-Claude bỏ qua param rỗng; mock-path không đụng tới chúng → bất biến).
    .OUTPUTS [hashtable] 3 key, value $null nếu vắng.
    #>
    param([Parameter(Mandatory)][string]$AgentPath)

    $fm = @{ allowedTools = $null; permission_mode = $null; model = $null }
    if (-not (Test-Path -LiteralPath $AgentPath)) { return $fm }

    $lines = @(Get-Content -LiteralPath $AgentPath -Encoding utf8)
    # Frontmatter = block giữa cặp '---' đầu tiên; dòng đầu (bỏ trắng) phải là '---'.
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($lines[$i])) { continue }
        if ($lines[$i].Trim() -eq '---') { $start = $i }
        break
    }
    if ($start -lt 0) { return $fm }

    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { break }
        $kv = $lines[$i] -split ':', 2
        if ($kv.Count -ne 2) { continue }
        $key = $kv[0].Trim()
        $val = $kv[1].Trim()
        switch ($key) {
            'allowedTools' {
                $v = $val.Trim()
                if ($v.StartsWith('[') -and $v.EndsWith(']')) {
                    # inline list [a, b, c]
                    $inner = $v.Substring(1, $v.Length - 2)
                    $items = @($inner -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                }
                elseif ($v) {
                    # scalar hoặc comma-separated inline
                    $items = @($v -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                }
                else {
                    # A-03: value rỗng → YAML multi-line list, gom các dòng '- item' kế tiếp
                    # (dừng ở dòng key kế / '---' / hết). Các dòng này khi loop chính chạm tới
                    # sẽ bị bỏ qua (split ':' không cho cặp key:value hợp lệ → không hại).
                    $items = @()
                    for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                        $t = $lines[$j].Trim()
                        if ($t -eq '---') { break }
                        if ([string]::IsNullOrWhiteSpace($t)) { continue }
                        if ($t -eq '-' -or $t.StartsWith('- ')) {
                            $item = $t.Substring(1).Trim()
                            if ($item) { $items += $item }
                        }
                        else { break }
                    }
                    if ($items.Count -eq 0) {
                        Write-Warning "Get-AgentFrontmatter: 'allowedTools' trong '$AgentPath' rỗng hoặc cú pháp YAML không hỗ trợ (chỉ inline list [a,b], scalar, hoặc multi-line '- item')."
                    }
                }
                if ($items.Count -gt 0) { $fm.allowedTools = ($items -join ' ') }
            }
            'permission_mode' { if ($val) { $fm.permission_mode = $val } }
            'model'           { if ($val) { $fm.model = $val } }
        }
    }
    return $fm
}

function Test-FrontmatterPermissions {
    <#
    .SYNOPSIS
        CC-a (C.9): tầng kiểm frontmatter TĨNH (free, mock-time) — bắt divergence quyền ghi-file
        TRƯỚC khi đốt token real.
    .DESCRIPTION
        Mock echo prompt + bỏ qua frontmatter → dry-run gate chỉ chứng minh topology graph tới
        terminal, KHÔNG chứng minh agent đủ quyền ghi file. Hàm này đối chiếu tĩnh: node tuyên ý
        ghi-file (`permission_mode: acceptEdits`) PHẢI có `Write`/`Edit` trong `allowedTools` —
        nếu thiếu → sẽ fail real-run (không ghi được file). Trả danh sách cảnh báo (rỗng = ok).
        Chỉ cảnh báo, KHÔNG fail (theo plan C.9) — caller in warning trước real.
    .OUTPUTS [string[]] mỗi phần tử = 1 dòng cảnh báo (rỗng nếu không có divergence).
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)

    $warnings = @()
    $graph = Get-Graph $ProjectDir
    foreach ($n in @($graph.nodes)) {
        $agent = $n.agent
        if ([string]::IsNullOrWhiteSpace($agent)) { continue }
        $fm = Get-AgentFrontmatter (Join-Path $ProjectDir $agent)
        if ($fm.permission_mode -eq 'acceptEdits') {
            $tools = if ($fm.allowedTools) { $fm.allowedTools } else { '' }
            if ($tools -notmatch '\b(Write|Edit)\b') {
                $warnings += "node '$($n.id)' [$agent]: permission_mode=acceptEdits nhưng allowedTools KHÔNG có Write/Edit — sẽ fail real-run khi ghi file."
            }
        }
    }
    return $warnings
}

function Invoke-Workflow {
    <#
    .SYNOPSIS
        Chạy workflow project theo single-cursor walk trên graph chuẩn hoá (Get-Graph) →
        ghi artifact mỗi run vào projects/<name>/.runs/<timestamp>/ (state v2, QĐ-4).
    .DESCRIPTION
        -Resume: tiếp tục run dở/failed mới nhất. Nạp lại output các lượt 'done' vào context
        (latest-wins từ <output_key>.txt), tiếp từ node đang dở. UserRequest lấy từ state cũ.

        -OnStepFail: scriptblock nhận @{ node; agent; error; runDir; seq; iter } khi 1 node fail —
        điểm hook fail-loop của HQ Tester quan sát/sửa rồi resume.
    .OUTPUTS Đường dẫn thư mục run.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,   # vd: examples/hello
        [Parameter(Position = 1)][string]$UserRequest,
        [switch]$Mock,
        [string]$Model,
        [switch]$Resume,
        [string]$Decision = '',    # D.3: approve|reject|<label> khi resume từ approval gate
        [switch]$AutoApprove,      # D.4: tự duyệt gate happy-path (cho selftest/CI mock offline)
        [scriptblock]$OnStepFail
    )

    if (-not (Test-Path -LiteralPath $ProjectDir)) {
        throw "Invoke-Workflow: project dir không tồn tại: $ProjectDir"
    }

    # Get-Graph chuẩn hoá cả pipeline cũ lẫn graph + validate cấu trúc (throw nếu hỏng).
    $graph = Get-Graph $ProjectDir

    $iterCount = @{}   # node id → số lần đã thăm (cho field iter)
    $visits    = [System.Collections.Generic.List[object]]::new()

    if ($Resume) {
        # --- RESUME: tái dùng run dở mới nhất ---
        $runDir  = Get-LatestRunDir $ProjectDir
        $runsDir = Split-Path -Parent $runDir
        $logFile = Join-Path $runDir 'run.log'
        $state   = Get-RunState $runDir

        if ($state.status -eq 'done') {
            Write-Log "Run mới nhất đã 'done' — không có gì để resume." -Level INFO -LogFile $logFile
            return $runDir
        }

        $rawVisits = @(Get-Prop $state 'visits')
        if ($rawVisits.Count -eq 0) {
            throw "Invoke-Workflow: state.json không có 'visits' (run format cũ?) — không resume được."
        }

        $UserRequest = $state.request
        $context     = Initialize-Context $graph $UserRequest $ProjectDir

        # Nạp lại output mọi key có file trên đĩa (latest-wins đã ghi sẵn).
        foreach ($n in $graph.nodes) {
            $k = $n.output_key
            if ([string]::IsNullOrWhiteSpace($k)) { continue }
            $outPath = Join-Path $runDir "$k.txt"
            if (Test-Path -LiteralPath $outPath) {
                $restored = (Get-Content -LiteralPath $outPath -Raw -Encoding utf8)
                $context[$k] = $restored
                # J.3: Restore _payload cho router nodes khi resume (tính lại từ output đã lưu).
                if ($n.type -eq 'router') {
                    $context["${k}_payload"] = Get-RouterPayload $restored
                }
            }
        }

        # Giữ lại các lượt 'done', dựng lại iterCount + seq từ chúng.
        $seq = 0
        foreach ($v in $rawVisits) {
            if ($v.status -ne 'done') { continue }
            $visits.Add([ordered]@{
                seq = $v.seq; node = $v.node; iter = $v.iter
                status = 'done'; output_key = $v.output_key; error = $null
            })
            $prev = if ($iterCount.ContainsKey($v.node)) { $iterCount[$v.node] } else { 0 }
            $iterCount[$v.node] = $prev + 1
            if ($v.seq -gt $seq) { $seq = $v.seq }
        }

        # D.3: Awaiting resume — resolve decision → cursor trước khi chạy tiếp sau approval gate.
        $awaitingResume = $false
        $awaitNode      = $null
        $decLabel       = ''
        if ($state.status -eq 'awaiting') {
            $awaitData = Get-Prop $state 'awaiting'
            if ($awaitData) {
                $awaitNode = $awaitData.node
                # Đưa lượt 'awaiting' vào visits với status='done' (người đã duyệt → node coi như xong).
                foreach ($av in @($rawVisits | Where-Object { $_.status -eq 'awaiting' })) {
                    $visits.Add([ordered]@{ seq = $av.seq; node = $av.node; iter = $av.iter; status = 'done'; output_key = $av.output_key; error = $null })
                    $prevIter2 = if ($iterCount.ContainsKey($av.node)) { $iterCount[$av.node] } else { 0 }
                    $iterCount[$av.node] = $prevIter2 + 1
                    if ($av.seq -gt $seq) { $seq = $av.seq }
                }
                # Resolve decision → next cursor
                $decLabel  = if ([string]::IsNullOrWhiteSpace($Decision)) { 'approve' } else { $Decision.Trim().ToLowerInvariant() }
                $awaitOuts = @($graph.adj[$awaitNode])
                if ($awaitOuts.Count -eq 0) { throw "Resume awaiting: approval '$awaitNode' không có cạnh ra." }
                if ($awaitOuts.Count -eq 1) {
                    $cursor = $awaitOuts[0].to
                } else {
                    $matchedTo = $null
                    foreach ($e in $awaitOuts) {
                        if ($e.when -and $e.when.Trim().ToLowerInvariant() -eq $decLabel) { $matchedTo = $e.to; break }
                    }
                    if (-not $matchedTo) {
                        $valid = (@($awaitOuts | Where-Object { $_.when } | ForEach-Object { $_.when })) -join ', '
                        throw "Resume awaiting: decision '$decLabel' không khớp 'when' nào của approval '$awaitNode'. Hợp lệ: { $valid }"
                    }
                    $cursor = $matchedTo
                }
                $awaitingResume = $true
            }
        }

        if (-not $awaitingResume) {
            # Cursor: lượt chưa-done đầu tiên → retry node đó; nếu mọi lượt done → đi cạnh sau node done cuối.
            $pending = @($rawVisits | Where-Object { $_.status -ne 'done' })
            if ($pending.Count -gt 0) {
                $cursor = $pending[0].node
            }
            elseif ($visits.Count -gt 0) {
                # Mọi lượt 'done' nhưng run chưa 'done' → đi cạnh sau node done cuối. Nếu node đó là
                # router, truyền lại output của nó (đã nạp vào context theo output_key) để chọn nhánh.
                $lastNode = $visits[$visits.Count - 1].node
                $lastKey  = $visits[$visits.Count - 1].output_key
                $lastOut  = if (-not [string]::IsNullOrWhiteSpace($lastKey) -and $context.ContainsKey($lastKey)) { [string]$context[$lastKey] } else { '' }
                $cursor   = Select-NextNode $graph $lastNode $lastOut
            }
            else {
                $cursor = $graph.entry
            }
        }

        # Reset run-level về sạch trước khi chạy tiếp.
        $state.status   = 'running'
        $state.finished = $null
        if ($state.PSObject.Properties.Name -contains 'error') { $state.error = $null }
        # D.3: xoá field 'awaiting' khi resume từ gate (set null để JSON vẫn ghi được).
        if ($awaitingResume) {
            if ($state -is [System.Collections.IDictionary]) {
                if ($state.Contains('awaiting')) { [void]$state.Remove('awaiting') }
            } else {
                if ($state.PSObject.Properties.Name -contains 'awaiting') { $state.awaiting = $null }
            }
        }
        $state.visits = @($visits)
        Write-Json (Join-Path $runDir 'state.json') $state
        Write-Log "Resume run → $runDir (tiếp từ node '$cursor', seq=$seq)" -Level INFO -LogFile $logFile
        if ($awaitingResume) {
            Write-Event $runDir 'resumed' @{ node = $awaitNode; decision = $decLabel; cursor = $cursor }
        }
    }
    else {
        # --- RUN MỚI ---
        if ([string]::IsNullOrEmpty($UserRequest)) {
            throw "Invoke-Workflow: cần <UserRequest> khi chạy mới (hoặc dùng -Resume)."
        }

        $ts      = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $runsDir = Join-Path $ProjectDir '.runs'
        $runDir  = Join-Path $runsDir $ts
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $logFile = Join-Path $runDir 'run.log'

        Write-Log "Run '$($graph.name)' bắt đầu → $runDir (entry=$($graph.entry), max_steps=$($graph.max_steps))" -Level INFO -LogFile $logFile

        $state = [ordered]@{
            name      = $graph.name
            request   = $UserRequest
            started   = (Get-Date).ToString('o')
            finished  = $null
            status    = 'running'
            error     = $null
            entry     = $graph.entry
            max_steps = $graph.max_steps
            path      = @()
            visits    = @()
        }
        Write-Json (Join-Path $runDir 'state.json') $state

        $context = Initialize-Context $graph $UserRequest $ProjectDir
        $seq     = 0
        $cursor  = $graph.entry
    }

    $statePath = Join-Path $runDir 'state.json'

    # D.1: phát run_start (entry+request). Resume cũng phát → nối tiếp events.ndjson (seq tự tăng).
    Write-Event $runDir 'run_start' @{ name = $graph.name; entry = $graph.entry; request = $UserRequest; resume = [bool]$Resume }

    # --- Single-cursor walk ---
    while ($null -ne $cursor) {

        # Cầu dao max_steps: đã thực thi $seq node, còn cursor → vượt trần = fail an toàn (QĐ-3).
        if ($seq -ge $graph.max_steps) {
            $msg = "vượt max_steps ($($graph.max_steps)) — nghi loop không hội tụ (cursor đang ở '$cursor')"
            $state.status   = 'failed'
            $state.error    = $msg
            $state.finished = (Get-Date).ToString('o')
            $state.visits   = @($visits)
            Write-Json $statePath $state
            Write-Log "Run dừng — $msg" -Level ERROR -LogFile $logFile
            Write-Json (Join-Path $runsDir 'latest.json') ([ordered]@{ run = (Split-Path -Leaf $runDir); status = 'failed' })
            Write-Event $runDir 'run_end' @{ status = 'failed'; node = $cursor; error = $msg }
            throw "Workflow '$($graph.name)' $msg (resume: run.ps1 resume $($graph.name))"
        }

        $node = $graph.nodeById[$cursor]
        $seq++
        $prevIter = if ($iterCount.ContainsKey($cursor)) { $iterCount[$cursor] } else { 0 }
        $iter = $prevIter + 1
        $iterCount[$cursor] = $iter

        $visit = [ordered]@{
            seq = $seq; node = $cursor; iter = $iter
            status = 'running'; output_key = $node.output_key; error = $null
        }
        $visits.Add($visit)
        $state.visits = @($visits)
        Write-Json $statePath $state
        Write-Log "[$seq] node '$cursor' (iter $iter) [$($node.agent)] → running" -Level INFO -LogFile $logFile
        Write-Event $runDir 'node_start' @{ node = $cursor; agent = $node.agent; iter = $iter; step = $seq }

        # D.3: Approval gate — dừng walk, chờ người duyệt (không gọi model).
        if ($node.type -eq 'approval') {
            $nodePromptText = if (-not [string]::IsNullOrWhiteSpace($node.prompt)) { [string]$node.prompt } else { '' }
            $choices = @(@($graph.adj[$cursor]) | ForEach-Object { if (-not [string]::IsNullOrWhiteSpace($_.when)) { $_.when } else { 'approve' } })

            # D.4: -AutoApprove → tự chọn cạnh happy-path (approve / cạnh đầu), không dừng.
            if ($AutoApprove) {
                $autoOuts = @($graph.adj[$cursor])
                if ($autoOuts.Count -eq 0) { throw "AutoApprove: approval '$cursor' không có cạnh ra." }
                $autoNext = $null
                foreach ($ae in $autoOuts) {
                    if ([string]::IsNullOrWhiteSpace($ae.when) -or $ae.when.Trim().ToLowerInvariant() -eq 'approve') {
                        $autoNext = $ae.to; break
                    }
                }
                if (-not $autoNext) { $autoNext = $autoOuts[0].to }
                $visit.status = 'done'
                $state.path   = @($state.path) + $cursor
                $state.visits = @($visits)
                Write-Json $statePath $state
                Write-Log "[$seq] node '$cursor' (approval) → auto-approve → '$autoNext'" -Level INFO -LogFile $logFile
                Write-Event $runDir 'node_done' @{ node = $cursor; step = $seq; auto_approved = $true }
                $cursor = $autoNext
                continue
            }

            $visit.status = 'awaiting'
            $awaitInfo = [ordered]@{ node = $cursor; prompt = $nodePromptText; choices = $choices }
            if ($state -is [System.Collections.IDictionary]) {
                $state['awaiting'] = $awaitInfo
            } else {
                $state | Add-Member -NotePropertyName 'awaiting' -NotePropertyValue $awaitInfo -Force
            }
            $state.status   = 'awaiting'
            $state.finished = $null
            $state.visits   = @($visits)
            Write-Json $statePath $state
            Write-Log "[$seq] node '$cursor' (approval) → awaiting. Resume: run.ps1 resume $($graph.name) -Decision approve|reject" -Level INFO -LogFile $logFile
            Write-Json (Join-Path $runsDir 'latest.json') ([ordered]@{ run = (Split-Path -Leaf $runDir); status = 'awaiting' })
            Write-Event $runDir 'awaiting' @{ node = $cursor; prompt = $nodePromptText; choices = $choices; step = $seq }
            return $runDir
        }

        $agentPath = Join-Path $ProjectDir $node.agent
        $prompt    = Resolve-Prompt $node.input $context

        # J.1 (CD-2): Bơm suffix "chọn MỘT nhãn" vào prompt router real-mode.
        # Mock-path bất biến: ENGINE_MOCK_ROUTER trả nhãn trực tiếp, không cần suffix.
        # Guard if (-not $Mock) để đảm bảo mock-path không bị ảnh hưởng.
        if ($node.type -eq 'router' -and -not $Mock) {
            $routerChoices = Get-RouterChoices $graph $cursor
            if ($routerChoices.Count -gt 0) {
                $choiceStr = $routerChoices -join ' | '
                $prompt += "`n`n---`nChọn đúng MỘT nhãn sau (in nhãn ở dòng cuối):`n{ $choiceStr }"
            }
        }

        $base = "$seq-$cursor"
        Set-Content -LiteralPath (Join-Path $runDir "$base.prompt.txt") -Value $prompt -Encoding utf8

        # Wiring 5.1: đọc frontmatter agent → truyền cờ headless cho claude CLI.
        # frontmatter `model:` override -Model global (global là fallback). Field vắng = $null →
        # Invoke-Claude bỏ qua. Mock-path KHÔNG dùng các cờ này → output mock bất biến.
        $fm        = Get-AgentFrontmatter $agentPath
        $nodeModel = if (-not [string]::IsNullOrWhiteSpace($fm.model)) { $fm.model } else { $Model }

        # Wiring 5.3: cwd của claude subprocess = project dir (resolve tuyệt đối). Khi harness chạy
        # real trong sandbox, agent ghi-file (Builder) dùng path cwd-relative `projects/<name>` →
        # branch rơi vào <sandbox>/projects/ (Find-GeneratedBranch tìm đúng). Mock bỏ qua WorkingDir.
        $projAbs   = (Resolve-Path -LiteralPath $ProjectDir).Path

        try {
            $output = Invoke-Claude $prompt $agentPath -Mock:$Mock -Model $nodeModel -AllowedTools $fm.allowedTools -PermissionMode $fm.permission_mode -WorkingDir $projAbs -NodeId $cursor -RunDir $runDir
        }
        catch {
            $errMsg = $_.Exception.Message
            $visit.status = 'failed'
            $visit.error  = $errMsg
            $state.status   = 'failed'
            $state.error    = "Node '$cursor' (seq $seq) failed: $errMsg"
            $state.finished = (Get-Date).ToString('o')
            $state.visits   = @($visits)
            Write-Json $statePath $state
            Write-Log "[$seq] node '$cursor' FAILED — $errMsg" -Level ERROR -LogFile $logFile
            Write-Json (Join-Path $runsDir 'latest.json') ([ordered]@{ run = (Split-Path -Leaf $runDir); status = 'failed' })
            Write-Event $runDir 'run_end' @{ status = 'failed'; node = $cursor; error = $errMsg }

            if ($OnStepFail) {
                try {
                    & $OnStepFail @{ node = $cursor; agent = $node.agent; error = $errMsg; runDir = $runDir; seq = $seq; iter = $iter }
                }
                catch {
                    Write-Log "OnStepFail hook ném lỗi — bỏ qua: $($_.Exception.Message)" -Level WARN -LogFile $logFile
                }
            }
            throw "Workflow '$($graph.name)' dừng tại node '$cursor' (seq $seq): $errMsg (resume: run.ps1 resume $($graph.name))"
        }

        # J.2: Validate nhãn router real-mode → Write-RouteIssue + throw fail-fast (KHÔNG retry).
        # Guard if (-not $Mock): mock-path bất biến (ENGINE_MOCK_ROUTER trả nhãn hợp lệ, skip validate).
        if ($node.type -eq 'router' -and -not $Mock) {
            $routerLabel  = ConvertTo-RouterLabel $output
            $validChoices = Get-RouterChoices $graph $cursor
            if ($validChoices.Count -gt 0 -and $routerLabel -notin $validChoices) {
                Write-RouteIssue -RunDir $runDir -NodeId $cursor -RawOutput $output -ValidChoices $validChoices
                # GIỮ NGUYÊN text throw (tương thích ngược app/tester parse)
                $valid = @($graph.adj[$cursor] | ForEach-Object { $_.when } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ', '
                throw "Router '$cursor' trả nhãn '$routerLabel' không khớp 'when' nào trong { $valid }"
            }
        }

        # Lịch sử từng lượt + output mới nhất (latest-wins, nguồn bridge) + nạp vào context.
        Set-Content -LiteralPath (Join-Path $runDir "$base.out.txt") -Value $output -Encoding utf8
        # D.1: node_output mang NỘI DUNG output ĐẦY ĐỦ (đóng #3 "(N chars)" → full content).
        Write-Event $runDir 'node_output' @{ node = $cursor; agent = $node.agent; step = $seq; output = [string]$output }
        if (-not [string]::IsNullOrWhiteSpace($node.output_key)) {
            Set-Content -LiteralPath (Join-Path $runDir "$($node.output_key).txt") -Value $output -Encoding utf8
            $context[$node.output_key] = $output
            # J.3: Auto-store <output_key>_payload cho router nodes. Node successor dùng {{<key>_payload}}.
            # Tương thích ngược: router chỉ in nhãn → Get-RouterPayload = "" → pre-seed bình thường.
            # Áp dụng cả Mock (payload = "" cho mock router 1-dòng) và real-mode.
            if ($node.type -eq 'router') {
                $context["$($node.output_key)_payload"] = Get-RouterPayload $output
            }
        }

        # Write-path (Phase M-B): node `record` có 'memory_write' → append output vào đúng tầng store.
        # Additive — node thường (memory_write = $null) bỏ qua; lỗi ghi memory không phá run (chỉ WARN).
        $memType = $node.memory_write
        if (-not [string]::IsNullOrWhiteSpace($memType)) {
            try {
                $memPath = Write-MemoryEntry $ProjectDir $memType $output -Slug $cursor
                Write-Log "[$seq] node '$cursor' memory_write '$memType' → $memPath" -Level INFO -LogFile $logFile
            }
            catch {
                Write-Log "[$seq] node '$cursor' memory_write LỖI — $($_.Exception.Message)" -Level WARN -LogFile $logFile
            }
        }

        $visit.status = 'done'
        $state.path   = @($state.path) + $cursor
        $state.visits = @($visits)
        Write-Json $statePath $state
        Write-Log "[$seq] node '$cursor' → done ($($output.Length) chars)" -Level INFO -LogFile $logFile
        Write-Event $runDir 'node_done' @{ node = $cursor; agent = $node.agent; step = $seq; output_key = $node.output_key; chars = $output.Length }

        $cursor = Select-NextNode $graph $cursor $output
    }

    $state.status   = 'done'
    $state.error    = $null
    $state.finished = (Get-Date).ToString('o')
    $state.visits   = @($visits)
    Write-Json $statePath $state
    Write-Json (Join-Path $runsDir 'latest.json') ([ordered]@{ run = (Split-Path -Leaf $runDir); status = $state.status })
    Write-Log "Run '$($graph.name)' xong → $($visits.Count) lượt thăm, path: $((@($state.path)) -join ' → ')" -Level INFO -LogFile $logFile
    $terminal = if (@($state.path).Count -gt 0) { @($state.path)[-1] } else { '' }
    Write-Event $runDir 'run_end' @{ status = $state.status; terminal = $terminal; visits = $visits.Count }
    return $runDir
}

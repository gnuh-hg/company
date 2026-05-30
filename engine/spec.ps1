# spec.ps1 — lớp spec HQ (Phase 3-A): validator máy-đọc-được cho 2 schema.
# Implement Session 3-A.1.
#
# 2 hàm thuần testable (gom MỌI lỗi, KHÔNG throw — reason máy-đọc-được, chỉ đúng field sai):
#   Test-PlanSchema $Plan  → kiểm plan-as-data (đầu ra Planner; schema ở brain-model.md §Plan-as-data).
#   Test-BuildSpec  $Spec  → kiểm build-spec (đầu ra CTO; schema ở hq/build-spec.md).
# Cả hai trả [ordered]@{ ok = [bool]; errors = [string[]] }. ok = (errors.Count -eq 0).
#
# Đây là gate AUTHOR-TIME của HQ (validate-trước-khi-build), KHÔNG phải engine guard runtime
# (QĐ C-2: engine coi plan-as-data là text mờ). Builder engine Invoke-BuildSpec (A.2) gọi
# Test-BuildSpec TRƯỚC khi ghi file.
#
# Surface lệnh: A.1 CHƯA wire vào run.ps1 (lệnh `build` là A.2). Direct-run để test thủ công:
#   ./spec.ps1 plan      <plan.json>
#   ./spec.ps1 buildspec <spec.json>

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $here     # company/
. (Join-Path $here 'lib/json.ps1')
. (Join-Path $here 'pattern.ps1')        # Expand-Pattern (build-time stamp) cho Invoke-BuildSpec
. (Join-Path $here 'validate.ps1')       # Test-Workflow (A-20: build-time validate graph vừa ghi)

# Kind hợp lệ cho trial[].expect (đồng bộ Test-TrialExpect trong sandbox.ps1, Phase 2-B).
$script:TrialKinds = @('non-empty', 'contains', 'matches')

# Get-Prop: accessor StrictMode-safe gom vào lib/json.ps1 (A-06) — đã dot-source ở đầu file.
# (A-19: placeholder '__P__' không còn khai ở đây — quy tắc stamp 1 nguồn trong Expand-Pattern.)

function Test-HasProp {
    <#
    .SYNOPSIS True nếu object có khai property $Name (kể cả giá trị null/rỗng).
    #>
    param($Obj, [Parameter(Mandatory)][string]$Name)
    return ($null -ne $Obj -and $Obj.PSObject -and ($Obj.PSObject.Properties.Name -contains $Name))
}

function Get-CatalogRoles {
    <#
    .SYNOPSIS Tập tên vai hợp lệ = tên file catalog/*.md (trừ README). Tính lười từ thư mục.
    #>
    $dir = Join-Path $repoRoot 'catalog'
    $set = @{}
    if (Test-Path -LiteralPath $dir) {
        foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.md' -File) {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            if ($base -ieq 'README') { continue }
            $set[$base] = $true
        }
    }
    return $set
}

function Get-PatternNames {
    <#
    .SYNOPSIS Tập tên pattern hợp lệ = tên file patterns/*.json. Tính lười từ thư mục.
    #>
    $dir = Join-Path $repoRoot 'patterns'
    $set = @{}
    if (Test-Path -LiteralPath $dir) {
        foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.json' -File) {
            $set[[System.IO.Path]::GetFileNameWithoutExtension($f.Name)] = $true
        }
    }
    return $set
}

function Get-StampedPatternNodeIds {
    <#
    .SYNOPSIS
        Đọc fragment patterns/<Name>.json → trả id node sau khi stamp ('__P__x' → '<Prefix>_x').
        Dùng để biết tập node id mà entry/edges của build-spec được phép trỏ. Trả @() nếu
        fragment thiếu/hỏng (lỗi 'pattern không tồn tại' do Test-BuildSpec báo riêng).
    .NOTES
        A-19: stamp qua chính Expand-Pattern (1 nguồn quy tắc stamp, đồng bộ Invoke-BuildSpec) —
        KHÔNG tự String.Replace nữa, tránh 2 bản logic stamp lệch nhau.
    #>
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Prefix)
    $path = Join-Path (Join-Path $repoRoot 'patterns') "$Name.json"
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    try { $frag = Read-Json $path } catch { return @() }
    try { $expanded = Expand-Pattern $frag $Prefix } catch { return @() }
    $ids = [System.Collections.Generic.List[string]]::new()
    foreach ($n in @($expanded.nodes)) {
        $id = $n['id']
        if (-not [string]::IsNullOrWhiteSpace($id)) { $ids.Add([string]$id) }
    }
    return , $ids.ToArray()
}

function Test-PlanSchema {
    <#
    .SYNOPSIS
        Kiểm shape plan-as-data (đầu ra Planner). Gom mọi lỗi, không throw.
    .DESCRIPTION
        Field bắt buộc: 'goal' (string non-empty), 'revision' (số ≥ 0), 'steps[]' (≥1, mỗi phần tử
        có 'action' non-empty), 'done_criteria[]' (≥1, mỗi phần tử có 'verify' non-empty),
        'open_questions[]' (mảng — rỗng hợp lệ = "đủ rõ"). Schema gốc: brain-model.md §Plan-as-data.
    .PARAMETER Plan
        Object plan-as-data đã parse (PSCustomObject). Direct-run wrapper đọc file → parse.
    .OUTPUTS
        [ordered]@{ ok = [bool]; errors = [string[]] }.
    #>
    param([Parameter(Mandatory, Position = 0)]$Plan)

    $errors = [System.Collections.Generic.List[string]]::new()
    $done = { return [ordered]@{ ok = ($errors.Count -eq 0); errors = $errors.ToArray() } }

    if ($null -eq $Plan) { $errors.Add("plan là null/không parse được"); return & $done }

    # --- goal ---
    if (-not (Test-HasProp $Plan 'goal')) {
        $errors.Add("thiếu field bắt buộc 'goal'")
    }
    elseif ([string]::IsNullOrWhiteSpace((Get-Prop $Plan 'goal'))) {
        $errors.Add("field 'goal' rỗng (cần mục tiêu 1 câu)")
    }

    # --- revision (số ≥ 0) ---
    if (-not (Test-HasProp $Plan 'revision')) {
        $errors.Add("thiếu field bắt buộc 'revision'")
    }
    else {
        $rev = Get-Prop $Plan 'revision'
        $isInt = ($rev -is [int]) -or ($rev -is [long]) -or ($rev -is [double] -and [math]::Floor($rev) -eq $rev)
        if (-not $isInt -or [double]$rev -lt 0) {
            $errors.Add("field 'revision' phải là số nguyên ≥ 0 (hiện: '$rev')")
        }
    }

    # --- steps[] (≥1, mỗi phần tử có action non-empty) ---
    if (-not (Test-HasProp $Plan 'steps')) {
        $errors.Add("thiếu field bắt buộc 'steps' (mảng)")
    }
    else {
        $steps = @(Get-Prop $Plan 'steps')
        if ($steps.Count -eq 0) {
            $errors.Add("'steps' rỗng — cần ít nhất 1 step")
        }
        else {
            $i = 0
            foreach ($s in $steps) {
                if (-not (Test-HasProp $s 'action') -or [string]::IsNullOrWhiteSpace((Get-Prop $s 'action'))) {
                    $errors.Add("steps[$i] thiếu/rỗng 'action'")
                }
                $i++
            }
        }
    }

    # --- done_criteria[] (≥1, mỗi phần tử có verify non-empty) ---
    if (-not (Test-HasProp $Plan 'done_criteria')) {
        $errors.Add("thiếu field bắt buộc 'done_criteria' (mảng)")
    }
    else {
        $dc = @(Get-Prop $Plan 'done_criteria')
        if ($dc.Count -eq 0) {
            $errors.Add("'done_criteria' rỗng — cần ít nhất 1 tiêu chí")
        }
        else {
            $i = 0
            foreach ($c in $dc) {
                if (-not (Test-HasProp $c 'verify') -or [string]::IsNullOrWhiteSpace((Get-Prop $c 'verify'))) {
                    $errors.Add("done_criteria[$i] thiếu/rỗng 'verify' (cần CÁCH kiểm đo được)")
                }
                $i++
            }
        }
    }

    # --- open_questions[] phải khai (mảng, rỗng hợp lệ) ---
    if (-not (Test-HasProp $Plan 'open_questions')) {
        $errors.Add("thiếu field bắt buộc 'open_questions' (mảng; rỗng = đủ rõ)")
    }

    return & $done
}

function Test-BuildSpec {
    <#
    .SYNOPSIS
        Kiểm shape build-spec (đầu ra CTO). Gom mọi lỗi, không throw. Schema: hq/build-spec.md.
    .DESCRIPTION
        Bắt buộc: name (non-empty); entry (∈ node id); max_steps (số > 0); roles[] (≥1, id unique
        + role ∈ catalog/*.md + output_key non-empty); edges[] (from/to ∈ node id). Optional:
        patterns[] (name ∈ patterns/*.json + prefix non-empty); trial[] (expect.kind ∈ TrialKinds,
        value bắt buộc với contains/matches). Tập node id = roles[].id ∪ node pattern đã stamp.
    .PARAMETER Spec
        Object build-spec đã parse (PSCustomObject).
    .OUTPUTS
        [ordered]@{ ok = [bool]; errors = [string[]] }.
    #>
    param([Parameter(Mandatory, Position = 0)]$Spec)

    $errors = [System.Collections.Generic.List[string]]::new()
    $done = { return [ordered]@{ ok = ($errors.Count -eq 0); errors = $errors.ToArray() } }

    if ($null -eq $Spec) { $errors.Add("build-spec là null/không parse được"); return & $done }

    # --- name ---
    if ([string]::IsNullOrWhiteSpace((Get-Prop $Spec 'name'))) {
        $errors.Add("thiếu/rỗng field bắt buộc 'name'")
    }

    # --- max_steps (số > 0) ---
    if (-not (Test-HasProp $Spec 'max_steps')) {
        $errors.Add("thiếu field bắt buộc 'max_steps'")
    }
    else {
        $ms = Get-Prop $Spec 'max_steps'
        $msInt = ($ms -is [int]) -or ($ms -is [long]) -or ($ms -is [double] -and [math]::Floor($ms) -eq $ms)
        if (-not $msInt -or [double]$ms -le 0) {
            $errors.Add("field 'max_steps' phải là số nguyên > 0 (hiện: '$ms')")
        }
    }

    # --- roles[]: bắt buộc, ≥1, id unique + role ∈ catalog + output_key non-empty ---
    $catalog  = Get-CatalogRoles
    $nodeIds  = @{}   # id → true (tập node id để check entry/edges)
    if (-not (Test-HasProp $Spec 'roles')) {
        $errors.Add("thiếu field bắt buộc 'roles' (mảng)")
    }
    else {
        $roles = @(Get-Prop $Spec 'roles')
        if ($roles.Count -eq 0) {
            $errors.Add("'roles' rỗng — cần ít nhất 1 vai")
        }
        $i = 0
        foreach ($r in $roles) {
            $rid = Get-Prop $r 'id'
            if ([string]::IsNullOrWhiteSpace($rid)) {
                $errors.Add("roles[$i] thiếu/rỗng 'id'")
            }
            elseif ($nodeIds.ContainsKey($rid)) {
                $errors.Add("roles[$i] id trùng: '$rid'")
            }
            else {
                $nodeIds[$rid] = $true
            }
            $role = Get-Prop $r 'role'
            if ([string]::IsNullOrWhiteSpace($role)) {
                $errors.Add("roles[$i] (id '$rid') thiếu/rỗng 'role'")
            }
            elseif (-not $catalog.ContainsKey($role)) {
                $errors.Add("roles[$i] (id '$rid') role '$role' không có trong catalog/ (vai hợp lệ: $(($catalog.Keys | Sort-Object) -join ', '))")
            }
            if ([string]::IsNullOrWhiteSpace((Get-Prop $r 'output_key'))) {
                $errors.Add("roles[$i] (id '$rid') thiếu/rỗng 'output_key'")
            }
            if (-not (Test-HasProp $r 'input')) {
                $errors.Add("roles[$i] (id '$rid') thiếu 'input'")
            }
            $i++
        }
    }

    # --- patterns[] (optional): name ∈ patterns/ + prefix non-empty; gom node id đã stamp ---
    $patNames = Get-PatternNames
    if (Test-HasProp $Spec 'patterns') {
        $pats = @(Get-Prop $Spec 'patterns')
        $i = 0
        foreach ($p in $pats) {
            $pname  = Get-Prop $p 'name'
            $prefix = Get-Prop $p 'prefix'
            if ([string]::IsNullOrWhiteSpace($prefix)) {
                $errors.Add("patterns[$i] thiếu/rỗng 'prefix'")
            }
            if ([string]::IsNullOrWhiteSpace($pname)) {
                $errors.Add("patterns[$i] thiếu/rỗng 'name'")
            }
            elseif (-not $patNames.ContainsKey($pname)) {
                $errors.Add("patterns[$i] name '$pname' không có trong patterns/ (pattern hợp lệ: $(($patNames.Keys | Sort-Object) -join ', '))")
            }
            elseif (-not [string]::IsNullOrWhiteSpace($prefix)) {
                foreach ($sid in (Get-StampedPatternNodeIds -Name $pname -Prefix $prefix)) {
                    if ($nodeIds.ContainsKey($sid)) {
                        $errors.Add("patterns[$i] node stamp '$sid' đụng id đã có (đổi prefix)")
                    }
                    else { $nodeIds[$sid] = $true }
                }
            }
            $i++
        }
    }

    # --- entry ∈ tập node id ---
    $entry = Get-Prop $Spec 'entry'
    if ([string]::IsNullOrWhiteSpace($entry)) {
        $errors.Add("thiếu/rỗng field bắt buộc 'entry'")
    }
    elseif (-not $nodeIds.ContainsKey($entry)) {
        $errors.Add("entry '$entry' không khớp node id nào (roles[].id hoặc node pattern đã stamp)")
    }

    # --- edges[]: bắt buộc, from/to ∈ tập node id ---
    if (-not (Test-HasProp $Spec 'edges')) {
        $errors.Add("thiếu field bắt buộc 'edges' (mảng)")
    }
    else {
        $edges = @(Get-Prop $Spec 'edges')
        $i = 0
        foreach ($e in $edges) {
            $from = Get-Prop $e 'from'
            $to   = Get-Prop $e 'to'
            if ([string]::IsNullOrWhiteSpace($from) -or -not $nodeIds.ContainsKey($from)) {
                $errors.Add("edges[$i] 'from'='$from' không trỏ node id nào")
            }
            if ([string]::IsNullOrWhiteSpace($to) -or -not $nodeIds.ContainsKey($to)) {
                $errors.Add("edges[$i] 'to'='$to' không trỏ node id nào")
            }
            $i++
        }
    }

    # --- trial[] (optional): observe non-empty + expect.kind ∈ TrialKinds (+ value cho contains/matches) ---
    if (Test-HasProp $Spec 'trial') {
        $trials = @(Get-Prop $Spec 'trial')
        $i = 0
        foreach ($t in $trials) {
            if ([string]::IsNullOrWhiteSpace((Get-Prop $t 'observe'))) {
                $errors.Add("trial[$i] thiếu/rỗng 'observe'")
            }
            $expect = Get-Prop $t 'expect'
            if ($null -eq $expect) {
                $errors.Add("trial[$i] thiếu 'expect'")
            }
            else {
                $kind = Get-Prop $expect 'kind'
                if ([string]::IsNullOrWhiteSpace($kind) -or $kind -notin $script:TrialKinds) {
                    $errors.Add("trial[$i] expect.kind '$kind' không hợp lệ (cần: $($script:TrialKinds -join ', '))")
                }
                elseif ($kind -in @('contains', 'matches') -and [string]::IsNullOrWhiteSpace((Get-Prop $expect 'value'))) {
                    $errors.Add("trial[$i] expect.kind '$kind' cần 'value' không rỗng")
                }
            }
            $i++
        }
    }

    return & $done
}

function New-PatternStubContent {
    <#
    .SYNOPSIS
        Sinh nội dung stub agent .md cho 1 node pattern đã stamp (node scaffolding KHÔNG
        thuộc catalog). Deterministic, chỉ-prompt. Router → in 1 dòng nhãn; work → thực thi gọn.
        Phase 3 sinh stub để workflow chạy được; vai catalog thật chỉ gắn cho roles[].
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$Id,
        [Parameter(Mandatory, Position = 1)][string]$Type,
        [Parameter(Mandatory, Position = 2)][string]$Pattern
    )
    if ($Type -eq 'router') {
        return @"
# Agent: $Id (pattern-stamped router — $Pattern)

Bạn là agent **router** trong pattern ``$Pattern`` (Builder stamp tự sinh, Phase 3-A.2).
Đọc input, kết luận, in **đúng một dòng** là nhãn route (vd ``pass`` / ``fail``).
Engine khớp dòng cuối với ``when`` của cạnh ra. (Test mock dùng ENGINE_MOCK_ROUTER.)
"@
    }
    return @"
# Agent: $Id (pattern-stamped node — $Pattern)

Node scaffolding sinh từ pattern ``$Pattern`` (Builder stamp tự sinh, Phase 3-A.2).
Thực thi một việc của node theo input bridge ``{{key}}``, trả output gọn cho downstream.
"@
}

function Invoke-BuildSpec {
    <#
    .SYNOPSIS
        Builder engine: build-spec hợp lệ → cây chi nhánh (agents/<id>.md + workflow.json).
        Gần-deterministic (copy vai catalog + stamp pattern + nối edge). Validate-trước-khi-ghi.
    .DESCRIPTION
        Đây là LỚP ENGINE thay agent Builder thực thi phần nguy hiểm (ghi file) một cách
        xác định — KHÔNG phải engine guard runtime. Agent `builder` (3-B) chỉ *gọi* lệnh này
        (`run.ps1 build`) + patch sau đó; CTO ra spec, Builder không tự thiết kế.
        Trình tự:
          1. Test-BuildSpec TRƯỚC — fail → throw kèm reason, KHÔNG tạo/ghi gì.
          2. Tạo <OutDir>/agents/.
          3. roles[] → copy catalog/<role>.md → agents/<id>.md + node (id/agent/input/output_key).
          4. patterns[] → Expand-Pattern (stamp __P__x→<prefix>_x) → node pattern + edge nội-pattern;
             mỗi node pattern sinh stub agents/<stamped-id>.md (không thuộc catalog).
          5. edges[] của spec (+ edge nội-pattern) → workflow.edges; trial[] top-level (Tester P2 đọc).
    .PARAMETER Spec   Object build-spec đã parse.
    .PARAMETER OutDir Thư mục đích (tạo mới). Caller chịu trách nhiệm chống đè.
    .OUTPUTS [string] OutDir đã ghi.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]$Spec,
        [Parameter(Mandatory, Position = 1)][string]$OutDir
    )

    # 1. Validate-trước-khi-ghi: spec hỏng → throw, không chạm filesystem.
    $check = Test-BuildSpec $Spec
    if (-not $check.ok) {
        $reason = ($check.errors | ForEach-Object { "  - $_" }) -join "`n"
        throw "Invoke-BuildSpec: build-spec không hợp lệ — KHÔNG ghi file:`n$reason"
    }

    $agentsDir = Join-Path $OutDir 'agents'
    New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

    $nodes = [System.Collections.Generic.List[object]]::new()
    $edges = [System.Collections.Generic.List[object]]::new()

    # 3. roles[] → copy vai catalog + node 1:1.
    foreach ($r in @(Get-Prop $Spec 'roles')) {
        $id   = [string](Get-Prop $r 'id')
        $role = [string](Get-Prop $r 'role')
        $src  = Join-Path (Join-Path $repoRoot 'catalog') "$role.md"
        Copy-Item -LiteralPath $src -Destination (Join-Path $agentsDir "$id.md") -Force
        $h = [ordered]@{ id = $id; agent = "agents/$id.md" }
        if (Test-HasProp $r 'input') { $h['input'] = [string](Get-Prop $r 'input') }
        $h['output_key'] = [string](Get-Prop $r 'output_key')
        $nodes.Add([pscustomobject]$h)
    }

    # 4. patterns[] → stamp fragment + stub agent cho node pattern + gom edge nội-pattern.
    if (Test-HasProp $Spec 'patterns') {
        foreach ($p in @(Get-Prop $Spec 'patterns')) {
            $pname    = [string](Get-Prop $p 'name')
            $prefix   = [string](Get-Prop $p 'prefix')
            $fragPath = Join-Path (Join-Path $repoRoot 'patterns') "$pname.json"
            $expanded = Expand-Pattern (Read-Json $fragPath) $prefix
            foreach ($n in $expanded.nodes) {
                $nid   = [string]$n['id']
                $ntype = if ($n.Contains('type')) { [string]$n['type'] } else { 'work' }
                Set-Content -LiteralPath (Join-Path $agentsDir "$nid.md") `
                    -Value (New-PatternStubContent $nid $ntype $pname) -Encoding utf8
                $h = [ordered]@{ id = $nid; agent = "agents/$nid.md" }
                if ($n.Contains('type'))       { $h['type'] = $n['type'] }
                if ($n.Contains('input'))      { $h['input'] = $n['input'] }
                if ($n.Contains('output_key')) { $h['output_key'] = $n['output_key'] }
                $nodes.Add([pscustomobject]$h)
            }
            foreach ($e in $expanded.edges) { $edges.Add($e) }
        }
    }

    # 5. edges[] nối (role↔role, role↔pattern) — edge nội-pattern đã thêm ở bước 4.
    foreach ($e in @(Get-Prop $Spec 'edges')) {
        $h = [ordered]@{ from = [string](Get-Prop $e 'from'); to = [string](Get-Prop $e 'to') }
        $when = Get-Prop $e 'when'
        if (-not [string]::IsNullOrWhiteSpace($when)) { $h['when'] = [string]$when }
        $edges.Add([pscustomobject]$h)
    }

    $wf = [ordered]@{
        name      = [string](Get-Prop $Spec 'name')
        entry     = [string](Get-Prop $Spec 'entry')
        max_steps = (Get-Prop $Spec 'max_steps')
        nodes     = @($nodes)
        edges     = @($edges)
    }
    if (Test-HasProp $Spec 'trial') { $wf['trial'] = @(Get-Prop $Spec 'trial') }

    Write-Json (Join-Path $OutDir 'workflow.json') $wf

    # 6. A-20: build-time validate — graph vừa ghi PHẢI qua Test-Workflow (bắt reachability /
    #    router-when / max_steps tại build-time, không để lộ ở `validate` riêng / real-run).
    #    Spec hợp-shape (Test-BuildSpec) nhưng graph hỏng (vd node unreachable) → throw,
    #    KHÔNG trả "thành công" giả. Files đã ghi để debug; caller (run.ps1 build) chống promote.
    $vr = Test-Workflow $OutDir
    $vErrs = @($vr.errors)
    if ($vErrs.Count -gt 0) {
        $reason = ($vErrs | ForEach-Object { "  - $_" }) -join "`n"
        throw "Invoke-BuildSpec: graph vừa ghi KHÔNG hợp lệ (Test-Workflow) — branch không tin được:`n$reason"
    }

    return $OutDir
}

function Write-SpecResult {
    <#
    .SYNOPSIS In kết quả validator + trả exit = số lỗi (đồng nhất convention validate).
    #>
    param(
        [Parameter(Mandatory, Position = 0)]$Result,
        [Parameter(Mandatory, Position = 1)][string]$Label
    )
    $errs = @($Result.errors)
    if ($errs.Count -eq 0) {
        Write-Host "✓ $Label hợp lệ" -ForegroundColor Green
        return 0
    }
    Write-Host "✗ $($errs.Count) lỗi trong ${Label}:" -ForegroundColor Red
    foreach ($e in $errs) { Write-Host "  - $e" -ForegroundColor Red }
    return $errs.Count
}

# --- Chạy trực tiếp (không dot-source): ./spec.ps1 plan|buildspec <file> ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 2 -or $args[0] -notin @('plan', 'buildspec')) {
        Write-Host "Cách dùng: ./spec.ps1 plan <plan.json> | buildspec <spec.json>" -ForegroundColor Yellow
        exit 2
    }
    $obj = Read-Json $args[1]
    if ($args[0] -eq 'plan') {
        $result = Test-PlanSchema $obj
        exit (Write-SpecResult $result "plan-as-data ($($args[1]))")
    }
    else {
        $result = Test-BuildSpec $obj
        exit (Write-SpecResult $result "build-spec ($($args[1]))")
    }
}

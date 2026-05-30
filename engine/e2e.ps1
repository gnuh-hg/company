# e2e.ps1 — Real-run harness cho Phase 5: HQ thật sinh branch chi nhánh → verify → promote.
# Implement Session 5.2.
#
# Vì sao cần: Phase 5 lần đầu gọi LLM thật (đốt token, non-deterministic). Trước mỗi real run
# phải có mock dry-run gate (free) xác nhận GRAPH có thể tới terminal thành công, rồi mới chạy
# real trong sandbox cô lập (tái dùng Copy-ToSandbox Phase 2), verify branch bằng validate/check
# (deterministic dù agent chạy LLM thật), promote branch đạt sang company/projects/, teardown.
# Gốc hq/ luôn sạch.
#
# Hàm thuần testable (QĐ #5):
#   Get-ProjectsRoot                                   → company/projects (resolve tuyệt đối).
#   Test-DryRunGate -ProjectDir -Request [-RouterSpec] [-SuccessTerminal record]
#                                                      → mock -Mock run → { pass; status; terminal; reason; runDir }.
#   Find-GeneratedBranch -SearchRoot [-Name]           → tìm branch sinh ra (<root>/projects/<name> có workflow.json).
#   Promote-Branch -BranchDir -Name [-Force]           → copy branch đạt → projects/<name> (guard chống đè + chống rò).
#   Invoke-E2E -ProjectDir -Request [-RouterSpec] [-Real] [-BranchName]
#                                                      → orchestrator: dry-run gate → (mặc định DỪNG, báo sẵn-sàng-real);
#                                                        -Real → Copy-ToSandbox → run real → locate → validate/check → promote → teardown.
#
# Token discipline (QĐ-4 + CHECKPOINT): KHÔNG -Real → 0 token (chỉ dry-run mock). -Real đốt token thật,
# CHỈ dùng ở Phase 5-B sau khi dry-run gate xanh. Mock-path executor bất biến (frontmatter flags bị mock bỏ qua).

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'sandbox.ps1')   # Copy-ToSandbox/Remove-Sandbox + check.ps1 (Test-StructuralGate) + workflow/validate/status

function Get-ProjectsRoot {
    <#
    .SYNOPSIS Thư mục app thật = company/projects (cạnh engine/). Resolve tuyệt đối.
    #>
    return (Join-Path (Split-Path -Parent $here) 'projects')
}

function Get-HappyPathRouterSpec {
    <#
    .SYNOPSIS
        A-24 (C.8): suy RouterSpec happy-path từ graph — heuristic chọn nhãn `when` của cạnh ra
        ĐẦU TIÊN ở mỗi node router. Trả chuỗi ENGINE_MOCK_ROUTER keyed-by-node-id (A-02),
        vd "coo:build;rg_gate:enough;tester:pass".
    .DESCRIPTION
        Để Test-DryRunGate tự lái router tới terminal mà caller KHÔNG phải hardcode node-id:nhãn nội
        bộ của graph (gỡ leak A-24). Cạnh ra giữ thứ tự khai báo trong workflow.json (graph.adj) →
        nhãn đầu = path "thẳng/thành công" theo convention author (vd coo→build, tester→pass).
        Keyed theo node id → khớp cả keyed-by-node (A-02) lẫn keyed-by-agent khi id==agent.
    .PARAMETER ProjectDir  Thư mục project (resolve được bởi Get-Graph).
    .OUTPUTS [string] spec ';'-separated (rỗng nếu graph không có router).
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)
    $graph = Get-Graph $ProjectDir
    $specs = @()
    foreach ($n in @($graph.nodes)) {
        if ($n.type -ne 'router') { continue }
        $outs = @($graph.adj[$n.id])
        $when = $null
        foreach ($e in $outs) {
            if (-not [string]::IsNullOrWhiteSpace($e.when)) { $when = $e.when.Trim(); break }
        }
        if (-not [string]::IsNullOrWhiteSpace($when)) { $specs += "$($n.id):$when" }
    }
    return ($specs -join ';')
}

function Test-DryRunGate {
    <#
    .SYNOPSIS
        Mock dry-run gate (free): chạy HQ project -Mock với RouterSpec đại diện cho happy-path
        → xác nhận run đạt 'done' + dừng đúng terminal thành công TRƯỚC khi đốt token real.
    .PARAMETER ProjectDir   Thư mục HQ project đã resolve.
    .PARAMETER Request      User request bơm vào mock run.
    .PARAMETER RouterSpec   ENGINE_MOCK_ROUTER đa-spec (vd "coo:build;rg_gate:enough;tester:pass").
                            Vắng → tự suy happy-path từ graph (Get-HappyPathRouterSpec, A-24).
    .PARAMETER SuccessTerminal  Node terminal kỳ vọng (mặc định 'record' = thành công HQ).
    .OUTPUTS [ordered]@{ pass; status; terminal; reason; runDir }.
    .NOTES Mock-only → 0 token. ENGINE_MOCK_ROUTER được set/clear cục bộ, không rò ra ngoài.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Mandatory, Position = 1)][string]$Request,
        [string]$RouterSpec,
        [string]$SuccessTerminal = 'record'
    )

    # A-24 (C.8): thiếu -RouterSpec → tự suy happy-path từ graph (heuristic nhãn `when` đầu mỗi router)
    # thay vì để caller hardcode node-id nội bộ. Truyền -RouterSpec tường minh vẫn override.
    if ([string]::IsNullOrWhiteSpace($RouterSpec)) {
        $RouterSpec = Get-HappyPathRouterSpec $ProjectDir
    }

    # CC-a (C.9): tầng kiểm frontmatter TĨNH (free) — cảnh báo node ghi-file thiếu quyền Write/Edit
    # TRƯỚC khi đốt token real. Chỉ cảnh báo (không fail gate) — mock không đụng frontmatter nên
    # divergence quyền chỉ lộ ở real; bắt sớm ở đây miễn phí.
    foreach ($w in @(Test-FrontmatterPermissions $ProjectDir)) {
        Write-Warning "dry-run frontmatter: $w"
    }

    $prev = $env:ENGINE_MOCK_ROUTER
    $env:ENGINE_MOCK_ROUTER = $RouterSpec
    try {
        $runDir = $null
        try {
            $runDir = Invoke-Workflow $ProjectDir $Request -Mock
        }
        catch {
            return [ordered]@{
                pass = $false; status = 'failed'; terminal = $null; runDir = $null
                reason = "dry-run -Mock throw: $($_.Exception.Message)"
            }
        }

        $state    = Get-RunState $runDir
        $status   = [string](Get-Prop $state 'status')
        $path     = @(Get-Prop $state 'path')
        $terminal = if ($path.Count -gt 0) { [string]$path[-1] } else { $null }

        if ($status -ne 'done') {
            return [ordered]@{
                pass = $false; status = $status; terminal = $terminal; runDir = $runDir
                reason = "dry-run state='$status' (kỳ vọng 'done')"
            }
        }
        if ($terminal -ne $SuccessTerminal) {
            return [ordered]@{
                pass = $false; status = $status; terminal = $terminal; runDir = $runDir
                reason = "dry-run terminal='$terminal' (kỳ vọng '$SuccessTerminal' = thành công)"
            }
        }
        return [ordered]@{
            pass = $true; status = $status; terminal = $terminal; runDir = $runDir
            reason = "dry-run done → terminal '$terminal'"
        }
    }
    finally {
        $env:ENGINE_MOCK_ROUTER = $prev
    }
}

function Find-GeneratedBranch {
    <#
    .SYNOPSIS
        Tìm branch chi nhánh HQ sinh ra trong <SearchRoot>/projects/ — thư mục con có workflow.json.
        Builder gọi `run.ps1 build` → Invoke-BuildSpec ghi projects/<name>/{workflow.json,agents/}.
    .PARAMETER SearchRoot  Thư mục chứa 'projects/' (vd sandbox dir).
    .PARAMETER Name        Lọc đúng tên branch; vắng → trả branch đầu tiên tìm thấy.
    .OUTPUTS [string] đường dẫn branch dir, hoặc $null nếu không thấy.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$SearchRoot,
        [string]$Name
    )

    $projDir = Join-Path $SearchRoot 'projects'
    if (-not (Test-Path -LiteralPath $projDir)) { return $null }

    $candidates = @(Get-ChildItem -LiteralPath $projDir -Directory -Force -ErrorAction SilentlyContinue)
    foreach ($c in $candidates) {
        if ($Name -and $c.Name -ne $Name) { continue }
        if (Test-Path -LiteralPath (Join-Path $c.FullName 'workflow.json')) {
            return $c.FullName
        }
    }
    return $null
}

function Promote-Branch {
    <#
    .SYNOPSIS
        Copy branch đạt từ sandbox → company/projects/<Name>/. Guard: đích phải nằm TRONG
        projects root (chống rò), từ chối đè nếu đã tồn tại (trừ -Force).
    .PARAMETER BranchDir  Branch dir nguồn (do Find-GeneratedBranch trả).
    .PARAMETER Name       Tên branch ở projects/.
    .PARAMETER Force      Cho phép đè branch cùng tên đã có.
    .OUTPUTS [string] đường dẫn projects/<Name> đã ghi.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$BranchDir,
        [Parameter(Mandatory, Position = 1)][string]$Name,
        [switch]$Force
    )

    if (-not (Test-Path -LiteralPath $BranchDir)) {
        throw "Promote-Branch: branch nguồn không tồn tại: $BranchDir"
    }

    $root = Get-ProjectsRoot
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    $rootFull = (Resolve-Path -LiteralPath $root).Path
    $dest     = Join-Path $root $Name
    # Resolve đích kỳ vọng (chưa tồn tại) qua parent để guard chống path traversal trong $Name.
    $destParent = (Resolve-Path -LiteralPath (Split-Path -Parent $dest)).Path
    if (-not (Test-PathInside $rootFull $destParent)) {
        throw "Promote-Branch: từ chối ghi '$dest' — nằm NGOÀI projects root '$rootFull'."
    }

    if (Test-Path -LiteralPath $dest) {
        if (-not $Force) {
            throw "Promote-Branch: '$dest' đã tồn tại (dùng -Force để đè)."
        }
        Remove-Item -LiteralPath $dest -Recurse -Force
    }
    Copy-Item -LiteralPath $BranchDir -Destination $dest -Recurse -Force
    return $dest
}

function Invoke-E2E {
    <#
    .SYNOPSIS
        Orchestrator real-E2E. Mặc định (không -Real): chỉ mock dry-run gate → báo sẵn-sàng-real,
        KHÔNG đốt token. Với -Real: dry-run gate → Copy-ToSandbox → run HQ THẬT → locate branch →
        validate/check branch → promote → teardown (gốc hq/ luôn sạch).
    .PARAMETER ProjectDir   HQ project đã resolve.
    .PARAMETER Request      User request.
    .PARAMETER RouterSpec   Router spec cho dry-run gate (happy-path kỳ vọng).
    .PARAMETER Real         Bật chạy LLM THẬT (đốt token). Vắng = dry-run-only (Phase 5-A).
    .PARAMETER BranchName   Tên branch kỳ vọng/promote; vắng → branch đầu tiên + giữ tên gốc.
    .OUTPUTS [ordered]@{ stage; pass; dryrun; branch?; verify?; promoted?; reason }.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Mandatory, Position = 1)][string]$Request,
        [string]$RouterSpec,
        [switch]$Real,
        [string]$BranchName,
        [switch]$KeepSandbox   # debug: KHÔNG teardown sandbox sau run (soi artifact builder/cto)
    )

    # --- (a) Mock dry-run gate — luôn chạy trước, free ---
    $dry = Test-DryRunGate $ProjectDir $Request -RouterSpec $RouterSpec
    if (-not $dry.pass) {
        return [ordered]@{
            stage = 'dry-run'; pass = $false; dryrun = $dry
            reason = "dry-run gate fail → KHÔNG chạy real: $($dry.reason)"
        }
    }
    if (-not $Real) {
        return [ordered]@{
            stage = 'dry-run'; pass = $true; dryrun = $dry
            reason = "dry-run pass ($($dry.reason)) — sẵn sàng real (chạy lại với -Real để đốt token)"
        }
    }

    # --- (b)–(f) Real run trong sandbox cô lập ---
    $sandboxDir = Copy-ToSandbox $ProjectDir
    try {
        # (c) chạy HQ THẬT (no -Mock) — executor truyền frontmatter flags (wiring 5.1).
        $runDir = Invoke-Workflow $sandboxDir $Request
        $state  = Get-RunState $runDir
        $status = [string](Get-Prop $state 'status')
        $path   = @(Get-Prop $state 'path')
        $terminal = if ($path.Count -gt 0) { [string]$path[-1] } else { $null }
        if ($status -ne 'done' -or $terminal -ne 'record') {
            return [ordered]@{
                stage = 'real-run'; pass = $false; dryrun = $dry
                reason = "real run state='$status' terminal='$terminal' (kỳ vọng done→record)"
            }
        }

        # (d) locate branch sinh ra trong sandbox
        $branchDir = Find-GeneratedBranch $sandboxDir -Name $BranchName
        if (-not $branchDir) {
            return [ordered]@{
                stage = 'locate'; pass = $false; dryrun = $dry
                reason = "không tìm thấy branch sinh ra trong $sandboxDir/projects/"
            }
        }

        # verify branch bằng validate + check (deterministic)
        $vr     = Test-Workflow $branchDir
        $verrs  = @($vr.errors)
        $struct = Test-StructuralGate $branchDir
        $verify = [ordered]@{
            validate_errors = $verrs.Count
            structural_pass = [bool]$struct.pass
        }
        if ($verrs.Count -ne 0 -or -not $struct.pass) {
            return [ordered]@{
                stage = 'verify'; pass = $false; dryrun = $dry; branch = $branchDir; verify = $verify
                reason = "branch fail verify (validate errs=$($verrs.Count), structural pass=$($struct.pass))"
            }
        }

        # (e) promote branch đạt → projects/
        $name     = if ($BranchName) { $BranchName } else { Split-Path -Leaf $branchDir }
        $promoted = Promote-Branch $branchDir $name -Force
        return [ordered]@{
            stage = 'done'; pass = $true; dryrun = $dry; branch = $branchDir
            verify = $verify; promoted = $promoted
            reason = "branch '$name' verify pass → promote $promoted"
        }
    }
    finally {
        # (f) teardown — gốc hq/ luôn sạch. -KeepSandbox: giữ lại để debug (KHÔNG dùng ở run sạch).
        if ($KeepSandbox) {
            Write-Host "  [KeepSandbox] giữ sandbox để debug → $sandboxDir" -ForegroundColor Yellow
        }
        else {
            Remove-Sandbox $sandboxDir
        }
    }
}

function Invoke-E2EFix {
    <#
    .SYNOPSIS
        Orchestrator real-E2E cho FIX-LOOP (Session 5.4). Khác Invoke-E2E (build branch mới):
        SEED một branch CỐ Ý HỎNG vào sandbox/projects/<name> trước, rồi để HQ thật đi đường
        `coo:fix → planner → cto → builder PATCH (Write/Edit) → tester:pass → record` sửa branch
        tại chỗ. Verify deterministic: pre-fix `validate` PHẢI fail, post-fix `validate` PHẢI exit 0.
    .PARAMETER ProjectDir    HQ project đã resolve.
    .PARAMETER Request       Fix request (nêu rõ branch path + lỗi để builder định vị qua {{user_request}}).
    .PARAMETER SeedBranchDir Branch hỏng nguồn (fixture, vd examples/broken-web) — copy vào sandbox.
    .PARAMETER BranchName    Tên branch dưới projects/ (vd broken-web).
    .PARAMETER RouterSpec    Router cho dry-run gate (fix happy-path: "coo:fix;tester:pass").
    .PARAMETER Real          Bật chạy LLM THẬT (đốt token). Vắng = dry-run-only.
    .PARAMETER KeepSandbox   Debug: giữ sandbox sau run.
    .OUTPUTS [ordered]@{ stage; pass; dryrun; branch?; verify?{validate_errors,pre_fix_errors,structural_pass}; promoted?; reason }.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Mandatory, Position = 1)][string]$Request,
        [Parameter(Mandatory)][string]$SeedBranchDir,
        [Parameter(Mandatory)][string]$BranchName,
        [string]$RouterSpec,
        [switch]$Real,
        [switch]$KeepSandbox
    )

    if (-not (Test-Path -LiteralPath $SeedBranchDir)) {
        return [ordered]@{ stage = 'seed'; pass = $false; dryrun = $null; reason = "seed branch không tồn tại: $SeedBranchDir" }
    }

    # --- (a) Mock dry-run gate (free) — đường fix phải tới 'record' ---
    $dry = Test-DryRunGate $ProjectDir $Request -RouterSpec $RouterSpec
    if (-not $dry.pass) {
        return [ordered]@{ stage = 'dry-run'; pass = $false; dryrun = $dry; reason = "dry-run gate fail → KHÔNG chạy real: $($dry.reason)" }
    }
    if (-not $Real) {
        return [ordered]@{ stage = 'dry-run'; pass = $true; dryrun = $dry; reason = "dry-run pass ($($dry.reason)) — sẵn sàng real fix-loop (chạy lại với -Real)" }
    }

    # --- (b)–(f) Real fix-loop trong sandbox cô lập ---
    $sandboxDir = Copy-ToSandbox $ProjectDir
    try {
        # SEED branch hỏng vào sandbox/projects/<name> (Builder patch tại chỗ qua cwd=sandbox)
        $seedDest = Join-Path $sandboxDir 'projects' $BranchName
        New-Item -ItemType Directory -Path (Split-Path -Parent $seedDest) -Force | Out-Null
        Copy-Item -LiteralPath $SeedBranchDir -Destination $seedDest -Recurse -Force

        # (pre) baseline: branch hỏng PHẢI validate fail (fixture đúng) + chụp mtime/hash để chứng minh Builder ghi thật
        $wfPath = Join-Path $seedDest 'workflow.json'
        $pre    = Test-Workflow $seedDest
        $preErrs = @($pre.errors).Count
        $preHash = (Get-FileHash -LiteralPath $wfPath -Algorithm SHA256).Hash
        if ($preErrs -eq 0) {
            return [ordered]@{ stage = 'seed'; pass = $false; dryrun = $dry; reason = "seed branch KHÔNG hỏng (validate 0 lỗi) — fixture sai, không test được fix-loop" }
        }

        # (c) chạy HQ THẬT (no -Mock) — executor truyền frontmatter flags (wiring 5.1) → Builder patch file thật
        $runDir = Invoke-Workflow $sandboxDir $Request
        $state  = Get-RunState $runDir
        $status = [string](Get-Prop $state 'status')
        $path   = @(Get-Prop $state 'path')
        $terminal = if ($path.Count -gt 0) { [string]$path[-1] } else { $null }
        if ($status -ne 'done' -or $terminal -ne 'record') {
            return [ordered]@{ stage = 'real-run'; pass = $false; dryrun = $dry; reason = "real fix run state='$status' terminal='$terminal' (kỳ vọng done→record)" }
        }

        # (post) branch sau fix PHẢI validate exit 0 + file đã đổi (chứng minh Write/Edit wiring real)
        $post     = Test-Workflow $seedDest
        $postErrs = @($post.errors).Count
        $postHash = if (Test-Path -LiteralPath $wfPath) { (Get-FileHash -LiteralPath $wfPath -Algorithm SHA256).Hash } else { $null }
        $fileChanged = ($preHash -ne $postHash)
        $verify = [ordered]@{
            validate_errors = $postErrs
            pre_fix_errors  = $preErrs
            file_changed    = [bool]$fileChanged
            structural_pass = $true
        }
        if ($postErrs -ne 0) {
            return [ordered]@{ stage = 'verify'; pass = $false; dryrun = $dry; branch = $seedDest; verify = $verify
                reason = "branch sau fix VẪN validate fail (errs trước=$preErrs, sau=$postErrs) — Builder chưa patch đúng" }
        }
        if (-not $fileChanged) {
            return [ordered]@{ stage = 'verify'; pass = $false; dryrun = $dry; branch = $seedDest; verify = $verify
                reason = "validate exit 0 nhưng workflow.json KHÔNG đổi (hash y hệt) — fix không phải do Builder ghi file" }
        }

        # (e) promote branch đã sửa → projects/
        $promoted = Promote-Branch $seedDest $BranchName -Force
        return [ordered]@{ stage = 'done'; pass = $true; dryrun = $dry; branch = $seedDest; verify = $verify; promoted = $promoted
            reason = "fix-loop pass: validate $preErrs lỗi → 0; Builder ghi file thật → promote $promoted" }
    }
    finally {
        if ($KeepSandbox) {
            Write-Host "  [KeepSandbox] giữ sandbox để debug → $sandboxDir" -ForegroundColor Yellow
        }
        else {
            Remove-Sandbox $sandboxDir
        }
    }
}

function Get-SandboxSnapshot {
    <#
    .SYNOPSIS
        Snapshot cây file của $Dir → hashtable {relPath → LastWriteTimeUtc.Ticks}.
        Dùng cặp trước/sau builder để feed Test-DiffScope (theo dõi thêm/sửa/xoá).
    .PARAMETER Dir  Thư mục sandbox tuyệt đối.
    .OUTPUTS [hashtable] {relPath → ticks}
    #>
    param([Parameter(Mandatory, Position = 0)][string]$Dir)
    $result = @{}
    if (-not (Test-Path -LiteralPath $Dir)) { return $result }
    $sep     = [IO.Path]::DirectorySeparatorChar
    $dirFull = (Resolve-Path -LiteralPath $Dir).Path.TrimEnd($sep)
    foreach ($f in @(Get-ChildItem -LiteralPath $dirFull -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        $rel = $f.FullName.Substring($dirFull.Length + 1)
        $result[$rel] = $f.LastWriteTimeUtc.Ticks
    }
    return $result
}

function Test-DiffScope {
    <#
    .SYNOPSIS
        CC-b: kiểm builder chỉ đụng path khai báo (whitelist).
        So snapshot trước/sau → liệt vi phạm (đụng/xoá ngoài whitelist).
        Đặc biệt bắt builder xoá .runs/ (vật chứng C.10 Phase C).
    .PARAMETER SandboxDir    Sandbox root tuyệt đối (caller truyền đã resolve).
    .PARAMETER AllowedPaths  Danh sách path tuyệt đối được phép đụng.
                             Mặc định: [SandboxDir/projects, SandboxDir/spec.json].
    .PARAMETER Before        Snapshot trước builder (hashtable từ Get-SandboxSnapshot).
    .PARAMETER After         Snapshot sau builder (hashtable từ Get-SandboxSnapshot).
    .OUTPUTS [ordered]@{ ok=[bool]; violations=[string[]] }
    .NOTES Tái dùng Test-PathInside từ lib/path.ps1 (qua sandbox.ps1) để guard ranh giới separator.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$SandboxDir,
        [Parameter(Position = 1)][string[]]$AllowedPaths,
        [Parameter(Mandatory)][hashtable]$Before,
        [Parameter(Mandatory)][hashtable]$After
    )

    $sep    = [IO.Path]::DirectorySeparatorChar
    $sbFull = $SandboxDir.TrimEnd($sep)

    $apList = if ($AllowedPaths -and @($AllowedPaths).Count -gt 0) { @($AllowedPaths) } else {
        @(
            (Join-Path $sbFull 'projects')
            (Join-Path $sbFull 'spec.json')
        )
    }

    $violations = [System.Collections.Generic.List[string]]::new()

    $allKeys = @(@($Before.Keys) + @($After.Keys)) | Sort-Object -Unique
    if ($null -eq $allKeys) { $allKeys = @() }

    foreach ($rel in $allKeys) {
        $inBefore = $Before.ContainsKey($rel)
        $inAfter  = $After.ContainsKey($rel)
        if ($inBefore -and $inAfter -and ($Before[$rel] -eq $After[$rel])) { continue }

        $absPath = Join-Path $sbFull $rel
        $allowed = $false
        foreach ($ap in $apList) {
            if (Test-PathInside $ap.TrimEnd($sep) $absPath) { $allowed = $true; break }
        }
        if (-not $allowed) {
            $action = if (-not $inAfter) { 'deleted' } elseif (-not $inBefore) { 'added' } else { 'modified' }
            $violations.Add("${action}: $rel")
        }
    }

    return [ordered]@{ ok = ($violations.Count -eq 0); violations = [string[]]$violations }
}

function Write-E2EResult {
    <#
    .SYNOPSIS In report E2E + trả exit code (0 = pass, 1 = fail).
    #>
    param([Parameter(Mandatory, Position = 0)]$Result)

    Write-Host "E2E harness — stage: $($Result.stage)" -ForegroundColor Cyan
    $d = $Result.dryrun
    $dmark = if ($d.pass) { '✓' } else { '✗' }
    $dcol  = if ($d.pass) { 'Green' } else { 'Red' }
    Write-Host ("  {0} dry-run gate: {1}" -f $dmark, $d.reason) -ForegroundColor $dcol

    if ($Result.PSObject.Properties.Name -contains 'branch') {
        Write-Host "  • branch: $($Result.branch)" -ForegroundColor DarkGray
    }
    if ($Result.PSObject.Properties.Name -contains 'verify') {
        $v = $Result.verify
        $extra = ''
        if ($v.PSObject.Properties.Name -contains 'pre_fix_errors') { $extra += " pre_fix_errors=$($v.pre_fix_errors)" }
        if ($v.PSObject.Properties.Name -contains 'file_changed')   { $extra += " file_changed=$($v.file_changed)" }
        Write-Host "  • verify: validate_errors=$($v.validate_errors) structural_pass=$($v.structural_pass)$extra" -ForegroundColor DarkGray
    }
    if ($Result.PSObject.Properties.Name -contains 'promoted') {
        Write-Host "  • promoted → $($Result.promoted)" -ForegroundColor DarkGray
    }
    Write-Host ''
    if ($Result.pass) {
        Write-Host "✓ E2E $($Result.stage): $($Result.reason)" -ForegroundColor Green
        return 0
    }
    Write-Host "✗ E2E $($Result.stage): $($Result.reason)" -ForegroundColor Red
    return 1
}

# --- Chạy trực tiếp (không dot-source): ./e2e.ps1 <projectDir> "<request>" [router] [-Real] ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 2) {
        Write-Host 'Cách dùng: ./e2e.ps1 <projectDir> "<request>" [routerSpec] [-Real]' -ForegroundColor Yellow
        exit 2
    }
    $real   = ($args -contains '-Real')
    $rest   = @($args | Where-Object { $_ -ne '-Real' })
    $router = if ($rest.Count -ge 3) { $rest[2] } else { $null }
    $result = Invoke-E2E $rest[0] $rest[1] -RouterSpec $router -Real:$real
    exit (Write-E2EResult $result)
}

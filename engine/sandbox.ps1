# sandbox.ps1 — harness cô lập cho Tester tầng 2 (trial).
# Implement Session 2-B.1.
#
# Vì sao cần: tầng trial (B.2) chạy project THẬT (không -Mock) → sinh artifact ghi file.
# Để KHÔNG đụng project gốc (quy ước #6 — examples/* CHỈ ĐỌC), ta copy project vào
# company/sandbox/<runid>/ cô lập, chạy ở đó, rồi teardown. company/ chưa là git repo
# nên dùng copy thư mục (không git worktree); sandbox/ được gitignore cho forward-compat.
#
# Hàm thuần testable (QĐ #5):
#   Copy-ToSandbox -ProjectDir <dir> [-RunId <id>] → copy (TRỪ .runs/) → path sandbox.
#   Remove-Sandbox -SandboxDir <dir>               → teardown an toàn (chỉ xoá trong sandbox/).
#   Get-SandboxRoot                                → company/sandbox (resolve tuyệt đối).
#   Get-Trials -ProjectDir <dir>                   → đọc trial[] từ workflow.json → list chuẩn hoá.
#   Test-TrialExpect -Actual <s> -Expect <obj>     → pure: áp 1 assertion → { pass; reason }.
#   Invoke-Trial -ProjectDir -Trials [...]         → copy → run THẬT → assert artifact → teardown.
#
# trial[] (đầu vào C-3 cho P3 CTO) — khai top-level trong workflow.json, plan-as-data:
#   "trial": [ { "observe": "<output_key>", "expect": { "kind": "non-empty"|"contains"|"matches",
#               "value"?: "<substring/regex>" } } ]
#   Mỗi item = 1 quan sát trên artifact <output_key>.txt shipped sau run THẬT (đạt 'done').
#   - non-empty: artifact tồn tại + không rỗng.
#   - contains : artifact chứa literal substring `value`.
#   - matches  : artifact khớp regex `value`.
#   Loader engine (Get-Graph) bỏ qua field 'trial' (chỉ đọc nodes/edges/...) → không ảnh hưởng run;
#   validate cũng bỏ qua (allowlist field bắt buộc) → thêm trial[] an toàn, không phải mutation.
#
# Surface lệnh (QĐ #4): run.ps1 trial <proj> — 2 tầng tuần tự:
#   (1) tầng cấu trúc (Invoke-TrialScaffold: copy → Test-StructuralGate -Mock → teardown) — tiền đề;
#   (2) nếu (1) pass → tầng trial THẬT (Invoke-Trial: copy → run real → assert trial[] → teardown).

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'check.ps1')          # Test-StructuralGate + Write-CheckResult (kéo theo workflow/validate/status)
. (Join-Path $here 'lib/path.ps1')       # Test-PathInside (guard ngăn-chặn path — A-14/A-25)

function Get-SandboxRoot {
    <#
    .SYNOPSIS Thư mục gốc sandbox = company/sandbox (cạnh engine/). Resolve tuyệt đối.
    #>
    return (Join-Path (Split-Path -Parent $here) 'sandbox')
}

function Copy-ToSandbox {
    <#
    .SYNOPSIS
        Copy 1 project vào company/sandbox/<runid>/ cô lập, BỎ .runs/ (tránh kéo artifact cũ).
    .PARAMETER ProjectDir
        Thư mục project đã resolve (vd: examples/loopy).
    .PARAMETER RunId
        Tên thư mục sandbox con. Mặc định = timestamp (đồng nhất convention .runs/).
    .OUTPUTS [string] đường dẫn sandbox dir đã tạo (chứa bản copy của project).
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Position = 1)][string]$RunId = ((Get-Date).ToString('yyyyMMdd-HHmmss'))
    )

    if (-not (Test-Path -LiteralPath $ProjectDir)) {
        throw "Copy-ToSandbox: project dir không tồn tại: $ProjectDir"
    }

    $root       = Get-SandboxRoot
    $sandboxDir = Join-Path $root $RunId
    if (Test-Path -LiteralPath $sandboxDir) {
        throw "Copy-ToSandbox: sandbox '$RunId' đã tồn tại: $sandboxDir"
    }
    New-Item -ItemType Directory -Path $sandboxDir -Force | Out-Null

    # Copy mọi entry top-level TRỪ .runs/ (artifact run cũ — không tái dùng trong sandbox sạch).
    $entries = @(Get-ChildItem -LiteralPath $ProjectDir -Force)
    foreach ($e in $entries) {
        if ($e.Name -eq '.runs') { continue }
        Copy-Item -LiteralPath $e.FullName -Destination $sandboxDir -Recurse -Force
    }

    return $sandboxDir
}

function Remove-Sandbox {
    <#
    .SYNOPSIS
        Teardown 1 sandbox dir. Guard an toàn: chỉ xoá nếu nằm TRONG company/sandbox/
        (tránh lỡ xoá ngoài scope — quy ước #6).
    .PARAMETER SandboxDir
        Đường dẫn sandbox cần xoá (do Copy-ToSandbox trả).
    #>
    param([Parameter(Mandatory, Position = 0)][string]$SandboxDir)

    if (-not (Test-Path -LiteralPath $SandboxDir)) { return }

    $root     = (Resolve-Path -LiteralPath (Get-SandboxRoot)).Path
    $fullPath = (Resolve-Path -LiteralPath $SandboxDir).Path
    if (-not (Test-PathInside $root $fullPath)) {
        throw "Remove-Sandbox: từ chối xoá '$fullPath' — nằm NGOÀI sandbox root '$root'."
    }
    if ($fullPath -eq $root) {
        throw "Remove-Sandbox: từ chối xoá chính sandbox root '$root'."
    }
    Remove-Item -LiteralPath $fullPath -Recurse -Force
}

function Get-Trials {
    <#
    .SYNOPSIS
        Đọc field top-level 'trial' trong workflow.json của project → list chuẩn hoá
        [{ observe; expect = { kind; value } }]. Không khai trial → trả mảng rỗng.
    .PARAMETER ProjectDir Thư mục project đã resolve.
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)

    $wfPath = Join-Path $ProjectDir 'workflow.json'
    if (-not (Test-Path -LiteralPath $wfPath)) {
        throw "Get-Trials: thiếu workflow.json: $wfPath"
    }
    $wf = Read-Json $wfPath
    if (-not ($wf.PSObject.Properties.Name -contains 'trial')) { return @() }

    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($t in @($wf.trial)) {
        $observe = if ($t.PSObject.Properties.Name -contains 'observe') { [string]$t.observe } else { '' }
        $kind  = 'non-empty'
        $value = $null
        if ($t.PSObject.Properties.Name -contains 'expect' -and $null -ne $t.expect) {
            $exp = $t.expect
            if ($exp.PSObject.Properties.Name -contains 'kind')  { $kind  = [string]$exp.kind }
            if ($exp.PSObject.Properties.Name -contains 'value') { $value = [string]$exp.value }
        }
        $out.Add([ordered]@{ observe = $observe; expect = [ordered]@{ kind = $kind; value = $value } })
    }
    return $out.ToArray()
}

function Test-TrialExpect {
    <#
    .SYNOPSIS
        Pure: áp 1 assertion `expect` lên text `Actual`. Trả { pass; reason } (reason máy-đọc-được).
    .PARAMETER Expect Object { kind; value } — kind ∈ non-empty|contains|matches.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][AllowEmptyString()][AllowNull()][string]$Actual,
        [Parameter(Mandatory, Position = 1)]$Expect
    )
    $kind  = [string]$Expect.kind
    $value = [string]$Expect.value
    switch ($kind) {
        'non-empty' {
            if ([string]::IsNullOrWhiteSpace($Actual)) {
                return [ordered]@{ pass = $false; reason = 'kỳ vọng non-empty nhưng artifact rỗng/thiếu' }
            }
            return [ordered]@{ pass = $true; reason = "non-empty ($($Actual.Length) chars)" }
        }
        'contains' {
            if ([string]::IsNullOrEmpty($value)) {
                return [ordered]@{ pass = $false; reason = "expect.value trống cho kind 'contains'" }
            }
            if ($null -ne $Actual -and $Actual.Contains($value)) {
                return [ordered]@{ pass = $true; reason = "chứa '$value'" }
            }
            return [ordered]@{ pass = $false; reason = "không chứa '$value'" }
        }
        'matches' {
            if ([string]::IsNullOrEmpty($value)) {
                return [ordered]@{ pass = $false; reason = "expect.value trống cho kind 'matches'" }
            }
            if ($Actual -match $value) {
                return [ordered]@{ pass = $true; reason = "khớp regex '$value'" }
            }
            return [ordered]@{ pass = $false; reason = "không khớp regex '$value'" }
        }
        default {
            return [ordered]@{ pass = $false; reason = "kind không hỗ trợ: '$kind' (non-empty|contains|matches)" }
        }
    }
}

function Invoke-Trial {
    <#
    .SYNOPSIS
        Tầng trial THẬT: copy project vào sandbox → chạy project **không -Mock** (gọi model) →
        yêu cầu run đạt 'done' → đọc artifact <observe>.txt mới nhất → áp từng `expect` → teardown.
    .OUTPUTS
        [ordered]@{ pass; status; sandbox; results = [{ observe; kind; value; pass; reason; actual_excerpt }] }
    .NOTES
        Đốt token + non-deterministic (QĐ user: tier trial = THẬT). env ENGINE_MOCK_* bị bỏ qua ở real mode.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Mandatory, Position = 1)][object[]]$Trials,
        [Parameter(Position = 2)][string]$Request = 'Thực hiện một thay đổi nhỏ rồi xác nhận hoàn tất.',
        [string]$Model
    )

    $sandboxDir = Copy-ToSandbox $ProjectDir
    try {
        $runDir = Invoke-Workflow $sandboxDir $Request -Model $Model
        $state  = Get-RunState $runDir
        $status = if ($state.PSObject.Properties.Name -contains 'status') { $state.status } else { $null }
        if ($status -ne 'done') {
            return [ordered]@{
                pass = $false; status = $status; sandbox = $sandboxDir; results = @()
                reason = "run real state='$status' (kỳ vọng 'done') → không tính trial"
            }
        }

        $results = [System.Collections.Generic.List[object]]::new()
        $allPass = $true
        foreach ($t in $Trials) {
            $observe = [string]$t.observe
            $p       = Join-Path $runDir "$observe.txt"
            $actual  = ''
            $found   = Test-Path -LiteralPath $p
            if ($found) { $actual = Get-Content -LiteralPath $p -Raw -Encoding utf8 }

            $verdict = Test-TrialExpect $actual $t.expect
            if (-not $verdict.pass) { $allPass = $false }

            $excerpt = if (-not $found) {
                "(thiếu file $observe.txt)"
            }
            elseif ($actual.Length -gt 120) {
                $actual.Substring(0, 120) + '…'
            }
            else { $actual }
            $excerpt = ($excerpt -replace "\r?\n", ' ⏎ ')

            $results.Add([ordered]@{
                observe = $observe; kind = $t.expect.kind; value = $t.expect.value
                pass = $verdict.pass; reason = $verdict.reason; actual_excerpt = $excerpt
            })
        }
        return [ordered]@{ pass = $allPass; status = 'done'; sandbox = $sandboxDir; results = $results.ToArray() }
    }
    finally {
        Remove-Sandbox $sandboxDir
    }
}

function Write-TrialResult {
    <#
    .SYNOPSIS In report tầng trial + trả exit code = số assertion 'fail' (status≠done → 1).
    #>
    param(
        [Parameter(Mandatory, Position = 0)]$Result,
        [Parameter(Mandatory, Position = 1)][string]$Label
    )
    Write-Host "Tầng trial (real) — $Label" -ForegroundColor Cyan
    if ($Result.status -ne 'done') {
        $why = if ($Result.PSObject.Properties.Name -contains 'reason') { $Result.reason } else { "status='$($Result.status)'" }
        Write-Host "  ✗ run real không đạt 'done': $why" -ForegroundColor Red
        Write-Host ''
        Write-Host "✗ trial FAIL: $Label" -ForegroundColor Red
        return 1
    }
    $fails = 0
    foreach ($r in @($Result.results)) {
        if ($r.pass) { $mark = '✓'; $color = 'Green' } else { $mark = '✗'; $color = 'Red'; $fails++ }
        $vstr = if (-not [string]::IsNullOrEmpty([string]$r.value)) { " '$($r.value)'" } else { '' }
        Write-Host -NoNewline ("  {0} observe={1} kind={2}{3}" -f $mark, $r.observe, $r.kind, $vstr) -ForegroundColor $color
        Write-Host "  → $($r.reason)"
        Write-Host "      actual: $($r.actual_excerpt)" -ForegroundColor DarkGray
    }
    Write-Host ''
    if ($fails -eq 0 -and $Result.pass) {
        Write-Host "✓ trial PASS: $Label ($($Result.results.Count) assertion)" -ForegroundColor Green
    }
    else {
        Write-Host "✗ trial FAIL: $Label ($fails assertion fail)" -ForegroundColor Red
    }
    return $fails
}

function Invoke-TrialScaffold {
    <#
    .SYNOPSIS
        Scaffold tầng trial (B.1): copy project vào sandbox → chạy tầng cấu trúc
        (Test-StructuralGate, vẫn -Mock) trên bản sandbox → teardown. Chứng minh isolation
        TRƯỚC khi thêm real trial (B.2). Trả object { sandbox; result; fails }.
    .PARAMETER ProjectDir
        Thư mục project đã resolve.
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)

    $sandboxDir = Copy-ToSandbox $ProjectDir
    try {
        $result = Test-StructuralGate $sandboxDir
        return [ordered]@{ sandbox = $sandboxDir; result = $result }
    }
    finally {
        Remove-Sandbox $sandboxDir
    }
}

# --- Chạy trực tiếp (không dot-source): trial scaffold → exit = số tiêu chí fail ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 1) {
        Write-Host "Cách dùng: ./sandbox.ps1 <projectDir>" -ForegroundColor Yellow
        exit 2
    }
    $outcome = Invoke-TrialScaffold $args[0]
    Write-Host "Sandbox (đã teardown): $($outcome.sandbox)" -ForegroundColor DarkGray
    exit (Write-CheckResult $outcome.result "trial-scaffold: $($args[0])")
}

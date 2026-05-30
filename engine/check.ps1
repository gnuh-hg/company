# check.ps1 — Tester tầng 1 (cấu trúc): gate máy-kiểm-được, deterministic, free.
# Implement Session 2-A.1.
#
# Tầng cấu trúc = 3 tiêu chí TUẦN TỰ trên 1 project (QĐ C-2, ROADMAP cross-cutting):
#   1. validate   → Test-Workflow đếm lỗi = 0 (graph hợp lệ).
#   2. run -Mock  → Invoke-Workflow chạy offline đạt state 'done' (không failed/max_steps).
#   3. output-key → mọi output_key khai trong nodes có file <key>.txt non-empty trong run dir.
# Short-circuit: tiêu chí trước fail → tiêu chí sau 'skip' (không tính vào exit, không false-positive).
#
# Hàm thuần testable: Test-StructuralGate -ProjectDir <dir> → object
#   { pass: bool; checks: [{ name; status('pass'|'fail'|'skip'); reason }] }.
# reason fail luôn MÁY-ĐỌC-ĐƯỢC (chứa tên node/key/path bị lỗi, không chỉ "failed") — để
# negative-path (A.2) chỉ đúng tầng + chỉ đúng chỗ hỏng.
#
# Surface lệnh (QĐ #4): run.ps1 check <proj> → in report + exit = số tiêu chí FAIL (0 = pass toàn bộ,
# đồng nhất convention validate). KHÔNG tạo entry point khác.
#
# Lưu ý fixture có router (loopy): đặt $env:ENGINE_MOCK_ROUTER="<router-agent>:pass" TRƯỚC khi gọi
# để router thoát loop ở tầng -Mock; nếu không, run sẽ fail (router không khớp 'when') → gate fail
# đúng tầng 'run'. check chỉ honor env có sẵn, KHÔNG hardcode fixture nào.

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib/json.ps1')
. (Join-Path $here 'workflow.ps1')   # Invoke-Workflow (+ Get-Graph qua graph.ps1)
. (Join-Path $here 'validate.ps1')   # Test-Workflow
. (Join-Path $here 'status.ps1')     # Get-RunState

function Test-StructuralGate {
    <#
    .SYNOPSIS
        Chạy tầng cấu trúc (3 tiêu chí tuần tự) trên 1 project. Trả object kết quả thuần.
    .PARAMETER ProjectDir
        Thư mục project đã resolve (vd: examples/loopy). run.ps1 resolve tên gọn → dir.
    .PARAMETER Request
        User request bơm vào run -Mock (mặc định 'structural-gate-probe').
    .OUTPUTS
        [ordered]@{ pass = [bool]; checks = [object[]] } — mỗi check { name; status; reason }.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Position = 1)][string]$Request = 'structural-gate-probe'
    )

    $checks = [System.Collections.Generic.List[object]]::new()
    $add = {
        param([string]$Name, [string]$Status, [string]$Reason)
        $checks.Add([ordered]@{ name = $Name; status = $Status; reason = $Reason })
    }
    $skipRest = {
        param([string[]]$Names, [string]$Why)
        foreach ($n in $Names) { & $add $n 'skip' $Why }
        return [ordered]@{ pass = $false; checks = $checks.ToArray() }
    }

    if (-not (Test-Path -LiteralPath $ProjectDir)) {
        & $add 'validate' 'fail' "project dir không tồn tại: $ProjectDir"
        return & $skipRest @('run', 'output-key') "bỏ qua — tiêu chí 'validate' fail"
    }

    # --- Tiêu chí 1: validate (exit 0 = không lỗi) ---
    $vr    = Test-Workflow $ProjectDir
    $verrs = @($vr.errors)
    if ($verrs.Count -gt 0) {
        $reason = "validate có $($verrs.Count) lỗi: " + ($verrs -join ' | ')
        & $add 'validate' 'fail' $reason
        return & $skipRest @('run', 'output-key') "bỏ qua — tiêu chí 'validate' fail"
    }
    & $add 'validate' 'pass' 'graph hợp lệ (0 lỗi)'

    # --- Tiêu chí 2: run -Mock đạt 'done' ---
    $runDir = $null
    try {
        $runDir = Invoke-Workflow $ProjectDir $Request -Mock
    }
    catch {
        # Invoke-Workflow throw khi node fail / router không khớp / vượt max_steps —
        # message đã chứa tên node + lý do (máy-đọc-được).
        & $add 'run' 'fail' "run -Mock không hoàn tất: $($_.Exception.Message)"
        return & $skipRest @('output-key') "bỏ qua — tiêu chí 'run' fail"
    }

    $state  = Get-RunState $runDir
    $status = if ($state.PSObject.Properties.Name -contains 'status') { $state.status } else { $null }
    if ($status -ne 'done') {
        $serr = if ($state.PSObject.Properties.Name -contains 'error') { $state.error } else { '' }
        & $add 'run' 'fail' "run -Mock state='$status' (kỳ vọng 'done'); error: $serr"
        return & $skipRest @('output-key') "bỏ qua — tiêu chí 'run' fail"
    }
    & $add 'run' 'pass' "run -Mock đạt 'done' → $(Split-Path -Leaf $runDir)"

    # --- Tiêu chí 3: mọi output_key có file non-empty trong run dir ---
    $graph = Get-Graph $ProjectDir
    $keys  = [System.Collections.Generic.List[string]]::new()
    foreach ($n in $graph.nodes) {
        $k = $n.output_key
        if (-not [string]::IsNullOrWhiteSpace($k) -and -not $keys.Contains($k)) { $keys.Add($k) }
    }
    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($k in $keys) {
        $p = Join-Path $runDir "$k.txt"
        if (-not (Test-Path -LiteralPath $p)) {
            $missing.Add("'$k' (thiếu file $k.txt)")
            continue
        }
        $content = Get-Content -LiteralPath $p -Raw -Encoding utf8
        if ([string]::IsNullOrWhiteSpace($content)) {
            $missing.Add("'$k' (file $k.txt rỗng)")
        }
    }
    if ($missing.Count -gt 0) {
        & $add 'output-key' 'fail' ("output_key thiếu/rỗng: " + ($missing -join ' | '))
        return [ordered]@{ pass = $false; checks = $checks.ToArray() }
    }
    & $add 'output-key' 'pass' "$($keys.Count) output_key đều có file non-empty: $($keys -join ', ')"

    return [ordered]@{ pass = $true; checks = $checks.ToArray() }
}

function Write-CheckResult {
    <#
    .SYNOPSIS In report tầng cấu trúc + trả exit code = số tiêu chí 'fail'.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]$Result,
        [Parameter(Mandatory, Position = 1)][string]$Label
    )
    $checks = @($Result.checks)
    $fails  = 0
    Write-Host "Tầng cấu trúc — $Label" -ForegroundColor Cyan
    foreach ($c in $checks) {
        switch ($c.status) {
            'pass' { $mark = '✓'; $color = 'Green' }
            'fail' { $mark = '✗'; $color = 'Red'; $fails++ }
            default { $mark = '⊘'; $color = 'DarkGray' }
        }
        Write-Host -NoNewline ("  {0} {1,-11}" -f $mark, $c.name) -ForegroundColor $color
        Write-Host " $($c.reason)"
    }
    Write-Host ''
    if ($fails -eq 0 -and $Result.pass) {
        Write-Host "✓ gate cấu trúc PASS: $Label" -ForegroundColor Green
    }
    else {
        Write-Host "✗ gate cấu trúc FAIL: $Label ($fails tiêu chí fail)" -ForegroundColor Red
    }
    return $fails
}

# --- Chạy trực tiếp (không dot-source): exit = số tiêu chí fail ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 1) {
        Write-Host "Cách dùng: ./check.ps1 <projectDir> [request]" -ForegroundColor Yellow
        exit 2
    }
    $req = if ($args.Count -ge 2) { $args[1] } else { 'structural-gate-probe' }
    $result = Test-StructuralGate $args[0] $req
    exit (Write-CheckResult $result $args[0])
}

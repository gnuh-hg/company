# e2e-harness-tests.ps1 — STOP gate Session 5.2 (mock-only, 0 token real).
#
# Verify harness engine/e2e.ps1 KHÔNG đốt token:
#   1. Dry-run gate: happy-path mock → pass + terminal=record; escalate path → pass khi
#      SuccessTerminal=escalate_report; terminal sai → fail (KHÔNG real).
#   2. Invoke-E2E (không -Real): dừng ở dry-run, báo sẵn-sàng-real, pass=true, không chạy real.
#   3. Copy-ToSandbox/Remove-Sandbox round-trip trên ../hq: sandbox đủ agents/+workflow.json;
#      teardown sạch; gốc hq/ file count không đổi.
#   4. Promote-Branch: branch giả trong sandbox/projects → promote → xuất hiện ở projects/ → dọn được.
#
# Exit = số assertion fail. Dọn .runs/ + sandbox + projects test sau verify.

Set-StrictMode -Version Latest

$hqEngine = Join-Path (Split-Path -Parent $PSScriptRoot) 'engine'
. (Join-Path $hqEngine 'e2e.ps1')   # kéo theo sandbox/check/workflow/validate/status

$hqDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'hq'

$script:fails = 0
function Assert([bool]$Cond, [string]$Msg) {
    if ($Cond) { Write-Host "  ✓ $Msg" -ForegroundColor Green }
    else       { Write-Host "  ✗ $Msg" -ForegroundColor Red; $script:fails++ }
}
function Remove-Runs([string]$Dir) {
    $r = Join-Path $Dir '.runs'
    if (Test-Path -LiteralPath $r) { Remove-Item -LiteralPath $r -Recurse -Force }
}
function Remove-Mem([string]$Dir) {
    $m = Join-Path $Dir 'memory'
    if (Test-Path -LiteralPath $m) { Remove-Item -LiteralPath $m -Recurse -Force }
}
function Count-Files([string]$Dir) {
    @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/](\.runs|memory)[\\/]' }).Count
}

try {
    # --- 1. Dry-run gate ---
    Write-Host "[1] Test-DryRunGate" -ForegroundColor Cyan
    Remove-Runs $hqDir; Remove-Mem $hqDir
    $happy = Test-DryRunGate $hqDir 'tạo pipeline web nhỏ' -RouterSpec 'coo:build;rg_gate:enough;tester:pass'
    Assert ($happy.pass) "happy-path dry-run pass"
    Assert ($happy.terminal -eq 'record') "happy terminal = record"

    Remove-Runs $hqDir; Remove-Mem $hqDir
    # COO unclear → escalate_gate escalate → escalate_report (terminal bí).
    $esc = Test-DryRunGate $hqDir 'mơ hồ' -RouterSpec 'coo:unclear;escalate_gate:escalate' -SuccessTerminal 'escalate_report'
    Assert ($esc.pass) "escalate path pass khi SuccessTerminal=escalate_report"
    Assert ($esc.terminal -eq 'escalate_report') "escalate terminal = escalate_report"

    Remove-Runs $hqDir; Remove-Mem $hqDir
    # Happy path nhưng kỳ vọng sai terminal → fail (gate chặn real).
    $bad = Test-DryRunGate $hqDir 'web' -RouterSpec 'coo:build;rg_gate:enough;tester:pass' -SuccessTerminal 'escalate_report'
    Assert (-not $bad.pass) "terminal sai → dry-run gate fail (chặn real)"

    # --- 2. Invoke-E2E không -Real: dừng ở dry-run, không chạy real ---
    Write-Host "[2] Invoke-E2E (dry-run-only)" -ForegroundColor Cyan
    Remove-Runs $hqDir; Remove-Mem $hqDir
    $e2e = Invoke-E2E $hqDir 'tạo pipeline web nhỏ' -RouterSpec 'coo:build;rg_gate:enough;tester:pass'
    Assert ($e2e.stage -eq 'dry-run') "stage = dry-run (không sang real)"
    Assert ($e2e.pass) "dry-run-only pass = true (sẵn sàng real)"

    # --- 3. Sandbox round-trip trên ../hq ---
    Write-Host "[3] Copy/Remove-Sandbox round-trip (../hq)" -ForegroundColor Cyan
    Remove-Runs $hqDir; Remove-Mem $hqDir
    $before = Count-Files $hqDir
    $sb = Copy-ToSandbox $hqDir
    Assert (Test-Path -LiteralPath (Join-Path $sb 'workflow.json')) "sandbox có workflow.json"
    Assert (Test-Path -LiteralPath (Join-Path $sb 'agents')) "sandbox có agents/"
    Remove-Sandbox $sb
    Assert (-not (Test-Path -LiteralPath $sb)) "sandbox teardown sạch"
    $after = Count-Files $hqDir
    Assert ($before -eq $after) "gốc hq/ file count không đổi ($before)"

    # --- 4. Promote-Branch (branch giả) ---
    Write-Host "[4] Promote-Branch (mock branch)" -ForegroundColor Cyan
    $fakeSb = Copy-ToSandbox $hqDir 'e2e-promote-test'
    try {
        $fakeBranchDir = Join-Path $fakeSb 'projects/web-subset'
        New-Item -ItemType Directory -Path (Join-Path $fakeBranchDir 'agents') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fakeBranchDir 'workflow.json') -Value '{"name":"web-subset"}' -Encoding utf8

        $found = Find-GeneratedBranch $fakeSb
        Assert ($found -eq $fakeBranchDir) "Find-GeneratedBranch tìm đúng branch"

        $promoted = Promote-Branch $found 'web-subset-test' -Force
        $destExpected = Join-Path (Get-ProjectsRoot) 'web-subset-test'
        Assert (Test-Path -LiteralPath (Join-Path $promoted 'workflow.json')) "promote → projects/ có workflow.json"
        Assert ((Resolve-Path -LiteralPath $promoted).Path -eq (Resolve-Path -LiteralPath $destExpected).Path) "promote đúng projects/<name>"

        # Cleanup branch promote
        Remove-Item -LiteralPath $promoted -Recurse -Force
        Assert (-not (Test-Path -LiteralPath $promoted)) "branch promote dọn được"
    }
    finally {
        Remove-Sandbox $fakeSb
    }
    # --- 5. Test-DiffScope (unit, mock-simulate, D.5) ---
    Write-Host "[5] Test-DiffScope (unit, mock-simulate)" -ForegroundColor Cyan

    # Dùng examples/ dir làm fake sandbox root (path tuyệt đối tồn tại, không cần file thật —
    # Test-DiffScope chỉ dùng SandboxDir như string prefix để build abs path cho Test-PathInside).
    $d5sb    = $PSScriptRoot
    $allowed = @((Join-Path $d5sb 'projects'))

    # Case 1: builder xoá .runs/ (C.10 vật chứng) → violation
    $b1 = @{ ".runs/abc123/state.json" = 100L; "projects/web/workflow.json" = 200L }
    $a1 = @{ "projects/web/workflow.json" = 200L }   # .runs/ bị xoá
    $r1 = Test-DiffScope $d5sb $allowed -Before $b1 -After $a1
    Assert (-not $r1.ok)                        ".runs/ deleted → ok=False"
    Assert ($r1.violations.Count -gt 0)          ".runs/ deleted → violations non-empty"
    Assert ($r1.violations[0] -match 'deleted.*\.runs') "violation mô tả đúng (.runs deleted)"

    # Case 2: file ngoài whitelist được thêm → violation
    $b2 = @{ "projects/web/workflow.json" = 200L }
    $a2 = @{ "projects/web/workflow.json" = 200L; "hq/agents/evil.md" = 999L }
    $r2 = Test-DiffScope $d5sb $allowed -Before $b2 -After $a2
    Assert (-not $r2.ok)                        "file ngoài whitelist thêm → ok=False"
    Assert ($r2.violations[0] -match 'added.*hq') "violation mô tả đúng (added outside)"

    # Case 3: chỉ đụng projects/ → ok=True
    $b3 = @{ "projects/web/workflow.json" = 200L; "workflow.json" = 300L }
    $a3 = @{ "projects/web/workflow.json" = 999L; "workflow.json" = 300L }
    $r3 = Test-DiffScope $d5sb $allowed -Before $b3 -After $a3
    Assert ($r3.ok)                             "chỉ projects/ touch → ok=True"
    Assert ($r3.violations.Count -eq 0)          "chỉ projects/ → violations rỗng"

    # Case 4: DEFAULT whitelist (không truyền -AllowedPaths) — engine TỰ QUẢN .runs/ + memory/
    # được phép (bug-fix: snapshot bọc cả workflow nên engine tự sinh .runs/state.json,
    # events.ndjson, memory/context.md... KHÔNG được tính builder vi phạm).
    $b4 = @{ "spec.json" = 100L }
    $a4 = @{
        "spec.json"                  = 100L
        ".runs/20260530/state.json"  = 200L   # engine sinh
        ".runs/20260530/events.ndjson" = 201L # engine sinh
        ".runs/latest.json"          = 202L   # engine sinh
        "memory/context.md"          = 203L   # record node ghi
        "projects/app/workflow.json" = 204L   # builder output
    }
    $r4 = Test-DiffScope $d5sb -Before $b4 -After $a4   # default whitelist
    Assert ($r4.ok)                             "default: .runs/+memory/+projects/ → ok=True (không false-positive)"
    Assert ($r4.violations.Count -eq 0)          "default: engine-managed dirs → violations rỗng"

    # Case 5: DEFAULT whitelist vẫn bắt ghi ngoài (vd hq/agents/) → violation
    $b5 = @{ "spec.json" = 100L }
    $a5 = @{ "spec.json" = 100L; ".runs/x/state.json" = 200L; "hq/agents/evil.md" = 999L }
    $r5 = Test-DiffScope $d5sb -Before $b5 -After $a5
    Assert (-not $r5.ok)                        "default: ghi hq/agents/ → ok=False (vẫn bắt out-of-scope)"
    Assert ($r5.violations[0] -match 'added.*hq') "default: violation mô tả đúng (added hq/)"
}
finally {
    Remove-Runs $hqDir
    Remove-Mem  $hqDir
}

Write-Host ''
if ($script:fails -eq 0) { Write-Host "✓ Harness 5.2+D.5 round-trip + dry-run gate + Test-DiffScope PASS (mock-only, 0 token)" -ForegroundColor Green }
else { Write-Host "✗ $($script:fails) assertion fail" -ForegroundColor Red }
exit $script:fails

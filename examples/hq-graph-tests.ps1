# hq-graph-tests.ps1 — mock path-coverage cho graph HQ (Phase 4-B, Session 4.3).
#
# Mock-drive `hq/workflow.json` (11 node, robustness đủ tầng) qua ENGINE_MOCK_ROUTER
# đa-spec ';' — mỗi router steer độc lập, offline, KHÔNG gọi model/đốt token.
# Mỗi test đặt 1 kịch bản router rồi `Invoke-Workflow ../hq -Mock`, assert:
#   (a) status = done ; (b) node terminal đúng (record=thành công / escalate_report=bí) ;
#   (c) path đi qua đúng node (loop quay đúng builder vs planner).
#
# ≥5 path (PLAN Phase 4-B):
#   1. build-happy     coo:build; rg_gate:enough; tester:pass            → record
#   2. fix             coo:fix; tester:pass                             → planner thẳng (bỏ researcher) → record
#   3. re-plan-loop    coo:build; rg_gate:enough; tester:fail_replan,pass → tester→planner→…→record (1 vòng re-plan)
#   4. do-verify-fix   coo:build; rg_gate:enough; tester:fail_fix,pass   → tester→builder→tester→record (1 vòng patch)
#   5. unclear-escalate coo:unclear; escalate_gate:escalate             → escalate_report (bí)
#   6. clarify-escalate coo:build; rg_gate:need_clarify;                → escalate_report
#                       clarify_gate:missing_input; escalate_gate:escalate
#
# Loop-bounding (Phase 4-B Session 4.4 — chứng minh loop DỪNG ĐÚNG, không vô hạn):
#   7. re-plan-escalate  tester:fail_replan,fail_replan,escalate; escalate_gate:escalate
#                        → re-plan 2 vòng (revision bump tới max=3) rồi tester in `escalate`
#                          → escalate_gate → escalate_report. Thoát MỀM trước khi đụng trần.
#   8. max_steps-backstop tester:fail_replan (LUÔN fail → loop không hội tụ)
#                        → engine throw "vượt max_steps" + state=failed. Cầu dao CỨNG (backstop).
#
# LƯU Ý mock-counter: $script:MockAgentCalls (lib/claude.ps1) persist trong 1 process →
# reset TRƯỚC mỗi test để spec đa-nhãn (vd tester:fail_fix,pass) đếm lại từ 0.
# Artifact test (.runs/, hq/memory/) DỌN sau verify.
# Chạy: pwsh examples/hq-graph-tests.ps1  (exit = số path fail).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Dùng tên riêng (không bị clobber bởi $here trong module dot-source).
$hqRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path   # company/examples
$hqRepo   = Split-Path -Parent $hqRoot                        # company
$hqEngine = Join-Path $hqRepo 'engine'
$hqDir    = Join-Path $hqRepo 'hq'                            # project HQ (company/hq)
. (Join-Path $hqEngine 'workflow.ps1')                        # kéo theo lib/claude.ps1 (MockAgentCalls)
. (Join-Path $hqEngine 'status.ps1')

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
function Count-In([object[]]$Path, [string]$Node) {
    @($Path | Where-Object { $_ -eq $Node }).Count
}

# Chạy 1 kịch bản: reset mock-counter + dọn → set router → run -Mock → trả state.
function Invoke-Path([string]$RouterSpec, [string]$Request) {
    $script:MockAgentCalls = @{}            # reset đếm mock (đa-nhãn đếm lại từ 0)
    Remove-Runs $hqDir
    Remove-Mem  $hqDir
    $env:ENGINE_MOCK_ROUTER = $RouterSpec
    $runDir = Invoke-Workflow $hqDir $Request -Mock
    $env:ENGINE_MOCK_ROUTER = $null
    return (Get-RunState $runDir)
}

try {
    # === 1. build-happy → record =========================================
    Write-Host "[1] build-happy: coo:build; rg_gate:enough; tester:pass →" -ForegroundColor Cyan
    $s = Invoke-Path "coo:build;rg_gate:enough;tester:pass" "xây app mới"
    $p = @($s.path)
    Assert ($s.status -eq 'done') "status = done"
    Assert ($p[-1] -eq 'record') "terminal = record (thành công)"
    Assert ($p -join '→' -eq 'coo→researcher→rg_gate→planner→cto→builder→tester→record') `
        "path: $($p -join '→')"

    # === 2. fix → planner thẳng (bỏ researcher) → record =================
    Write-Host "[2] fix: coo:fix; tester:pass →" -ForegroundColor Cyan
    $s = Invoke-Path "coo:fix;tester:pass" "sửa bug"
    $p = @($s.path)
    Assert ($s.status -eq 'done') "status = done"
    Assert ($p[-1] -eq 'record') "terminal = record"
    Assert ($p -notcontains 'researcher') "bỏ researcher (fix vào planner thẳng)"
    Assert ($p -join '→' -eq 'coo→planner→cto→builder→tester→record') `
        "path: $($p -join '→')"

    # === 3. re-plan-loop: tester fail_replan → planner → … → record ======
    Write-Host "[3] re-plan-loop: tester:fail_replan,pass →" -ForegroundColor Cyan
    $s = Invoke-Path "coo:build;rg_gate:enough;tester:fail_replan,pass" "xây app khó"
    $p = @($s.path)
    Assert ($s.status -eq 'done') "status = done"
    Assert ($p[-1] -eq 'record') "terminal = record"
    Assert ((Count-In $p 'planner') -eq 2) "planner thăm 2 lần (1 vòng re-plan)"
    Assert ((Count-In $p 'tester')  -eq 2) "tester thăm 2 lần (fail_replan rồi pass)"
    Assert ($p -join '→' -eq 'coo→researcher→rg_gate→planner→cto→builder→tester→planner→cto→builder→tester→record') `
        "path: $($p -join '→')"

    # === 4. do-verify-fix: tester fail_fix → builder → tester → record ===
    Write-Host "[4] do-verify-fix: tester:fail_fix,pass →" -ForegroundColor Cyan
    $s = Invoke-Path "coo:build;rg_gate:enough;tester:fail_fix,pass" "xây app cần patch"
    $p = @($s.path)
    Assert ($s.status -eq 'done') "status = done"
    Assert ($p[-1] -eq 'record') "terminal = record"
    Assert ((Count-In $p 'builder') -eq 2) "builder thăm 2 lần (1 vòng patch)"
    Assert ((Count-In $p 'planner') -eq 1) "planner CHỈ 1 lần (fix nhỏ, không re-plan)"
    Assert ($p -join '→' -eq 'coo→researcher→rg_gate→planner→cto→builder→tester→builder→tester→record') `
        "path: $($p -join '→')"

    # === 5. unclear-escalate → escalate_report (bí) ======================
    Write-Host "[5] unclear-escalate: coo:unclear; escalate_gate:escalate →" -ForegroundColor Cyan
    $s = Invoke-Path "coo:unclear;escalate_gate:escalate" "ờm cái gì đó??"
    $p = @($s.path)
    Assert ($s.status -eq 'done') "status = done"
    Assert ($p[-1] -eq 'escalate_report') "terminal = escalate_report (bí)"
    Assert ($p -join '→' -eq 'coo→escalate_gate→escalate_report') "path: $($p -join '→')"

    # === 6. clarify-escalate → escalate_report ===========================
    Write-Host "[6] clarify-escalate: rg_gate:need_clarify; clarify_gate:missing_input; escalate_gate:escalate →" -ForegroundColor Cyan
    $s = Invoke-Path "coo:build;rg_gate:need_clarify;clarify_gate:missing_input;escalate_gate:escalate" "yêu cầu mơ hồ"
    $p = @($s.path)
    Assert ($s.status -eq 'done') "status = done"
    Assert ($p[-1] -eq 'escalate_report') "terminal = escalate_report"
    Assert ($p -join '→' -eq 'coo→researcher→rg_gate→clarify_gate→escalate_gate→escalate_report') `
        "path: $($p -join '→')"

    # === 7. re-plan-escalate: loop DỪNG mềm khi revision≥max → escalate_report ===
    # tester in fail_replan 2 lần (revision bump tới trần max=3) rồi escalate → escalate_gate.
    Write-Host "[7] re-plan-escalate (revision≥max): tester:fail_replan,fail_replan,escalate; escalate_gate:escalate →" -ForegroundColor Cyan
    $s = Invoke-Path "coo:build;rg_gate:enough;tester:fail_replan,fail_replan,escalate;escalate_gate:escalate" "xây app rất khó"
    $p = @($s.path)
    Assert ($s.status -eq 'done') "status = done (thoát mềm, không treo)"
    Assert ($p[-1] -eq 'escalate_report') "terminal = escalate_report (bí sau N vòng re-plan)"
    Assert ((Count-In $p 'tester')  -eq 3) "tester thăm 3 lần (fail_replan ×2 rồi escalate)"
    Assert ((Count-In $p 'planner') -eq 3) "planner thăm 3 lần (re-plan ×2 + initial)"
    Assert ($p -notcontains 'record') "KHÔNG vào record (không phải thành công)"
    Assert ($p -join '→' -eq 'coo→researcher→rg_gate→planner→cto→builder→tester→planner→cto→builder→tester→planner→cto→builder→tester→escalate_gate→escalate_report') `
        "path: $($p -join '→')"

    # === 8. max_steps backstop: loop KHÔNG hội tụ → engine cầu dao cứng =========
    # tester:fail_replan (1 nhãn = LUÔN fail) → planner→cto→builder→tester lặp mãi → chạm max_steps=40.
    Write-Host "[8] max_steps backstop: tester:fail_replan (luôn fail) → engine throw vượt max_steps →" -ForegroundColor Cyan
    $script:MockAgentCalls = @{}
    Remove-Runs $hqDir
    Remove-Mem  $hqDir
    $env:ENGINE_MOCK_ROUTER = "coo:build;rg_gate:enough;tester:fail_replan"
    $threw = $false; $errMsg = ''
    try { $null = Invoke-Workflow $hqDir "loop mãi không dừng" -Mock }
    catch { $threw = $true; $errMsg = $_.Exception.Message }
    $env:ENGINE_MOCK_ROUTER = $null
    Assert $threw "engine throw khi vượt max_steps (cầu dao cứng)"
    Assert ($errMsg -match 'max_steps') "thông điệp nhắc max_steps: $errMsg"
    $st = Get-RunState (Get-LatestRunDir $hqDir)
    Assert ($st.status -eq 'failed') "state.status = failed (loop không hội tụ)"
    Assert (@($st.path).Count -ge ([int]$st.max_steps - 1)) "đã chạy tới sát trần max_steps ($($st.max_steps))"
}
finally {
    Remove-Runs $hqDir
    Remove-Mem  $hqDir
    $env:ENGINE_MOCK_ROUTER = $null
}

# === Tổng kết ============================================================
Write-Host ''
if ($script:fails -eq 0) { Write-Host "✓ TẤT CẢ path graph HQ đi đúng terminal + đúng node" -ForegroundColor Green }
else                     { Write-Host "✗ $($script:fails) assertion FAIL" -ForegroundColor Red }
exit $script:fails

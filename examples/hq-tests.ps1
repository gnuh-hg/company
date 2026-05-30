# hq-tests.ps1 — per-agent mock test cho 5 agent HQ (Phase 3-B.2).
#
# Test ĐƠN LẺ từng agent bằng mock (chưa nối graph HQ — đó là Phase 4):
#   COO     → workflow 1 router + 3 edge when; ENGINE_MOCK_ROUTER steer 3 path (build/fix/unclear).
#   Planner → Test-PlanSchema: plan dài + ngắn valid; thiếu 'verify' → fail.
#   CTO     → Test-BuildSpec: spec tiny-api valid; vai ngoài catalog → fail.
#   Builder → Invoke-BuildSpec spec hợp lệ → validate exit 0 + run -Mock done; pattern stamp đúng.
#   Tester  → record-node memory_write → run mock ghi memory/context.md + Test-StructuralGate verdict.
#
# Tất cả mock offline (không gọi model). Artifact test (.runs/, memory/, outDir builder) DỌN sau verify.
# Chạy: pwsh examples/hq-tests.ps1  (exit = số test fail).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# NOTE: các module engine dot-source dưới đây cũng gán $here trong scope chung →
# dùng tên riêng $hqRoot/$hqEngine (không bị clobber sau khi dot-source).
$hqRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path   # company/examples
$hqRepo   = Split-Path -Parent $hqRoot                        # company
$hqEngine = Join-Path $hqRepo 'engine'
. (Join-Path $hqEngine 'workflow.ps1')
. (Join-Path $hqEngine 'validate.ps1')
. (Join-Path $hqEngine 'status.ps1')
. (Join-Path $hqEngine 'check.ps1')
. (Join-Path $hqEngine 'spec.ps1')

$script:fails = 0
function Assert([bool]$Cond, [string]$Msg) {
    if ($Cond) { Write-Host "  ✓ $Msg" -ForegroundColor Green }
    else       { Write-Host "  ✗ $Msg" -ForegroundColor Red; $script:fails++ }
}
function Remove-Runs([string]$Dir) {
    $r = Join-Path $Dir '.runs'
    if (Test-Path -LiteralPath $r) { Remove-Item -LiteralPath $r -Recurse -Force }
}

# === 1. COO — router 3 path ===========================================
Write-Host "[COO] router 3 nhãn build/fix/unclear →" -ForegroundColor Cyan
$cooDir = Join-Path $hqRoot 'hq-coo'
foreach ($case in @(
    @{ label = 'build';   terminal = 'build_path' },
    @{ label = 'fix';     terminal = 'fix_path' },
    @{ label = 'unclear'; terminal = 'unclear_path' }
)) {
    Remove-Runs $cooDir
    $env:ENGINE_MOCK_ROUTER = "coo:$($case.label)"
    $runDir = Invoke-Workflow $cooDir "làm gì đó" -Mock
    $state  = Get-RunState $runDir
    $path   = @($state.path)
    Assert ($state.status -eq 'done' -and $path -contains $case.terminal) `
        "nhãn '$($case.label)' → done qua node '$($case.terminal)' (path: $($path -join '→'))"
}
$env:ENGINE_MOCK_ROUTER = $null
Remove-Runs $cooDir

# === 2. Planner — Test-PlanSchema =====================================
Write-Host "[Planner] plan-as-data dài/ngắn valid; thiếu verify → fail →" -ForegroundColor Cyan
$rLong  = Test-PlanSchema (Read-Json (Join-Path $hqRoot 'hq-planner/plan-long.json'))
$rShort = Test-PlanSchema (Read-Json (Join-Path $hqRoot 'hq-planner/plan-short.json'))
$rBad   = Test-PlanSchema (Read-Json (Join-Path $hqRoot 'hq-planner/plan-bad.json'))
Assert ($rLong.ok)  "plan dài (nhiều steps + open_questions) → ok"
Assert ($rShort.ok) "plan ngắn (1 step, open_questions rỗng) → ok"
Assert (-not $rBad.ok -and (@($rBad.errors) -join ' ') -match 'verify') "plan thiếu 'verify' → fail, reason đúng field"

# === 3. CTO — Test-BuildSpec ==========================================
Write-Host "[CTO] build-spec tiny-api valid; vai ngoài catalog → fail →" -ForegroundColor Cyan
$rOk  = Test-BuildSpec (Read-Json (Join-Path $hqRoot 'hq-cto/spec-ok.json'))
$rBad = Test-BuildSpec (Read-Json (Join-Path $hqRoot 'hq-cto/spec-bad.json'))
Assert ($rOk.ok) "spec tiny-api (2 vai catalog + pattern dv) → ok, parse được"
Assert (-not $rBad.ok -and (@($rBad.errors) -join ' ') -match 'nonexistent-role') "spec vai ngoài catalog → fail, reason đúng field"

# === 4. Builder — Invoke-BuildSpec → validate + run -Mock =============
Write-Host "[Builder] Invoke-BuildSpec → cây + workflow.json → validate + run -Mock →" -ForegroundColor Cyan
$outDir = Join-Path ($hqRepo) 'sandbox/_hq_builder_test'
if (Test-Path -LiteralPath $outDir) { Remove-Item -LiteralPath $outDir -Recurse -Force }
try {
    $spec = Read-Json (Join-Path $hqRoot 'hq-cto/spec-ok.json')
    Invoke-BuildSpec $spec $outDir | Out-Null
    $wf = Read-Json (Join-Path $outDir 'workflow.json')
    $stampedOk = (@($wf.nodes).id -contains 'dv_builder') -and -not ((Get-Content -Raw (Join-Path $outDir 'workflow.json')) -match '__P__')
    Assert ((Test-Path (Join-Path $outDir 'agents/pm.md')) -and (Test-Path (Join-Path $outDir 'agents/api.md'))) "copy vai catalog → agents/pm.md + agents/api.md"
    Assert $stampedOk "pattern stamp đúng (dv_builder có, không còn '__P__')"
    $vr = Test-Workflow $outDir
    Assert (@($vr.errors).Count -eq 0) "validate chi nhánh sinh ra → exit 0"
    $env:ENGINE_MOCK_ROUTER = 'dv_verdict:fail,pass'
    $runDir = Invoke-Workflow $outDir "ping" -Mock
    $env:ENGINE_MOCK_ROUTER = $null
    Assert ((Get-RunState $runDir).status -eq 'done') "run -Mock (loop fail→pass) → done"
}
finally {
    if (Test-Path -LiteralPath $outDir) { Remove-Item -LiteralPath $outDir -Recurse -Force }
}

# === 5. Tester — record-node ghi memory + check verdict ===============
Write-Host "[Tester] record-node memory_write + Test-StructuralGate →" -ForegroundColor Cyan
$tDir   = Join-Path $hqRoot 'hq-tester'
$memCtx = Join-Path $tDir 'memory/context.md'
Remove-Runs $tDir
if (Test-Path -LiteralPath (Join-Path $tDir 'memory')) { Remove-Item -LiteralPath (Join-Path $tDir 'memory') -Recurse -Force }
try {
    $runDir = Invoke-Workflow $tDir "việc cần làm" -Mock
    Assert ((Get-RunState $runDir).status -eq 'done') "run -Mock → done"
    Assert (Test-Path -LiteralPath $memCtx) "node record (memory_write: context) → tạo memory/context.md"
    Assert ((Get-Content -Raw $memCtx) -match '##') "memory entry date-stamped (có delimiter '##')"
    Remove-Runs $tDir
    $gate = Test-StructuralGate $tDir
    Assert ($gate.pass) "Test-StructuralGate (validate+run-Mock+output-key) → pass"
}
finally {
    Remove-Runs $tDir
    if (Test-Path -LiteralPath (Join-Path $tDir 'memory')) { Remove-Item -LiteralPath (Join-Path $tDir 'memory') -Recurse -Force }
}

# === Tổng kết =========================================================
Write-Host ''
if ($script:fails -eq 0) { Write-Host "✓ TẤT CẢ test đơn lẻ 5 agent HQ PASS" -ForegroundColor Green }
else                     { Write-Host "✗ $($script:fails) assertion FAIL" -ForegroundColor Red }
exit $script:fails

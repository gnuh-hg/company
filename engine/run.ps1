# run.ps1 — dispatcher: parse command → gọi module
# Implement Session 3.1.
#
# Surface lệnh duy nhất (QĐ-3):  ./run.ps1 <command> <project> [args]
# Gom mọi command về một entry point dùng chung cho cả Claude lẫn user.
#   run       <proj> "<request>" [-Mock] [-Model m]  → workflow.ps1  (Invoke-Workflow)
#   graph     <proj> [out.mmd]                        → viz.ps1       (Show-Workflow + Export)
#   validate  <proj>                                  → validate.ps1  (Test-Workflow)
#   status    <proj>                                  → status.ps1 (Show-Status, state v2)
#   logs      <proj> [node]                           → status.ps1 (Show-Logs, theo lượt thăm)
#   build     <spec-file> [<outName>]                 → spec.ps1      (Invoke-BuildSpec)
#   autobuild <proj> "<req>" [-Router s] [-Real]      → e2e.ps1       (Invoke-E2E)
#   autofix   <proj> "<req>" -Seed <br> -Branch <n>   → e2e.ps1       (Invoke-E2EFix)
#   edit      <proj>                                  → edit.ps1      (Invoke-Edit, TUI)
#   selftest  [all]                                   → test-runner.ps1 (Invoke-SelfTest)
#
# Alias tương thích (tên cũ vẫn chạy): viz→graph, e2e→autobuild, e2efix→autofix, test→selftest.
# <project> nhận tên gọn ('hello') hoặc path ('examples/hello'); resolve về thư mục thật.

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'workflow.ps1')   # kéo theo lib/* + bridge.ps1
. (Join-Path $here 'validate.ps1')
. (Join-Path $here 'viz.ps1')
. (Join-Path $here 'edit.ps1')
. (Join-Path $here 'status.ps1')
. (Join-Path $here 'check.ps1')
. (Join-Path $here 'sandbox.ps1')
. (Join-Path $here 'spec.ps1')
. (Join-Path $here 'e2e.ps1')
. (Join-Path $here 'test-runner.ps1')

function Show-Help {
    <#
    .SYNOPSIS In help đầy đủ: mọi command + cú pháp + mô tả.
    #>
    $lines = @(
        'Workflow Engine — surface lệnh duy nhất.   ./run.ps1 <command> <project> [args]',
        '',
        '  <project> = tên gọn (vd: hello) hoặc path (vd: examples/hello), hoặc ''hq''.',
        '',
        'PROJECT — chạy & soi một workflow:',
        '  run      <proj> "<request>" [-Mock] [-Model m] [-AutoApprove]  Chạy pipeline end-to-end',
        '  resume   <proj> [-Mock] [-Model m] [-Decision d] [-AutoApprove] Tiếp tục run dở/failed/awaiting',
        '  graph    <proj> [out.mmd]                        In DAG ASCII + xuất Mermaid        (cũ: viz)',
        '  validate <proj>                                  Kiểm tra DAG hợp lệ (cycle/agent/key)',
        '  status   <proj>                                  Trạng thái run gần nhất',
        '  logs     <proj> [node]                           Prompt/output từng lượt thăm',
        '  check    <proj>                                  Tester tầng cấu trúc (validate+run-Mock+output-key)',
        '  trial    <proj> [-Model m]                       Tester tầng trial THẬT (assert trial[])',
        '',
        'BUILD — HQ sinh/sửa chi nhánh:',
        '  build     <spec-file> [<outName>]                Builder deterministic: spec → chi nhánh',
        '  autobuild <proj> "<req>" [-Router s] [-Real]     HQ chạy thật → verify → promote    (cũ: e2e)',
        '  autofix   <proj> "<req>" -Seed <br> -Branch <n>  Fix-loop branch hỏng → verify      (cũ: e2efix)',
        '',
        'AUTHOR — soạn workflow:',
        '  edit     <proj>                                  TUI thêm/xoá/đổi node + agent + deps',
        '',
        'Advanced:',
        '  selftest [all]                                   Chạy bộ test engine (script+stamp+mem-demo)  (cũ: test)',
        '',
        'Không arg / help / -h / --help → in trợ giúp này.',
        'Tương thích: tên cũ (viz/e2e/e2efix/test) vẫn chạy như alias.',
        '',
        'Ví dụ:',
        '  ./run.ps1 run hello "ping" -Mock',
        '  ./run.ps1 graph hello',
        '  ./run.ps1 validate hello'
    )
    foreach ($l in $lines) { Write-Host $l }
}

function Show-RouterHint {
    <#
    .SYNOPSIS
        A-01 hint: khi run -Mock vấp router throw (nhãn không khớp 'when' nào), nhắc rằng
        -Mock trần KHÔNG lái router — cần $env:ENGINE_MOCK_ROUTER='<agent>:label;...'.
        Chỉ in khi đang chạy mock + lỗi đúng họ router-mismatch (tránh nhiễu các lỗi khác).
    #>
    param([string]$ErrorMessage, [bool]$Mock)
    if (-not $Mock) { return }
    if ($ErrorMessage -notmatch "không khớp 'when'") { return }
    if ($env:ENGINE_MOCK_ROUTER) { return }
    Write-Host "  gợi ý: -Mock trần không lái router. Đặt `$env:ENGINE_MOCK_ROUTER='<agent>:label;...' để chọn nhánh (vd 'coo:build;tester:pass')." -ForegroundColor Yellow
}

function Resolve-ProjectDir {
    <#
    .SYNOPSIS
        Đưa tên gọn / path về thư mục project thật. Thử theo thứ tự: path nguyên trạng →
        company/projects/<name> (app thật) → company/examples/<name> (demo/fixture) →
        company/<name> (project top-level, vd 'hq'). Throw nếu không tìm thấy.
    .OUTPUTS [string] đường dẫn project dir.
    #>
    param([Parameter(Mandatory, Position = 0)][string]$Project)

    if (Test-Path -LiteralPath $Project) { return $Project }
    # A-05-fix (C.9): gom MỌI nơi khớp tên gọn → cảnh báo khi >1 (vd projects/ + examples/ cùng tên,
    # thường gặp sau khi promote 1 branch trùng tên fixture). Vẫn ưu tiên projects/ (phần tử đầu).
    $found = @()
    foreach ($root in @('../projects', '../examples', '..')) {
        $candidate = Join-Path $here $root $Project
        if (Test-Path -LiteralPath $candidate) { $found += $candidate }
    }
    if ($found.Count -eq 0) {
        throw "Không tìm thấy project '$Project' (đã thử '$Project', 'projects/$Project', 'examples/$Project', '../$Project')."
    }
    if ($found.Count -gt 1) {
        Write-Warning "Tên '$Project' khớp $($found.Count) nơi: $($found -join ', '). Dùng '$($found[0])' (projects/ ưu tiên). Truyền path đầy đủ để chọn bản khác."
    }
    return $found[0]
}

# --- Phân tách $args: switch (-Mock / -Model) tách khỏi positional ---
function Split-DispatchArgs {
    param([string[]]$RawArgs)
    # [string[]] @() bị PowerShell ép về $null → guard trước khi đụng .Count (StrictMode).
    if ($null -eq $RawArgs) { return @{ Positional = @(); Mock = $false; Model = $null; Real = $false; Router = $null; KeepSandbox = $false; Seed = $null; Branch = $null; Decision = $null; AutoApprove = $false } }
    $pos         = [System.Collections.Generic.List[string]]::new()
    $mock        = $false
    $model       = $null
    $real        = $false
    $router      = $null
    $keep        = $false
    $seed        = $null
    $branch      = $null
    $decision    = $null
    $autoApprove = $false
    for ($i = 0; $i -lt $RawArgs.Count; $i++) {
        $a = $RawArgs[$i]
        switch -Regex ($a) {
            '^-Mock$'        { $mock = $true }
            '^-Real$'        { $real = $true }
            '^-KeepSandbox$' { $keep = $true }
            '^-AutoApprove$' { $autoApprove = $true }
            '^-Model$'       { $i++; if ($i -lt $RawArgs.Count) { $model = $RawArgs[$i] }    else { Write-Warning "Flag '$a' thiếu value — bỏ qua." } }
            '^-Router$'      { $i++; if ($i -lt $RawArgs.Count) { $router = $RawArgs[$i] }   else { Write-Warning "Flag '$a' thiếu value — bỏ qua." } }
            '^-Seed$'        { $i++; if ($i -lt $RawArgs.Count) { $seed = $RawArgs[$i] }     else { Write-Warning "Flag '$a' thiếu value — bỏ qua." } }
            '^-Branch$'      { $i++; if ($i -lt $RawArgs.Count) { $branch = $RawArgs[$i] }   else { Write-Warning "Flag '$a' thiếu value — bỏ qua." } }
            '^-Decision$'    { $i++; if ($i -lt $RawArgs.Count) { $decision = $RawArgs[$i] } else { Write-Warning "Flag '$a' thiếu value — bỏ qua." } }
            default          { $pos.Add($a) }
        }
    }
    return @{ Positional = $pos.ToArray(); Mock = $mock; Model = $model; Real = $real; Router = $router; KeepSandbox = $keep; Seed = $seed; Branch = $branch; Decision = $decision; AutoApprove = $autoApprove }
}

function Invoke-Dispatch {
    <#
    .SYNOPSIS Route 1 command tới module tương ứng. Trả exit code.
    #>
    param([Parameter(Position = 0)][string[]]$RawArgs)

    if ($null -eq $RawArgs -or $RawArgs.Count -lt 1) {
        Show-Help
        return 0
    }

    $command = $RawArgs[0].ToLower()
    # Alias tương thích (B.2): map tên-cũ → tên-mới, im lặng (route thẳng, không in note).
    # Sau bước này mọi nhánh switch + allowlist chỉ cần biết tên mới.
    $aliasMap = @{ 'viz' = 'graph'; 'e2e' = 'autobuild'; 'e2efix' = 'autofix'; 'test' = 'selftest' }
    if ($aliasMap.ContainsKey($command)) { $command = $aliasMap[$command] }
    $rest    = if ($RawArgs.Count -gt 1) { $RawArgs[1..($RawArgs.Count - 1)] } else { @() }
    $parsed  = Split-DispatchArgs $rest
    $pos     = $parsed.Positional

    if ($command -in @('help', '-h', '--help')) { Show-Help; return 0 }

    if ($command -notin @('run', 'resume', 'graph', 'validate', 'check', 'trial', 'build', 'autobuild', 'autofix', 'status', 'logs', 'edit', 'selftest')) {
        Write-Host "Command không hợp lệ: '$command'" -ForegroundColor Red
        Write-Host ''
        Show-Help
        return 2
    }

    # 'selftest' không cần <project> → xử lý trước project-count check.
    if ($command -eq 'selftest') {
        return (Invoke-SelfTest $pos)
    }

    if ($pos.Count -lt 1) {
        Write-Host "Command '$command' cần <project>." -ForegroundColor Red
        Show-Help
        return 2
    }

    # 'build' nhận <spec-file> (không phải project) → xử lý trước Resolve-ProjectDir.
    if ($command -eq 'build') {
        $specFile = $pos[0]
        if (-not (Test-Path -LiteralPath $specFile)) {
            Write-Host "build: không tìm thấy spec-file '$specFile'" -ForegroundColor Red
            return 2
        }
        $spec    = Read-Json $specFile
        $outName = if ($pos.Count -ge 2) { $pos[1] } else { [string](Get-Prop $spec 'name') }
        if ([string]::IsNullOrWhiteSpace($outName)) {
            Write-Host "build: spec thiếu 'name' và không truyền <outName>" -ForegroundColor Red
            return 2
        }
        # outName là path (có / hoặc \) → dùng nguyên trạng; ngược lại → projects/<outName>.
        $outDir = if ($outName -match '[\\/]') { $outName } else { Join-Path $here '../projects' $outName }
        try {
            $result = Invoke-BuildSpec $spec $outDir
        }
        catch {
            Write-Host "✗ Build thất bại: $($_.Exception.Message)" -ForegroundColor Red
            return 1
        }
        Write-Host "✓ Build xong → $result" -ForegroundColor Green
        return 0
    }

    $projectDir = Resolve-ProjectDir $pos[0]

    switch ($command) {
        'run' {
            if ($pos.Count -lt 2) {
                Write-Host "run cần: run <project> ""<request>""" -ForegroundColor Red
                return 2
            }
            try {
                $runDir = Invoke-Workflow $projectDir $pos[1] -Mock:$parsed.Mock -Model $parsed.Model -AutoApprove:$parsed.AutoApprove
            }
            catch {
                Write-Host "✗ Run thất bại: $($_.Exception.Message)" -ForegroundColor Red
                Show-RouterHint $_.Exception.Message $parsed.Mock
                return 1
            }
            # D.4: phân biệt done vs awaiting — approval gate dừng mà không throw.
            $finalState = Get-RunState $runDir
            if ((Get-Prop $finalState 'status') -eq 'awaiting') {
                $awaitData  = Get-Prop $finalState 'awaiting'
                $gateNode   = if ($awaitData -and $awaitData.node)   { $awaitData.node }   else { '?' }
                $gatePrompt = if ($awaitData -and $awaitData.prompt) { [string]$awaitData.prompt } else { '' }
                Write-Host "⏸ Run dừng tại gate '$gateNode' — chờ người duyệt." -ForegroundColor Yellow
                if ($gatePrompt) { Write-Host "  Prompt:  $gatePrompt" -ForegroundColor Yellow }
                Write-Host "  Tiếp tục: ./run.ps1 resume $($pos[0]) -Decision approve" -ForegroundColor Yellow
                return 3
            }
            Write-Host "✓ Run xong → $runDir" -ForegroundColor Green
            return 0
        }
        'resume' {
            $decArg = if ($parsed.Decision) { $parsed.Decision } else { '' }
            try {
                $runDir = Invoke-Workflow $projectDir -Resume -Mock:$parsed.Mock -Model $parsed.Model -Decision $decArg -AutoApprove:$parsed.AutoApprove
            }
            catch {
                Write-Host "✗ Resume thất bại: $($_.Exception.Message)" -ForegroundColor Red
                Show-RouterHint $_.Exception.Message $parsed.Mock
                return 1
            }
            # D.4: kiểm xem resume có dừng lại ở gate kế không.
            $finalState = Get-RunState $runDir
            if ((Get-Prop $finalState 'status') -eq 'awaiting') {
                $awaitData  = Get-Prop $finalState 'awaiting'
                $gateNode   = if ($awaitData -and $awaitData.node)   { $awaitData.node }   else { '?' }
                $gatePrompt = if ($awaitData -and $awaitData.prompt) { [string]$awaitData.prompt } else { '' }
                Write-Host "⏸ Resume dừng tại gate '$gateNode' — chờ người duyệt." -ForegroundColor Yellow
                if ($gatePrompt) { Write-Host "  Prompt:  $gatePrompt" -ForegroundColor Yellow }
                Write-Host "  Tiếp tục: ./run.ps1 resume $($pos[0]) -Decision approve" -ForegroundColor Yellow
                return 3
            }
            Write-Host "✓ Resume xong → $runDir" -ForegroundColor Green
            return 0
        }
        'graph' {
            Show-Workflow $projectDir
            $outArg = if ($pos.Count -ge 2) { $pos[1] } else { $null }
            $out = Export-WorkflowMermaid $projectDir $outArg
            Write-Host ''
            Write-Host "Mermaid → $out" -ForegroundColor Green
            return 0
        }
        'validate' {
            $result = Test-Workflow $projectDir
            return (Write-ValidateResult $result $projectDir)
        }
        'check' {
            $result = Test-StructuralGate $projectDir
            return (Write-CheckResult $result $projectDir)
        }
        'trial' {
            # Tầng 1 — cấu trúc (mock) trong sandbox cô lập: tiền đề, free/deterministic.
            $scaffold    = Invoke-TrialScaffold $projectDir
            $structFails = Write-CheckResult $scaffold.result "trial→cấu trúc: $($pos[0])"
            if ($structFails -ne 0) {
                Write-Host "⊘ Bỏ qua tầng trial THẬT — tầng cấu trúc fail." -ForegroundColor Yellow
                return $structFails
            }
            # Tầng 2 — trial THẬT (no -Mock, gọi model) trên artifact trong sandbox cô lập.
            $trials = @(Get-Trials $projectDir)
            if ($trials.Count -eq 0) {
                Write-Host ''
                Write-Host "⊘ Project không khai 'trial[]' trong workflow.json — chỉ chạy tầng cấu trúc." -ForegroundColor Yellow
                return 0
            }
            Write-Host ''
            $trialResult = Invoke-Trial $projectDir $trials -Model $parsed.Model
            return (Write-TrialResult $trialResult "trial-real: $($pos[0])")
        }
        'autobuild' {
            # Real-run harness (Phase 5): dry-run gate (free) → -Real để đốt token + sandbox→promote.
            if ($pos.Count -lt 2) {
                Write-Host "autobuild cần: autobuild <project> ""<request>"" [-Router spec] [-Real]" -ForegroundColor Red
                return 2
            }
            try {
                $result = Invoke-E2E $projectDir $pos[1] -RouterSpec $parsed.Router -Real:$parsed.Real -KeepSandbox:$parsed.KeepSandbox
            }
            catch {
                Write-Host "✗ E2E thất bại: $($_.Exception.Message)" -ForegroundColor Red
                return 1
            }
            return (Write-E2EResult $result)
        }
        'autofix' {
            # Fix-loop harness (Phase 5.4): seed branch hỏng → dry-run gate → (-Real) HQ fix patch → verify fail→pass.
            if ($pos.Count -lt 2) {
                Write-Host "autofix cần: autofix <project> ""<request>"" -Seed <broken-branch> -Branch <name> [-Router s] [-Real]" -ForegroundColor Red
                return 2
            }
            if ([string]::IsNullOrWhiteSpace($parsed.Seed) -or [string]::IsNullOrWhiteSpace($parsed.Branch)) {
                Write-Host "autofix cần -Seed <broken-branch-dir> + -Branch <name>" -ForegroundColor Red
                return 2
            }
            try {
                $result = Invoke-E2EFix $projectDir $pos[1] -SeedBranchDir $parsed.Seed -BranchName $parsed.Branch -RouterSpec $parsed.Router -Real:$parsed.Real -KeepSandbox:$parsed.KeepSandbox
            }
            catch {
                Write-Host "✗ E2E-fix thất bại: $($_.Exception.Message)" -ForegroundColor Red
                return 1
            }
            return (Write-E2EResult $result)
        }
        'status' { Show-Status $projectDir; return 0 }
        'logs'   {
            $stepArg = if ($pos.Count -ge 2) { $pos[1] } else { $null }
            Show-Logs $projectDir $stepArg
            return 0
        }
        'edit'   { return (Invoke-Edit $projectDir) }
    }
}

# --- Chạy trực tiếp (không dot-source) ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    $code = Invoke-Dispatch $args
    exit $code
}

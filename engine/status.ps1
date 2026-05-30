# status.ps1 — status + logs viewer cho run gần nhất.
# Implement Session 3.3 · state v2 Session 4.1.
#
# Hai command (route từ run.ps1):
#   status <proj>          → tiến độ run mới nhất: path đã đi + iter mỗi node, started/finished, request
#   logs   <proj> [node]   → prompt + output từng lượt thăm (mọi lượt, hoặc 1 node)
#
# Nguồn dữ liệu (QĐ-4, state v2): projects/<name>/.runs/
#   latest.json              { run, status }                  ← con trỏ run mới nhất
#   <ts>/state.json          { name, request, started, finished, status, error,
#                              entry, max_steps, path[], visits[] }
#                            visit = { seq, node, iter, status, output_key, error }
#   <ts>/<seq>-<node>.prompt.txt  prompt nhét vào claude (theo lượt)
#   <ts>/<seq>-<node>.out.txt     output lượt đó (lịch sử, không ghi đè)
#   <ts>/<output_key>.txt         output MỚI NHẤT của key (latest-wins, nguồn bridge)

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib/json.ps1')

# Get-Prop: accessor StrictMode-safe gom vào lib/json.ps1 (A-06) — đã dot-source ở đầu file.

function Get-LatestRunDir {
    <#
    .SYNOPSIS
        Trả thư mục run mới nhất của project. Ưu tiên con trỏ .runs/latest.json;
        fallback thư mục con .runs/ mới nhất theo tên (timestamp sortable).
        Throw nếu project chưa có run nào.
    .OUTPUTS [string] đường dẫn .runs/<ts>/
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)

    $runsDir = Join-Path $ProjectDir '.runs'
    if (-not (Test-Path -LiteralPath $runsDir)) {
        throw "Chưa có run nào cho project này (thiếu $runsDir). Chạy 'run' trước."
    }

    $latestPtr = Join-Path $runsDir 'latest.json'
    if (Test-Path -LiteralPath $latestPtr) {
        $ptr = Read-Json $latestPtr
        if ($ptr.PSObject.Properties.Name -contains 'run') {
            $candidate = Join-Path $runsDir $ptr.run
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }

    # Fallback: thư mục con mới nhất theo tên (yyyyMMdd-HHmmss sort được).
    $dirs = Get-ChildItem -LiteralPath $runsDir -Directory | Sort-Object Name -Descending
    if ($dirs.Count -lt 1) {
        throw "Chưa có run nào cho project này (thư mục $runsDir rỗng)."
    }
    return $dirs[0].FullName
}

function Get-RunState {
    <#
    .SYNOPSIS Đọc state.json của 1 run dir. Throw nếu thiếu.
    #>
    param([Parameter(Mandatory, Position = 0)][string]$RunDir)
    $statePath = Join-Path $RunDir 'state.json'
    if (-not (Test-Path -LiteralPath $statePath)) {
        throw "Run dir thiếu state.json: $RunDir"
    }
    return Read-Json $statePath
}

function Get-StatusColor {
    param([string]$Status)
    switch ($Status) {
        'done'     { 'Green' }
        'running'  { 'Cyan' }
        'failed'   { 'Red' }
        'awaiting' { 'Yellow' }
        'pending'  { 'DarkGray' }
        default    { 'Gray' }
    }
}

function Get-VisitMark {
    param([string]$Status)
    switch ($Status) {
        'done'     { '✓' }
        'running'  { '…' }
        'failed'   { '✗' }
        'awaiting' { '⏸' }
        default    { '?' }
    }
}

function Show-Status {
    <#
    .SYNOPSIS
        In tiến độ run mới nhất (state v2): đường đi (path) + iter mỗi lượt thăm, thời gian, request.
        Node lặp được (loop) → đo bằng số lượt thăm 'done' / tổng lượt, kèm cầu dao max_steps.
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)

    $runDir = Get-LatestRunDir $ProjectDir
    $state  = Get-RunState $runDir
    $visits = @(Get-Prop $state 'visits')
    $total  = $visits.Count
    $done   = @($visits | Where-Object { (Get-Prop $_ 'status') -eq 'done' }).Count
    $pct    = if ($total -gt 0) { [int]([math]::Round($done * 100.0 / $total)) } else { 0 }
    $maxSteps = Get-Prop $state 'max_steps'

    Write-Host "Run:     $(Split-Path -Leaf $runDir)"
    Write-Host "Project: $($state.name)"
    Write-Host -NoNewline "Status:  "
    Write-Host $state.status -ForegroundColor (Get-StatusColor $state.status)
    Write-Host "Entry:   $(Get-Prop $state 'entry')   (max_steps $maxSteps)"
    Write-Host "Tiến độ: $done/$total lượt done ($pct%)"
    Write-Host "Bắt đầu:  $($state.started)"
    $fin = if ($state.finished) { $state.finished } else { '(chưa xong)' }
    Write-Host "Kết thúc: $fin"
    Write-Host "Request: $($state.request)"
    $err = Get-Prop $state 'error'
    if (-not [string]::IsNullOrWhiteSpace($err)) {
        Write-Host -NoNewline "Lỗi:     "
        Write-Host $err -ForegroundColor Red
    }
    # D.4: hiện gate info + resume hint khi đang awaiting.
    if ($state.status -eq 'awaiting') {
        $awaitData = Get-Prop $state 'awaiting'
        if ($awaitData) {
            $gateNode   = $awaitData.node
            $gatePrompt = if ($awaitData.prompt) { [string]$awaitData.prompt } else { '' }
            $gateChoices = @(Get-Prop $awaitData 'choices')
            Write-Host -NoNewline "Gate:    "
            Write-Host "node '$gateNode' — chờ người duyệt" -ForegroundColor Yellow
            if ($gatePrompt)         { Write-Host "  Prompt:  $gatePrompt" }
            if ($gateChoices.Count -gt 0) { Write-Host "  Choices: $($gateChoices -join ' | ')" }
            Write-Host "  Resume:  ./run.ps1 resume <proj> -Decision approve" -ForegroundColor Yellow
        }
    }

    $path = @(Get-Prop $state 'path')
    Write-Host ''
    Write-Host "Đường đi: $(if ($path.Count -gt 0) { $path -join ' → ' } else { '(chưa đi)' })"

    Write-Host ''
    Write-Host 'Lượt thăm:'
    foreach ($v in $visits) {
        $vstatus = Get-Prop $v 'status'
        $mark    = Get-VisitMark $vstatus
        Write-Host -NoNewline ("  {0} [{1,2}] " -f $mark, (Get-Prop $v 'seq'))
        Write-Host -NoNewline ("{0,-16}" -f (Get-Prop $v 'node'))
        Write-Host -NoNewline (" iter {0,-3}→ " -f (Get-Prop $v 'iter'))
        Write-Host -NoNewline ("{0,-9}" -f $vstatus) -ForegroundColor (Get-StatusColor $vstatus)
        Write-Host "  [$(Get-Prop $v 'output_key')]"
        $verr = Get-Prop $v 'error'
        if (-not [string]::IsNullOrWhiteSpace($verr)) {
            Write-Host "       └─ $verr" -ForegroundColor Red
        }
    }
}

function Show-Logs {
    <#
    .SYNOPSIS
        In prompt + output từng LƯỢT THĂM của run mới nhất (state v2). Truyền $NodeName → chỉ
        các lượt của node đó (mọi vòng lặp). File theo lượt: <seq>-<node>.prompt.txt / .out.txt.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Position = 1)][string]$NodeName
    )

    $runDir = Get-LatestRunDir $ProjectDir
    $state  = Get-RunState $runDir
    $visits = @(Get-Prop $state 'visits')

    if ($NodeName) {
        $visits = @($visits | Where-Object { (Get-Prop $_ 'node') -eq $NodeName })
        if ($visits.Count -lt 1) {
            $nodes = @(@(Get-Prop $state 'visits') | ForEach-Object { Get-Prop $_ 'node' } | Select-Object -Unique) -join ', '
            throw "Không có node '$NodeName' trong run gần nhất. Node đã đi: $nodes"
        }
    }

    Write-Host "Run: $(Split-Path -Leaf $runDir)  ($ProjectDir)"
    foreach ($v in $visits) {
        $seq    = Get-Prop $v 'seq'
        $node   = Get-Prop $v 'node'
        $vstatus = Get-Prop $v 'status'
        $base   = "$seq-$node"

        Write-Host ''
        Write-Host ('═' * 60) -ForegroundColor DarkGray
        Write-Host -NoNewline "■ [$seq] $node  (iter $(Get-Prop $v 'iter'))  "
        Write-Host $vstatus -ForegroundColor (Get-StatusColor $vstatus)
        Write-Host ('─' * 60) -ForegroundColor DarkGray

        $promptPath = Join-Path $runDir "$base.prompt.txt"
        Write-Host 'PROMPT:' -ForegroundColor Yellow
        if (Test-Path -LiteralPath $promptPath) {
            Write-Host (Get-Content -LiteralPath $promptPath -Raw -Encoding utf8)
        } else {
            Write-Host '  (chưa có — lượt chưa chạy)' -ForegroundColor DarkGray
        }

        $outPath = Join-Path $runDir "$base.out.txt"
        Write-Host 'OUTPUT:' -ForegroundColor Yellow
        if (Test-Path -LiteralPath $outPath) {
            Write-Host (Get-Content -LiteralPath $outPath -Raw -Encoding utf8)
        } else {
            Write-Host '  (chưa có — lượt chưa xong)' -ForegroundColor DarkGray
        }
    }
}

# --- Chạy trực tiếp (không dot-source) ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 2) {
        Write-Host "Cách dùng: ./status.ps1 <status|logs> <projectDir> [node]" -ForegroundColor Yellow
        exit 2
    }
    $sub = $args[0].ToLower()
    switch ($sub) {
        'status' { Show-Status $args[1]; exit 0 }
        'logs'   { Show-Logs $args[1] $(if ($args.Count -ge 3) { $args[2] } else { $null }); exit 0 }
        default  { Write-Host "Sub không hợp lệ: '$sub' (status|logs)" -ForegroundColor Red; exit 2 }
    }
}

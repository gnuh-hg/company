# edit.ps1 — TUI sửa workflow.json (thêm/xoá/đổi thứ tự/sửa step) + tự re-validate
# Implement Session 3.2.
#
# Scope 3.2: menu tương tác trong pwsh để dựng/sửa pipeline mà không cần gõ JSON tay:
#   - liệt kê step hiện tại (index + step/agent/output_key/input)
#   - thêm step: chọn agent từ thư mục agents/, nhập step id / output_key / input template
#   - xoá step theo index
#   - đổi thứ tự step (move from → to)
#   - sửa 1 step (agent/input/output_key)
#   - lưu workflow.json rồi tự chạy Test-Workflow (validate) báo kết quả ngay
#   - xem DAG (Show-Workflow) không rời TUI
#
# QĐ-1/QĐ-2: chỉ ghi ngữ nghĩa (name + pipeline), không bao giờ toạ độ. Cạnh suy ra từ {{key}}.
# Input qua Read-Host → pipe được stdin để test/script. EOF (chuỗi rỗng liên tiếp) → tự thoát an toàn.

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib/json.ps1')
. (Join-Path $here 'validate.ps1')   # Get-PromptKeys + Test-Workflow
. (Join-Path $here 'viz.ps1')        # Show-Workflow (xem DAG ngay trong TUI)

function Get-AgentFiles {
    <#
    .SYNOPSIS Liệt kê agent .md dưới <ProjectDir>/agents/ — trả path TƯƠNG ĐỐI project (vd 'agents/echo-a.md').
    .OUTPUTS [string[]] (rỗng nếu không có agents/).
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)
    $agentsDir = Join-Path $ProjectDir 'agents'
    if (-not (Test-Path -LiteralPath $agentsDir)) { return , @() }
    $files = Get-ChildItem -LiteralPath $agentsDir -Filter '*.md' -File | Sort-Object Name
    $rel = foreach ($f in $files) { "agents/$($f.Name)" }
    return , @($rel)
}

function Format-PipelineView {
    <#
    .SYNOPSIS Trả [string[]] dòng hiển thị pipeline (index + field chính), 1-line input rút gọn.
    #>
    param([Parameter(Position = 0)][AllowNull()]$Pipeline)
    $items = @($Pipeline)
    if ($items.Count -eq 0) { return , @('  (pipeline rỗng)') }
    $out = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $items.Count; $i++) {
        $s = $items[$i]
        $inp = ([string]$s.input) -replace '\r?\n', '\n'
        if ($inp.Length -gt 50) { $inp = $inp.Substring(0, 47) + '...' }
        $out.Add(("  [{0}] step={1}  agent={2}  output={3}  input=""{4}""" -f $i, $s.step, $s.agent, $s.output_key, $inp))
    }
    return , $out.ToArray()
}

function Read-Line {
    <#
    .SYNOPSIS Bọc Read-Host: trả $null khi EOF (cho phép phát hiện hết stdin). Prompt qua Write-Host -NoNewline.
    #>
    param([string]$Prompt)
    if ($Prompt) { Write-Host $Prompt -NoNewline }
    $line = Read-Host
    return $line
}

function Read-StepFromUser {
    <#
    .SYNOPSIS Hỏi từng field để dựng 1 step (PSCustomObject). Trả $null nếu user bỏ dở (step id rỗng).
    .PARAMETER Agents   Danh sách agent path tương đối để chọn theo số.
    .PARAMETER KnownKeys Các output_key/đặc biệt đã có (gợi ý cho input template).
    .PARAMETER Defaults  Hashtable giá trị mặc định khi SỬA step (step/agent/input/output_key).
    #>
    param(
        [Parameter(Mandatory)][string[]]$Agents,
        [Parameter(Mandatory)][string[]]$KnownKeys,
        [hashtable]$Defaults = @{}
    )

    $defStep   = if ($Defaults.ContainsKey('step'))       { $Defaults.step }       else { '' }
    $defAgent  = if ($Defaults.ContainsKey('agent'))      { $Defaults.agent }      else { '' }
    $defInput  = if ($Defaults.ContainsKey('input'))      { $Defaults.input }      else { '{{user_request}}' }
    $defOutput = if ($Defaults.ContainsKey('output_key')) { $Defaults.output_key } else { '' }

    $stepId = Read-Line ("  step id" + $(if ($defStep) { " [$defStep]" } else { '' }) + ": ")
    if ([string]::IsNullOrWhiteSpace($stepId)) { $stepId = $defStep }
    if ([string]::IsNullOrWhiteSpace($stepId)) {
        Write-Host "  (huỷ — step id trống)" -ForegroundColor Yellow
        return $null
    }

    # --- Chọn agent ---
    Write-Host "  Agent có sẵn:" -ForegroundColor DarkGray
    if ($Agents.Count -eq 0) {
        Write-Host "    (không có .md trong agents/ — gõ path tay)" -ForegroundColor DarkGray
    }
    else {
        for ($i = 0; $i -lt $Agents.Count; $i++) { Write-Host ("    {0}) {1}" -f $i, $Agents[$i]) -ForegroundColor DarkGray }
    }
    $agentSel = Read-Line ("  agent (số hoặc path)" + $(if ($defAgent) { " [$defAgent]" } else { '' }) + ": ")
    $agent = $defAgent
    if (-not [string]::IsNullOrWhiteSpace($agentSel)) {
        $n = 0
        if ([int]::TryParse($agentSel, [ref]$n) -and $n -ge 0 -and $n -lt $Agents.Count) { $agent = $Agents[$n] }
        else { $agent = $agentSel }
    }
    if ([string]::IsNullOrWhiteSpace($agent)) {
        Write-Host "  (huỷ — chưa chọn agent)" -ForegroundColor Yellow
        return $null
    }

    $outKey = Read-Line ("  output_key" + $(if ($defOutput) { " [$defOutput]" } else { '' }) + ": ")
    if ([string]::IsNullOrWhiteSpace($outKey)) { $outKey = $defOutput }
    if ([string]::IsNullOrWhiteSpace($outKey)) {
        Write-Host "  (huỷ — output_key trống)" -ForegroundColor Yellow
        return $null
    }

    Write-Host ("  Key dùng được trong input: " + ($KnownKeys -join ', ')) -ForegroundColor DarkGray
    Write-Host "  (dùng \n cho xuống dòng; vd: {{user_request}}\n{{schema}})" -ForegroundColor DarkGray
    $inputRaw = Read-Line ("  input" + " [$defInput]" + ": ")
    if ([string]::IsNullOrWhiteSpace($inputRaw)) { $inputRaw = $defInput }
    $inputVal = $inputRaw -replace '\\n', "`n"

    return [pscustomobject]@{
        step       = $stepId
        agent      = $agent
        input      = $inputVal
        output_key = $outKey
    }
}

function Save-Workflow {
    <#
    .SYNOPSIS Ghi {name, pipeline} ra <ProjectDir>/workflow.json rồi chạy Test-Workflow, in kết quả.
    .OUTPUTS [int] số lỗi validate (0 = sạch).
    #>
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Pipeline
    )
    $wfPath = Join-Path $ProjectDir 'workflow.json'
    $obj = [pscustomobject]@{
        name     = $Name
        pipeline = @($Pipeline)   # ép array kể cả 1 phần tử
    }
    Write-Json $wfPath $obj
    Write-Host "✓ Đã ghi $wfPath" -ForegroundColor Green

    $errs = Test-Workflow $ProjectDir
    if ($errs.Count -eq 0) {
        Write-Host "✓ validate: hợp lệ" -ForegroundColor Green
    }
    else {
        Write-Host "✗ validate: $($errs.Count) lỗi" -ForegroundColor Red
        foreach ($e in $errs) { Write-Host "  - $e" -ForegroundColor Red }
    }
    return $errs.Count
}

function Invoke-Edit {
    <#
    .SYNOPSIS TUI sửa workflow của 1 project. Vòng lặp menu tới khi user thoát.
    .DESCRIPTION
        Nạp workflow.json sẵn có (nếu thiếu → pipeline rỗng, name = tên thư mục). Mọi thao tác
        sửa trên bản nhớ; chỉ ghi đĩa khi chọn 's'. EOF stdin (3 dòng rỗng liên tiếp ở menu) → thoát.
    .OUTPUTS [int] exit code: 0 nếu thoát bình thường.
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)

    if (-not (Test-Path -LiteralPath $ProjectDir)) {
        Write-Host "Project dir không tồn tại: $ProjectDir" -ForegroundColor Red
        return 1
    }

    $name = Split-Path -Leaf $ProjectDir
    $pipeline = [System.Collections.Generic.List[object]]::new()

    $wfPath = Join-Path $ProjectDir 'workflow.json'
    if (Test-Path -LiteralPath $wfPath) {
        try {
            $wf = Read-Json $wfPath
            # A-18: edit chỉ hiểu pipeline v1. Project dạng GRAPH (có 'nodes') nếu mở edit thì
            # save/viz sẽ ghi đè thành {name, pipeline:[]} → xoá trắng nodes/edges. Từ chối ngay,
            # KHÔNG bao giờ ghi đè khi không nạp được pipeline.
            if ($wf.PSObject.Properties.Name -contains 'nodes') {
                Write-Host "⚠ '$name' là workflow dạng GRAPH (nodes/edges) — edit chỉ hỗ trợ pipeline v1." -ForegroundColor Yellow
                Write-Host "  Sửa workflow.json bằng tay hoặc dùng 'build'. KHÔNG mở edit để tránh ghi đè xoá trắng graph." -ForegroundColor Yellow
                return 2
            }
            if ($wf.PSObject.Properties.Name -contains 'name' -and $wf.name) { $name = $wf.name }
            if ($wf.PSObject.Properties.Name -contains 'pipeline' -and $wf.pipeline) {
                foreach ($s in @($wf.pipeline)) {
                    $pipeline.Add([pscustomobject]@{
                        step       = $s.step
                        agent      = $s.agent
                        input      = $s.input
                        output_key = $s.output_key
                    })
                }
            }
        }
        catch {
            Write-Host "⚠ workflow.json hiện tại không đọc được ($($_.Exception.Message)) — bắt đầu pipeline rỗng." -ForegroundColor Yellow
        }
    }

    $agents = Get-AgentFiles $ProjectDir
    $emptyStreak = 0

    while ($true) {
        Write-Host ''
        Write-Host "=== edit: $name  ($ProjectDir) ===" -ForegroundColor Cyan
        foreach ($l in (Format-PipelineView $pipeline)) { Write-Host $l }
        Write-Host ''
        Write-Host "Lệnh: [a]dd  [d]el  [m]ove  [e]dit  [v]iz  [s]ave+validate  [q]uit" -ForegroundColor DarkGray

        $choice = Read-Line "> "
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $emptyStreak++
            if ($emptyStreak -ge 3) {
                Write-Host "(hết input — thoát)" -ForegroundColor Yellow
                return 0
            }
            continue
        }
        $emptyStreak = 0
        $cmd = $choice.Trim().ToLower()

        switch ($cmd) {
            'a' {
                $known = @('user_request') + @($pipeline | ForEach-Object { $_.output_key })
                $step = Read-StepFromUser -Agents $agents -KnownKeys $known
                if ($step) {
                    $pipeline.Add($step)
                    Write-Host "✓ Thêm step '$($step.step)'." -ForegroundColor Green
                }
            }
            'd' {
                if ($pipeline.Count -eq 0) { Write-Host "  (không có step để xoá)" -ForegroundColor Yellow; break }
                $idxRaw = Read-Line "  xoá index: "
                $n = 0
                if ([int]::TryParse($idxRaw, [ref]$n) -and $n -ge 0 -and $n -lt $pipeline.Count) {
                    $removed = $pipeline[$n]
                    $pipeline.RemoveAt($n)
                    Write-Host "✓ Xoá step '$($removed.step)'." -ForegroundColor Green
                }
                else { Write-Host "  (index không hợp lệ)" -ForegroundColor Yellow }
            }
            'm' {
                if ($pipeline.Count -lt 2) { Write-Host "  (cần >=2 step để đổi thứ tự)" -ForegroundColor Yellow; break }
                $fromRaw = Read-Line "  từ index: "
                $toRaw   = Read-Line "  tới index: "
                $f = 0; $t = 0
                if ([int]::TryParse($fromRaw, [ref]$f) -and [int]::TryParse($toRaw, [ref]$t) -and
                    $f -ge 0 -and $f -lt $pipeline.Count -and $t -ge 0 -and $t -lt $pipeline.Count) {
                    $item = $pipeline[$f]
                    $pipeline.RemoveAt($f)
                    $pipeline.Insert($t, $item)
                    Write-Host "✓ Chuyển step '$($item.step)': $f → $t." -ForegroundColor Green
                }
                else { Write-Host "  (index không hợp lệ)" -ForegroundColor Yellow }
            }
            'e' {
                if ($pipeline.Count -eq 0) { Write-Host "  (không có step để sửa)" -ForegroundColor Yellow; break }
                $idxRaw = Read-Line "  sửa index: "
                $n = 0
                if ([int]::TryParse($idxRaw, [ref]$n) -and $n -ge 0 -and $n -lt $pipeline.Count) {
                    $cur = $pipeline[$n]
                    $known = @('user_request') + @($pipeline | Where-Object { $_ -ne $cur } | ForEach-Object { $_.output_key })
                    $defaults = @{
                        step       = $cur.step
                        agent      = $cur.agent
                        input      = ([string]$cur.input) -replace '\r?\n', '\n'
                        output_key = $cur.output_key
                    }
                    $step = Read-StepFromUser -Agents $agents -KnownKeys $known -Defaults $defaults
                    if ($step) {
                        $pipeline[$n] = $step
                        Write-Host "✓ Cập nhật step index $n." -ForegroundColor Green
                    }
                }
                else { Write-Host "  (index không hợp lệ)" -ForegroundColor Yellow }
            }
            'v' {
                # A-17: Show-Workflow đọc workflow.json từ đĩa, nhưng hợp đồng TUI là "chỉ ghi khi 's'".
                # Sao lưu nội dung file gốc → ghi tạm bản-nhớ → vẽ → KHÔI PHỤC nguyên trạng.
                $hadFile = Test-Path -LiteralPath $wfPath
                $backup = if ($hadFile) { [System.IO.File]::ReadAllText($wfPath) } else { $null }
                $obj = [pscustomobject]@{ name = $name; pipeline = @($pipeline) }
                Write-Json $wfPath $obj
                Write-Host ''
                try { Show-Workflow $ProjectDir }
                catch { Write-Host "  (chưa vẽ được: $($_.Exception.Message))" -ForegroundColor Yellow }
                finally {
                    if ($hadFile) { [System.IO.File]::WriteAllText($wfPath, $backup, [System.Text.UTF8Encoding]::new($false)) }
                    elseif (Test-Path -LiteralPath $wfPath) { Remove-Item -LiteralPath $wfPath -Force }
                }
            }
            's' {
                [void](Save-Workflow -ProjectDir $ProjectDir -Name $name -Pipeline @($pipeline))
            }
            'q' {
                Write-Host "Thoát edit." -ForegroundColor DarkGray
                return 0
            }
            default {
                Write-Host "  (lệnh lạ: '$cmd')" -ForegroundColor Yellow
            }
        }
    }
}

# --- Chạy trực tiếp (không dot-source) ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 1) {
        Write-Host "Cách dùng: ./edit.ps1 <projectDir>" -ForegroundColor Yellow
        exit 2
    }
    $code = Invoke-Edit $args[0]
    exit $code
}

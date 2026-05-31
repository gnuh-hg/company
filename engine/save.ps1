# save.ps1 — Save-Graph: write → validate → commit-or-restore (atomic, graph-format).
# Implement Session G.1.
#
# Mục đích: ghi graph candidate vào workflow.json theo pattern backup-write-validate-restore
#   (tiền lệ: edit.ps1:282-295 nút 'v'). Chỉ commit khi Test-Workflow trả 0 lỗi;
#   fail → khôi phục file cũ nguyên trạng → workflow.json LUÔN hợp lệ.
# Strip toạ độ (x/y/position/...) khỏi nodes trước khi ghi — defense engine-side (bất biến #2).
#
# Surface (qua run.ps1): run.ps1 save-graph <proj> <candidate-file>
#   In 1 dòng JSON {"ok":bool,"errors":[...]} ra stdout (server parse, KHÔNG tin exit code —
#   pwsh có thể core-dump RC=134 lúc teardown). Exit = số lỗi (0 = commit).

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib/json.ps1')
. (Join-Path $here 'lib/path.ps1')
. (Join-Path $here 'validate.ps1')

$script:CoordKeys = @('x', 'y', 'position', 'positionAbsolute', 'width', 'height',
                      'measured', 'dragging', 'selected', 'selectable')

function Strip-GraphCoordinates {
    <#
    .SYNOPSIS Strip x/y/position và các key React Flow khỏi mỗi node trong graph candidate.
    .NOTES Defense engine-side: bổ sung strip server-side (G.2) — 2 lớp bảo vệ bất biến #2.
    #>
    param($Candidate)
    $rawNodes = Get-Prop $Candidate 'nodes'
    if ($null -eq $rawNodes) { return $Candidate }

    $strippedNodes = @($rawNodes | ForEach-Object {
        $src = $_
        $srcProps = if ($src.PSObject) { @($src.PSObject.Properties.Name) } else { @() }
        $out = [ordered]@{}
        foreach ($p in $srcProps) {
            if ($p -notin $script:CoordKeys) { $out[$p] = $src.$p }
        }
        [pscustomobject]$out
    })

    $result = [ordered]@{}
    $candProps = if ($Candidate.PSObject) { @($Candidate.PSObject.Properties.Name) } else { @() }
    foreach ($p in $candProps) {
        if ($p -eq 'nodes') { $result[$p] = $strippedNodes }
        else { $result[$p] = $Candidate.$p }
    }
    return [pscustomobject]$result
}

function Save-Graph {
    <#
    .SYNOPSIS
        Ghi graph candidate vào workflow.json theo cycle backup→strip→write→validate→commit-or-restore.
    .PARAMETER ProjectDir   Thư mục project đã resolve (vd: examples/edit-demo).
    .PARAMETER Candidate    Object graph candidate (đọc từ file JSON — mang nodes/edges/entry/max_steps).
    .OUTPUTS [ordered]@{ ok=[bool]; errors=[string[]] }
        ok=$true  → đã commit workflow.json mới.
        ok=$false → file cũ được khôi phục nguyên trạng; errors[] từ Test-Workflow.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Mandatory, Position = 1)]$Candidate
    )

    $wfPath  = Join-Path $ProjectDir 'workflow.json'
    $hadFile = Test-Path -LiteralPath $wfPath
    $backup  = if ($hadFile) { [System.IO.File]::ReadAllText($wfPath) } else { $null }

    try {
        $clean = Strip-GraphCoordinates $Candidate
        Write-Json $wfPath $clean

        $result = Test-Workflow $ProjectDir
        $errs   = @(if ($null -ne $result -and $null -ne $result.errors) { $result.errors } else { @() })

        if ($errs.Count -eq 0) {
            return [ordered]@{ ok = $true; errors = @() }
        }

        # Validate fail → restore
        if ($hadFile) {
            [System.IO.File]::WriteAllText($wfPath, $backup, [System.Text.UTF8Encoding]::new($false))
        }
        elseif (Test-Path -LiteralPath $wfPath) {
            Remove-Item -LiteralPath $wfPath -Force
        }
        return [ordered]@{ ok = $false; errors = $errs }
    }
    catch {
        # Restore on unexpected error
        try {
            if ($hadFile -and $null -ne $backup) {
                [System.IO.File]::WriteAllText($wfPath, $backup, [System.Text.UTF8Encoding]::new($false))
            }
            elseif (-not $hadFile -and (Test-Path -LiteralPath $wfPath)) {
                Remove-Item -LiteralPath $wfPath -Force
            }
        }
        catch { }
        return [ordered]@{ ok = $false; errors = @("save-graph lỗi ngoài dự kiến: $($_.Exception.Message)") }
    }
}

function Write-SaveResult {
    <#
    .SYNOPSIS In 1 dòng JSON {"ok":bool,"errors":[...]} ra stdout. Server parse stdout — KHÔNG tin exit code.
    #>
    param([Parameter(Mandatory, Position = 0)]$Result)
    $j = [pscustomobject]@{
        ok     = [bool]$Result.ok
        errors = @($Result.errors)
    } | ConvertTo-Json -Depth 5 -Compress
    [Console]::Out.WriteLine($j)
}

# --- Chạy trực tiếp (không dot-source) ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 2) {
        Write-Host "Cách dùng: ./save.ps1 <projectDir> <candidate-file>" -ForegroundColor Yellow
        exit 2
    }
    $res = Save-Graph $args[0] (Read-Json $args[1])
    Write-SaveResult $res
    exit ([int]($res.errors.Count))
}

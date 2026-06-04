# tokens.ps1 — báo cáo token usage per-node + tổng run (Phase I.A.2).
#
# Đọc events.ndjson của 1 run dir → lọc type='node_usage' (I.A.1) → in bảng.
# usage real  (mock=false): input_tokens / output_tokens / cache_read / cost
# usage mock  (mock=true):  prompt_chars / output_chars  + proxy_tokens ≈ chars/4
#
# Hàm thuần:
#   Get-RunTokens  $RunDir     → @{ rows=@(); totals=@{}; is_mock=$bool }
#   Show-RunTokens $RunDir     → in bảng Write-Host (mock hoặc real layout)
# Dot-source-safe: guard ở cuối file (copy pattern từ events.ps1).

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib/json.ps1')

function Get-RunTokens {
    <#
    .SYNOPSIS
        Đọc events.ndjson của một run dir → trích node_usage → trả object báo cáo.
    .OUTPUTS
        Hashtable: rows (per-node array), totals (numeric sums, null-safe), is_mock (bool).
        rows[i]: { node, agent, mock, input_tokens, output_tokens, cache_read, cost,
                   prompt_chars, output_chars, proxy_tokens }
        totals:  { input_tokens, output_tokens, cache_read, cost,
                   prompt_chars, output_chars, proxy_tokens }
    .NOTES
        Mọi field usage guard bằng .PSObject.Properties.Name -contains (StrictMode + vắng field).
    #>
    param([Parameter(Mandatory, Position = 0)][string]$RunDir)

    $evPath = Join-Path $RunDir 'events.ndjson'
    if (-not (Test-Path -LiteralPath $evPath)) {
        throw "Không tìm thấy events.ndjson trong: $RunDir"
    }

    $rows   = [System.Collections.Generic.List[hashtable]]::new()
    $isMock = $false

    foreach ($line in @(Get-Content -LiteralPath $evPath -Encoding utf8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $ev = $line | ConvertFrom-Json
        if (-not ($ev.PSObject.Properties.Name -contains 'type')) { continue }
        if ([string]$ev.type -ne 'node_usage') { continue }

        # Extract usage nested object (guard vắng field)
        $u = if ($ev.PSObject.Properties.Name -contains 'usage') { $ev.usage } else { $null }

        $mock        = $false
        $inputTok    = $null
        $outputTok   = $null
        $cacheRead   = $null
        $cost        = $null
        $promptChars = $null
        $outputChars = $null
        $proxyTok    = $null

        if ($null -ne $u) {
            if ($u.PSObject.Properties.Name -contains 'mock')         { $mock        = [bool]$u.mock }
            if ($u.PSObject.Properties.Name -contains 'input_tokens') { $inputTok    = $u.input_tokens }
            if ($u.PSObject.Properties.Name -contains 'output_tokens'){ $outputTok   = $u.output_tokens }
            if ($u.PSObject.Properties.Name -contains 'cache_read')   { $cacheRead   = $u.cache_read }
            if ($u.PSObject.Properties.Name -contains 'cost')         { $cost        = $u.cost }
            if ($u.PSObject.Properties.Name -contains 'prompt_chars') { $promptChars = [int]$u.prompt_chars }
            if ($u.PSObject.Properties.Name -contains 'output_chars') { $outputChars = [int]$u.output_chars }
        }

        if ($mock) {
            $isMock = $true
            # Proxy: chars/4 ≈ token estimate (offline, không đốt token)
            $proxyTok = if ($null -ne $promptChars -and $null -ne $outputChars) {
                [int](($promptChars + $outputChars) / 4)
            } else { $null }
        }

        $nodeId  = if ($ev.PSObject.Properties.Name -contains 'node')  { [string]$ev.node }  else { '' }
        $agentId = if ($ev.PSObject.Properties.Name -contains 'agent') { [string]$ev.agent } else { '' }

        $rows.Add(@{
            node         = $nodeId
            agent        = $agentId
            mock         = $mock
            input_tokens  = $inputTok
            output_tokens = $outputTok
            cache_read   = $cacheRead
            cost         = $cost
            prompt_chars = $promptChars
            output_chars = $outputChars
            proxy_tokens = $proxyTok
        })
    }

    # Totals — null-safe addition
    $totInput   = $null
    $totOutput  = $null
    $totCache   = $null
    $totCost    = $null
    $totPrompt  = $null
    $totOutC    = $null
    $totProxy   = $null
    foreach ($r in $rows) {
        if ($null -ne $r.input_tokens)  { $totInput  = ($totInput  -eq $null ? 0 : $totInput)  + [long]$r.input_tokens }
        if ($null -ne $r.output_tokens) { $totOutput = ($totOutput -eq $null ? 0 : $totOutput) + [long]$r.output_tokens }
        if ($null -ne $r.cache_read)    { $totCache  = ($totCache  -eq $null ? 0 : $totCache)  + [long]$r.cache_read }
        if ($null -ne $r.cost)          { $totCost   = ($totCost   -eq $null ? 0.0 : $totCost)  + [double]$r.cost }
        if ($null -ne $r.prompt_chars)  { $totPrompt = ($totPrompt -eq $null ? 0 : $totPrompt) + [long]$r.prompt_chars }
        if ($null -ne $r.output_chars)  { $totOutC   = ($totOutC   -eq $null ? 0 : $totOutC)   + [long]$r.output_chars }
        if ($null -ne $r.proxy_tokens)  { $totProxy  = ($totProxy  -eq $null ? 0 : $totProxy)  + [long]$r.proxy_tokens }
    }

    return @{
        rows     = $rows.ToArray()
        is_mock  = $isMock
        totals   = @{
            input_tokens  = $totInput
            output_tokens = $totOutput
            cache_read    = $totCache
            cost          = $totCost
            prompt_chars  = $totPrompt
            output_chars  = $totOutC
            proxy_tokens  = $totProxy
        }
    }
}

function Show-RunTokens {
    <#
    .SYNOPSIS
        Đọc usage data của RunDir rồi in bảng per-node + TỔNG.
        Mock-mode: cột prompt_chars / output_chars / proxy_tokens (≈chars/4).
        Real-mode: cột input_tokens / output_tokens / cache_read / cost.
    .OUTPUTS Không (Write-Host side-effect).
    #>
    param([Parameter(Mandatory, Position = 0)][string]$RunDir)

    $data = Get-RunTokens $RunDir
    $rows = $data.rows
    $tot  = $data.totals

    if ($rows.Count -eq 0) {
        Write-Host "Không có node_usage events trong run này." -ForegroundColor Yellow
        return
    }

    if ($data.is_mock) {
        # Mock layout: proxy chars
        $fmt  = "{0,-18} {1,-30} {2,12} {3,12} {4,12}"
        $sep  = '-' * 88
        Write-Host ''
        Write-Host "Token proxy (mock — chars/4 ≈ tokens)" -ForegroundColor Cyan
        Write-Host $sep
        Write-Host ($fmt -f 'node', 'agent', 'prompt_chars', 'output_chars', 'proxy_tok') -ForegroundColor White
        Write-Host $sep
        foreach ($r in $rows) {
            $ag = [System.IO.Path]::GetFileNameWithoutExtension($r.agent)
            $pc = if ($null -ne $r.prompt_chars) { $r.prompt_chars } else { '-' }
            $oc = if ($null -ne $r.output_chars) { $r.output_chars } else { '-' }
            $pt = if ($null -ne $r.proxy_tokens) { $r.proxy_tokens } else { '-' }
            Write-Host ($fmt -f $r.node, $ag, $pc, $oc, $pt)
        }
        Write-Host $sep
        $tpc = if ($null -ne $tot.prompt_chars) { $tot.prompt_chars } else { '-' }
        $toc = if ($null -ne $tot.output_chars) { $tot.output_chars } else { '-' }
        $tpt = if ($null -ne $tot.proxy_tokens) { $tot.proxy_tokens } else { '-' }
        Write-Host ($fmt -f 'TỔNG', '', $tpc, $toc, $tpt) -ForegroundColor Green
        Write-Host ''
    } else {
        # Real layout: actual tokens
        $fmt  = "{0,-18} {1,-30} {2,10} {3,10} {4,10} {5,12}"
        $sep  = '-' * 96
        Write-Host ''
        Write-Host "Token usage (real — từ claude --output-format json)" -ForegroundColor Cyan
        Write-Host $sep
        Write-Host ($fmt -f 'node', 'agent', 'input_tok', 'output_tok', 'cache_read', 'cost_usd') -ForegroundColor White
        Write-Host $sep
        foreach ($r in $rows) {
            $ag = [System.IO.Path]::GetFileNameWithoutExtension($r.agent)
            $it = if ($null -ne $r.input_tokens)  { $r.input_tokens }  else { '-' }
            $ot = if ($null -ne $r.output_tokens) { $r.output_tokens } else { '-' }
            $cr = if ($null -ne $r.cache_read)    { $r.cache_read }    else { '-' }
            $cs = if ($null -ne $r.cost)          { '{0:F5}' -f [double]$r.cost } else { '-' }
            Write-Host ($fmt -f $r.node, $ag, $it, $ot, $cr, $cs)
        }
        Write-Host $sep
        $tit = if ($null -ne $tot.input_tokens)  { $tot.input_tokens }  else { '-' }
        $tot2 = if ($null -ne $tot.output_tokens) { $tot.output_tokens } else { '-' }
        $tcr = if ($null -ne $tot.cache_read)    { $tot.cache_read }    else { '-' }
        $tcs = if ($null -ne $tot.cost)          { '{0:F5}' -f [double]$tot.cost } else { '-' }
        Write-Host ($fmt -f 'TỔNG', '', $tit, $tot2, $tcr, $tcs) -ForegroundColor Green
        Write-Host ''
    }
}

# --- Chạy trực tiếp (không dot-source): in tokens của 1 run dir ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 1) {
        Write-Host "Cách dùng: ./tokens.ps1 <runDir>   (in token usage của run)" -ForegroundColor Yellow
        exit 2
    }
    Show-RunTokens $args[0]
    exit 0
}

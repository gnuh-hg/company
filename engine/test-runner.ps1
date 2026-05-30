# test-runner.ps1 — surface gom bộ test ENGINE (Phase B.3, lệnh `run.ps1 selftest`).
#
# CHỈ gom + đếm + báo (D-B3): chạy 3 test script + 7 stamp + mem-demo done-gate →
# in PASS/FAIL từng mục + bảng tổng → exit = số mục fail (đồng quy ước check/validate).
# Mock-only, 0 token. KHÔNG đụng engine executor (workflow/graph/validate).
#
# CC-c (Phase C.6): stamp ASSERT NỘI DUNG node id (prefix kỳ vọng + không còn '__P__').
# CC-c (Phase C.7): mem-demo ASSERT "run2 ≠ run1" — so output worker (work.txt) 2 run; run2 đọc
# mem_context do run1 ghi → prompt dài hơn → output khác → chứng minh memory thực sự đọc-được.

Set-StrictMode -Version Latest

$script:SelfTestEngineDir = $PSScriptRoot   # = company/engine (cố định lúc dot-source)

# CC-c: prefix stamp kỳ vọng cho mỗi p-*/ — assert NỘI DUNG (không chỉ exit 0).
# Single-pattern dir → 1 prefix; p-brain compose 5 pattern → 5 prefix hợp lệ.
# Mọi node STAMP trong workflow.json sinh ra PHẢI khớp '^<prefix>_' của 1 prefix hợp lệ
# và KHÔNG còn placeholder '__P__' (chứng minh stamp thật sự xảy ra, đồng bộ Expand-Pattern).
$script:StampPrefixExpect = @{
    'p-clarify-gate'    = @('cg')
    'p-do-verify-loop'  = @('dv')
    'p-escalate-gate'   = @('eg')
    'p-plan-decompose'  = @('pd')
    'p-re-plan-loop'    = @('rp')
    'p-research-gather' = @('rg')
    'p-brain'           = @('rg', 'cg', 'pd', 'dv', 'eg')
}

# Node HOST hợp lệ (KHÔNG từ fragment → không mang prefix stamp). p-brain nối 1 node host
# 'record' (memory/done, §D) ngoài 5 pattern. Single-pattern dir không có host node.
$script:StampHostIds = @{
    'p-brain' = @('record')
}

function Test-StampContent {
    <#
    .SYNOPSIS
        Đọc <Dir>/workflow.json (do stamp.ps1 vừa ghi) → assert mọi node id khớp '^<prefix>_'
        của $Allowed (hoặc là host node hợp lệ) + không còn '__P__'. Trả [ordered]@{ ok; detail }.
    #>
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string[]]$Allowed,
        [string[]]$Hosts = @()
    )
    # Chuẩn hoá $Hosts: positional @() có thể bind thành $null → @($null) Count=1 (StrictMode).
    $Hosts = @($Hosts | Where-Object { -not [string]::IsNullOrEmpty($_) })
    $wfPath = Join-Path $Dir 'workflow.json'
    if (-not (Test-Path -LiteralPath $wfPath)) {
        return [ordered]@{ ok = $false; detail = 'thiếu workflow.json' }
    }
    try { $wf = Get-Content -LiteralPath $wfPath -Raw | ConvertFrom-Json }
    catch { return [ordered]@{ ok = $false; detail = "JSON hỏng: $($_.Exception.Message)" } }

    $ids = @($wf.PSObject.Properties.Name -contains 'nodes' ? $wf.nodes : @() | ForEach-Object { [string]$_.id })
    if ($ids.Count -eq 0) { return [ordered]@{ ok = $false; detail = 'không có node' } }
    $stamped = 0
    foreach ($id in $ids) {
        if ($id -like '*__P__*') {
            return [ordered]@{ ok = $false; detail = "id '$id' còn placeholder __P__ (chưa stamp)" }
        }
        if ($id -in $Hosts) { continue }   # host node hợp lệ → bỏ qua check prefix
        $hit = $false
        foreach ($p in $Allowed) { if ($id -match "^$([regex]::Escape($p))_") { $hit = $true; break } }
        if (-not $hit) {
            return [ordered]@{ ok = $false; detail = "id '$id' không khớp prefix kỳ vọng ($($Allowed -join '|'))_ và không phải host node" }
        }
        $stamped++
    }
    $hostCount = @($Hosts).Count
    $hostNote = if ($hostCount -gt 0) { " +$hostCount host" } else { '' }
    return [ordered]@{ ok = $true; detail = "$stamped node stamp$hostNote, prefix=$($Allowed -join '|')" }
}

function Clear-MemDemoArtifacts {
    <# .SYNOPSIS Dọn .runs/ + memory/ của mem-demo (fixture phải start sạch + không để rác). #>
    param([Parameter(Mandatory)][string]$Dir)
    foreach ($sub in @('.runs', 'memory')) {
        $p = Join-Path $Dir $sub
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    }
}

function Invoke-SelfTest {
    <#
    .SYNOPSIS
        Chạy bộ test engine: 3 test script (subprocess) + 7 p-*/stamp.ps1 (subprocess) +
        mem-demo done-gate (2-run -Mock inline). In PASS/FAIL từng mục + bảng tổng.
    .OUTPUTS [int] số mục FAIL (0 = tất cả pass).
    #>
    param([string[]]$Pos)   # [all] hiện không phân nhóm — luôn chạy hết (B surface).

    $examples = Join-Path $script:SelfTestEngineDir '../examples'
    $pwshExe  = (Get-Process -Id $PID).Path
    if ([string]::IsNullOrWhiteSpace($pwshExe)) { $pwshExe = 'pwsh' }

    $items = [System.Collections.Generic.List[object]]::new()

    Write-Host "selftest — bộ test engine (script + stamp + mem-demo). Mock-only, 0 token." -ForegroundColor Cyan

    # 1) 3 test script (mỗi script tự `exit $fails`) ----------------------------
    Write-Host ''
    Write-Host '── Test scripts ──'
    foreach ($s in @('hq-tests', 'hq-graph-tests', 'e2e-harness-tests')) {
        $path = Join-Path $examples "$s.ps1"
        & $pwshExe -NoProfile -File $path *> $null
        $code = $LASTEXITCODE
        $ok   = ($code -eq 0)
        $items.Add([pscustomobject]@{ Name = "script/$s"; Pass = $ok; Detail = "exit=$code" })
        Write-SelfTestLine "script/$s" $ok "exit=$code"
    }

    # 2) 7 stamp wrapper (mỗi stamp ghi workflow.json deterministic, exit 0) ------
    Write-Host ''
    Write-Host '── Pattern stamps ──'
    $stampDirs = @(Get-ChildItem -LiteralPath $examples -Directory -Filter 'p-*' | Sort-Object Name)
    foreach ($d in $stampDirs) {
        $stamp = Join-Path $d.FullName 'stamp.ps1'
        if (-not (Test-Path -LiteralPath $stamp)) { continue }
        & $pwshExe -NoProfile -File $stamp *> $null
        $code = $LASTEXITCODE
        $ok   = ($code -eq 0)
        $detail = "exit=$code"
        # CC-c: stamp exit 0 → assert NỘI DUNG node id (prefix kỳ vọng + không còn __P__).
        if ($ok -and $script:StampPrefixExpect.ContainsKey($d.Name)) {
            $hosts = if ($script:StampHostIds.ContainsKey($d.Name)) { $script:StampHostIds[$d.Name] } else { @() }
            $cc = Test-StampContent $d.FullName $script:StampPrefixExpect[$d.Name] $hosts
            $ok = $cc.ok
            $detail = if ($cc.ok) { "exit=$code; $($cc.detail)" } else { "exit=$code; STAMP-ASSERT: $($cc.detail)" }
        }
        $items.Add([pscustomobject]@{ Name = "stamp/$($d.Name)"; Pass = $ok; Detail = $detail })
        Write-SelfTestLine "stamp/$($d.Name)" $ok $detail
    }

    # 3) mem-demo done-gate (2-run -Mock, inline) -------------------------------
    Write-Host ''
    Write-Host '── mem-demo (done-gate 2-run) ──'
    $memDir = Join-Path $examples 'mem-demo'
    $memOk = $false; $memDetail = ''
    try {
        Clear-MemDemoArtifacts $memDir
        $r1 = Invoke-Workflow $memDir 'demo selftest' -Mock 6> $null
        $s1 = (Get-RunState $r1).status
        # work.txt = output worker (output_key='work'); run1 đọc mem_context RỖNG.
        $w1 = Get-Content -LiteralPath (Join-Path $r1 'work.txt') -Raw -Encoding utf8
        $r2 = Invoke-Workflow $memDir 'demo selftest' -Mock 6> $null
        $s2 = (Get-RunState $r2).status
        # run2 đọc mem_context = bài học run1 ghi → prompt worker DÀI hơn → output KHÁC run1.
        $w2 = Get-Content -LiteralPath (Join-Path $r2 'work.txt') -Raw -Encoding utf8
        # CC-c (C.7): không chỉ done — assert run2 ≠ run1 (chứng minh memory thực sự đọc-được).
        $differs   = ($w1 -ne $w2)
        $memOk     = ($s1 -eq 'done' -and $s2 -eq 'done' -and $differs)
        $memDetail = "run1=$s1 run2=$s2 run2≠run1=$differs"
    }
    catch {
        $memOk = $false; $memDetail = $_.Exception.Message
    }
    finally {
        Clear-MemDemoArtifacts $memDir
    }
    $items.Add([pscustomobject]@{ Name = 'mem-demo/done-gate'; Pass = $memOk; Detail = $memDetail })
    Write-SelfTestLine 'mem-demo/done-gate' $memOk $memDetail

    # Bảng tổng -----------------------------------------------------------------
    $fails = @($items | Where-Object { -not $_.Pass }).Count
    $total = $items.Count
    Write-Host ''
    Write-Host '── Tổng kết selftest ──'
    foreach ($it in $items) { Write-SelfTestLine $it.Name $it.Pass $it.Detail }
    Write-Host ''
    if ($fails -eq 0) {
        Write-Host "✓ selftest: $total/$total PASS" -ForegroundColor Green
    }
    else {
        Write-Host "✗ selftest: $fails/$total FAIL" -ForegroundColor Red
    }
    Write-Host '  (C.6: stamp assert nội dung node id; C.7: mem-demo assert "run2 ≠ run1")' -ForegroundColor DarkGray
    return $fails
}

function Write-SelfTestLine {
    param([string]$Name, [bool]$Pass, [string]$Detail)
    $tag   = if ($Pass) { 'PASS' } else { 'FAIL' }
    $color = if ($Pass) { 'Green' } else { 'Red' }
    Write-Host ("  [{0}] {1,-26} {2}" -f $tag, $Name, $Detail) -ForegroundColor $color
}

# --- Chạy trực tiếp (không dot-source) — quy ước #5 ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    # Khi gọi thẳng `pwsh test-runner.ps1`, cần engine context → dot-source run-stack.
    . (Join-Path $PSScriptRoot 'workflow.ps1')
    . (Join-Path $PSScriptRoot 'status.ps1')
    exit (Invoke-SelfTest $args)
}

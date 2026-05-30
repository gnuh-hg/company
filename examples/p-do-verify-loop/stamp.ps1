# stamp.ps1 — build-time: fragment do-verify-loop → workflow.json (demo wrapper).
# Chạy: pwsh examples/p-do-verify-loop/stamp.ps1   (sinh workflow.json cạnh script này)
#
# Minh hoạ pipeline chốt ở Phase 0-A: fragment → Expand-Pattern (stamp id/edge) →
# host bind agent + cấp name/entry/max_steps → workflow.json explicit chạy được.
# KHÔNG phải runtime; chỉ tái tạo workflow.json từ fragment khi cần.

Set-StrictMode -Version Latest

$projDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$engine  = Join-Path $projDir '../../engine'
. (Join-Path $engine 'pattern.ps1')   # kéo theo lib/json.ps1 (lưu ý: ghi đè $here)

$prefix   = 'dv'
$fragment = Read-Json (Join-Path $projDir '../../patterns/do-verify-loop.json')
$expanded = Expand-Pattern $fragment $prefix

# Host bind agent mỗi node theo convention agents/<stamped-id>.md
# (router agent basename = node id 'dv_verdict' → khớp ENGINE_MOCK_ROUTER).
$nodes = foreach ($n in $expanded.nodes) {
    $h = [ordered]@{ id = $n['id'] }
    $h['agent'] = "agents/$($n['id']).md"
    if ($n.Contains('type'))       { $h['type'] = $n['type'] }
    if ($n.Contains('input'))      { $h['input'] = $n['input'] }
    if ($n.Contains('output_key')) { $h['output_key'] = $n['output_key'] }
    [pscustomobject]$h
}

$workflow = [ordered]@{
    name      = 'p-do-verify-loop'
    entry     = "${prefix}_builder"
    max_steps = 10
    nodes     = @($nodes)
    edges     = @($expanded.edges)
}

Write-Json (Join-Path $projDir 'workflow.json') $workflow
Write-Host "✓ stamped p-do-verify-loop: $($workflow.nodes.Count) node / $(@($workflow.edges).Count) edge" -ForegroundColor Green

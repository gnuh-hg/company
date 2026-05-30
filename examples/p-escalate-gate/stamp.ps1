# stamp.ps1 — build-time: fragment escalate-gate → workflow.json (demo wrapper).
# Chạy: pwsh examples/p-escalate-gate/stamp.ps1   (sinh workflow.json cạnh script này)
#
# Pipeline Phase 0: fragment → Expand-Pattern (stamp id/edge) →
# host bind agent + cấp name/entry/max_steps → workflow.json explicit chạy được.
# KHÔNG phải runtime; chỉ tái tạo workflow.json từ fragment khi cần.

Set-StrictMode -Version Latest

$projDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$engine  = Join-Path $projDir '../../engine'
. (Join-Path $engine 'pattern.ps1')   # kéo theo lib/json.ps1 (lưu ý: ghi đè $here)

$prefix   = 'eg'
$fragment = Read-Json (Join-Path $projDir '../../patterns/escalate-gate.json')
$expanded = Expand-Pattern $fragment $prefix

# Host bind agent mỗi node theo convention agents/<stamped-id>.md
# (router agent basename = node id 'eg_gate' → khớp ENGINE_MOCK_ROUTER).
$nodes = foreach ($n in $expanded.nodes) {
    $h = [ordered]@{ id = $n['id'] }
    $h['agent'] = "agents/$($n['id']).md"
    if ($n.Contains('type'))       { $h['type'] = $n['type'] }
    if ($n.Contains('input'))      { $h['input'] = $n['input'] }
    if ($n.Contains('output_key')) { $h['output_key'] = $n['output_key'] }
    [pscustomobject]$h
}

$workflow = [ordered]@{
    name      = 'p-escalate-gate'
    entry     = "${prefix}_gate"
    max_steps = 10
    nodes     = @($nodes)
    edges     = @($expanded.edges)
}

Write-Json (Join-Path $projDir 'workflow.json') $workflow
Write-Host "✓ stamped p-escalate-gate: $($workflow.nodes.Count) node / $(@($workflow.edges).Count) edge" -ForegroundColor Green

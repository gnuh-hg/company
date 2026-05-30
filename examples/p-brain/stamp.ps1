# stamp.ps1 — build-time: NỐI 6 pattern thành vòng đời đầu-não §D (brain-model) → workflow.json.
# Chạy: pwsh examples/p-brain/stamp.ps1   (sinh workflow.json cạnh script này)
#
# Phase 0-C integration demo. Khác p-<name> (1 fragment): p-brain stamp NHIỀU fragment
# bằng Expand-Pattern (prefix riêng) rồi NỐI theo sơ đồ §D — chứng minh 6 pattern compose.
#
# QUYẾT ĐỊNH WIRING (ghi ở CHECKPOINT Notes C.1):
#   §D vẽ MỘT verdict router gộp do-verify (pass/fail) + re-plan (fail/clarify→planner)
#   + trigger escalate. Vì vậy re-plan-loop KHÔNG stamp thành subgraph riêng (sẽ tạo
#   planner/verdict trùng → UNREACHABLE, fail reachability-validate). Topology re-plan
#   (verdict --fail/clarify--> planner) hiện thực TRÊN dv_verdict; bản thân re-plan-loop
#   đã được validate độc lập ở p-re-plan-loop (B.2). → p-brain stamp 5 fragment owner:
#     rg = research-gather (researcher + gate)   cg = clarify-gate (gate)
#     pd = plan-decompose (planner + classify)   dv = do-verify-loop (builder/tester/verdict)
#     eg = escalate-gate (gate + user)
#   + 1 node host 'record' (memory/done) — điểm hội tụ pass & resolved (§D record:memory).

Set-StrictMode -Version Latest

$projDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$engine  = Join-Path $projDir '../../engine'
. (Join-Path $engine 'pattern.ps1')   # kéo theo lib/json.ps1 (lưu ý: ghi đè $here)
$patDir  = Join-Path $projDir '../../patterns'

# Stamp từng fragment với prefix riêng → gom mọi node stamped vào 1 lookup id→node.
$byId = @{}
foreach ($pair in @(
    @{ file = 'research-gather'; prefix = 'rg' },
    @{ file = 'clarify-gate';    prefix = 'cg' },
    @{ file = 'plan-decompose';  prefix = 'pd' },
    @{ file = 'do-verify-loop';  prefix = 'dv' },
    @{ file = 'escalate-gate';   prefix = 'eg' }
)) {
    $frag = Read-Json (Join-Path $patDir "$($pair.file).json")
    $exp  = Expand-Pattern $frag $pair.prefix
    foreach ($n in $exp.nodes) { $byId[$n['id']] = $n }
}

# Chọn node theo vai §D (bỏ exit-stub bị bridge thay: rg_out/rg_clarify, cg_out/cg_escalate,
# pd_long/pd_short, dv_done, eg_out). 'record' là node host mới (không từ fragment).
$select = @(
    'rg_researcher', 'rg_gate',          # research
    'cg_gate',                            # clarify-gate (biên)
    'pd_planner', 'pd_classify',          # plan decompose
    'dv_builder', 'dv_tester', 'dv_verdict',  # orchestrate + verdict (gộp re-plan)
    'eg_gate', 'eg_user'                  # escalate-gate
)

$nodes = foreach ($id in $select) {
    $src = $byId[$id]
    $h = [ordered]@{ id = $id; agent = "agents/$id.md" }
    if ($src.Contains('type'))       { $h['type'] = $src['type'] }
    if ($src.Contains('input'))      { $h['input'] = $src['input'] }
    if ($src.Contains('output_key')) { $h['output_key'] = $src['output_key'] }
    [pscustomobject]$h
}
# Node host 'record' (memory/done) — không từ fragment.
$nodes += [pscustomobject]([ordered]@{
    id = 'record'; agent = 'agents/record.md'; type = 'work'
    input = "{{user_request}}"; output_key = 'record_result'
})

# Cạnh NỐI theo §D (brain-model §D + PLAN C.1 line 130). Mỗi router có ≥2 cạnh + fallback.
$edges = @(
    [ordered]@{ from = 'rg_researcher'; to = 'rg_gate' },
    [ordered]@{ from = 'rg_gate'; to = 'pd_planner'; when = 'enough' },
    [ordered]@{ from = 'rg_gate'; to = 'cg_gate';    when = 'need_clarify' },
    [ordered]@{ from = 'cg_gate'; to = 'pd_planner'; when = 'ok' },
    [ordered]@{ from = 'cg_gate'; to = 'eg_gate';    when = 'missing_input' },
    [ordered]@{ from = 'pd_planner';  to = 'pd_classify' },
    [ordered]@{ from = 'pd_classify'; to = 'dv_builder'; when = 'long' },
    [ordered]@{ from = 'pd_classify'; to = 'dv_builder'; when = 'short' },
    [ordered]@{ from = 'dv_builder'; to = 'dv_tester' },
    [ordered]@{ from = 'dv_tester';  to = 'dv_verdict' },
    [ordered]@{ from = 'dv_verdict'; to = 'record';     when = 'pass' },
    [ordered]@{ from = 'dv_verdict'; to = 'pd_planner'; when = 'fail' },     # re-plan
    [ordered]@{ from = 'dv_verdict'; to = 'pd_planner'; when = 'clarify' },  # re-plan
    [ordered]@{ from = 'dv_verdict'; to = 'eg_gate';    when = 'escalate' },
    [ordered]@{ from = 'eg_gate'; to = 'record';  when = 'resolved' },
    [ordered]@{ from = 'eg_gate'; to = 'eg_user'; when = 'escalate' }
)

$workflow = [ordered]@{
    name      = 'p-brain'
    entry     = 'rg_researcher'
    max_steps = 30
    nodes     = @($nodes)
    edges     = @($edges | ForEach-Object { [pscustomobject]$_ })
}

Write-Json (Join-Path $projDir 'workflow.json') $workflow
Write-Host "✓ stamped p-brain: $($workflow.nodes.Count) node / $(@($workflow.edges).Count) edge" -ForegroundColor Green

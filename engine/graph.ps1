# graph.ps1 — loader: workflow.json → graph chuẩn hoá {nodes, edges, entry, max_steps}.
# Implement Session 1.1.
#
# Scope 1.1: hàm thuần Get-Graph $ProjectDir → object chuẩn hoá dùng chung cho executor v2.
#   - Graph form: đọc thẳng entry/max_steps/nodes/edges (QĐ-1).
#   - Pipeline cũ (flat): mỗi step → 1 node, chuỗi cạnh tuyến tính, entry = step đầu,
#     max_steps = số step → một executor duy nhất xử lý cả hai (tương thích ngược).
#   - Build adjacency (id → cạnh ra) + nodeById để executor/router tra cứu O(1).
#   - Throw khi: thiếu name/entry/nodes, id node trùng, entry không khớp node, cạnh dangling.
# Dot-source-safe (guard InvocationName/Line) + StrictMode.

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib/json.ps1')

# Get-Prop: accessor StrictMode-safe gom vào lib/json.ps1 (A-06) — đã dot-source ở đầu file.

function ConvertTo-NormNode {
    <#
    .SYNOPSIS Chuẩn hoá 1 node thô (graph hoặc step pipeline) → ordered hashtable nhất quán.
    .DESCRIPTION
        Trường tuỳ chọn (type) vắng → 'work'. Trường nội dung (agent/input/output_key) vắng
        giữ $null — kiểm tra đầy đủ là việc của validate.ps1 (Session 3.1), không phải loader.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]$Raw,
        [Parameter(Mandatory, Position = 1)][string]$Id
    )
    $type = Get-Prop $Raw 'type'
    if ([string]::IsNullOrWhiteSpace($type)) { $type = 'work' }
    # prompt: text cho người duyệt ở node type='approval' (Phase D); $null nếu vắng.
    # Chấp 'prompt' hoặc 'message' (alias) — gate không gọi model nên dùng field mô tả này.
    $prompt = Get-Prop $Raw 'prompt'
    if ($null -eq $prompt) { $prompt = Get-Prop $Raw 'message' }
    return [ordered]@{
        id           = $Id
        agent        = Get-Prop $Raw 'agent'
        type         = $type
        input        = Get-Prop $Raw 'input'
        output_key   = Get-Prop $Raw 'output_key'
        memory_write = Get-Prop $Raw 'memory_write'   # Phase M-B: loại ghi (node record), $null nếu vắng
        prompt       = $prompt                          # Phase D: text gate approval, $null nếu vắng
    }
}

function Get-Graph {
    <#
    .SYNOPSIS
        Đọc projects/<name>/workflow.json → graph chuẩn hoá dùng chung cho executor v2.
    .DESCRIPTION
        Nhận diện 2 dạng schema:
          - có 'pipeline' → flat (cũ): sinh node mỗi step + cạnh tuyến tính + entry/max_steps suy ra.
          - có 'nodes'    → graph (QĐ-1): đọc thẳng entry/max_steps/nodes/edges.
        Trả về ordered hashtable:
          @{ name; entry; max_steps; nodes[]; edges[]; nodeById{}; adj{} }
        nodes/edges đã chuẩn hoá (node: id/agent/type/input/output_key; edge: from/to/when).
        adj: id node → List cạnh ra (giữ thứ tự khai báo — quan trọng cho router edge-select).
    .PARAMETER ProjectDir
        Thư mục project, vd: examples/hello.
    .OUTPUTS
        [ordered] graph chuẩn hoá. Throw khi schema thiếu/hỏng cấu trúc.
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)

    if (-not (Test-Path -LiteralPath $ProjectDir)) {
        throw "Get-Graph: project dir không tồn tại: $ProjectDir"
    }
    $wf = Read-Json (Join-Path $ProjectDir 'workflow.json')

    $name = Get-Prop $wf 'name'
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Get-Graph: workflow.json thiếu field bắt buộc 'name'"
    }

    $hasPipeline = $wf.PSObject.Properties.Name -contains 'pipeline'
    $hasNodes    = $wf.PSObject.Properties.Name -contains 'nodes'

    $nodes = [System.Collections.Generic.List[object]]::new()
    $edges = [System.Collections.Generic.List[object]]::new()

    if ($hasPipeline) {
        # --- Flat pipeline → graph (sugar; QĐ-1) ---
        $pipe = @($wf.pipeline)
        if ($pipe.Count -eq 0) {
            throw "Get-Graph: pipeline rỗng — cần ít nhất 1 step"
        }
        foreach ($s in $pipe) {
            $id = Get-Prop $s 'step'
            if ([string]::IsNullOrWhiteSpace($id)) {
                throw "Get-Graph: step trong pipeline thiếu field 'step'"
            }
            $nodes.Add((ConvertTo-NormNode $s $id))
        }
        # Cạnh tuyến tính step[i] → step[i+1].
        for ($i = 0; $i -lt ($pipe.Count - 1); $i++) {
            $edges.Add([ordered]@{ from = (Get-Prop $pipe[$i] 'step'); to = (Get-Prop $pipe[$i + 1] 'step'); when = $null })
        }
        $entry    = Get-Prop $pipe[0] 'step'
        $maxSteps = $pipe.Count
    }
    elseif ($hasNodes) {
        # --- Graph form (QĐ-1) ---
        $entry = Get-Prop $wf 'entry'
        if ([string]::IsNullOrWhiteSpace($entry)) {
            throw "Get-Graph: graph thiếu field bắt buộc 'entry'"
        }
        $rawMax = Get-Prop $wf 'max_steps'
        if ($null -eq $rawMax) {
            throw "Get-Graph: graph thiếu field bắt buộc 'max_steps' (cầu dao chống loop vô hạn)"
        }
        if (-not (($rawMax -is [int]) -or ($rawMax -is [long]) -or ($rawMax -is [double] -and [math]::Floor($rawMax) -eq $rawMax))) {
            throw "Get-Graph: max_steps phải là số nguyên (hiện: '$rawMax')"
        }
        $maxSteps = [int]$rawMax

        $rawNodes = @($wf.nodes)
        if ($rawNodes.Count -eq 0) {
            throw "Get-Graph: nodes rỗng — cần ít nhất 1 node"
        }
        foreach ($n in $rawNodes) {
            $id = Get-Prop $n 'id'
            if ([string]::IsNullOrWhiteSpace($id)) {
                throw "Get-Graph: node thiếu field bắt buộc 'id'"
            }
            $nodes.Add((ConvertTo-NormNode $n $id))
        }
        foreach ($e in @(Get-Prop $wf 'edges' | Where-Object { $null -ne $_ })) {
            $edges.Add([ordered]@{ from = (Get-Prop $e 'from'); to = (Get-Prop $e 'to'); when = (Get-Prop $e 'when') })
        }
    }
    else {
        throw "Get-Graph: workflow.json phải có 'pipeline' (flat) hoặc 'nodes' (graph)"
    }

    # --- nodeById + kiểm tra id unique ---
    $nodeById = @{}
    foreach ($n in $nodes) {
        if ($nodeById.ContainsKey($n.id)) {
            throw "Get-Graph: id node trùng: '$($n.id)'"
        }
        $nodeById[$n.id] = $n
    }
    if (-not $nodeById.ContainsKey($entry)) {
        throw "Get-Graph: entry '$entry' không khớp node nào"
    }

    # --- Adjacency: id → cạnh ra (giữ thứ tự); kiểm tra cạnh không dangling ---
    $adj = @{}
    foreach ($id in $nodeById.Keys) {
        $adj[$id] = [System.Collections.Generic.List[object]]::new()
    }
    foreach ($e in $edges) {
        if (-not $nodeById.ContainsKey($e.from)) {
            throw "Get-Graph: cạnh có 'from' không tồn tại: '$($e.from)'"
        }
        if (-not $nodeById.ContainsKey($e.to)) {
            throw "Get-Graph: cạnh có 'to' không tồn tại: '$($e.to)' (from '$($e.from)')"
        }
        $adj[$e.from].Add($e)
    }

    return [ordered]@{
        name      = $name
        entry     = $entry
        max_steps = $maxSteps
        nodes     = @($nodes)
        edges     = @($edges)
        nodeById  = $nodeById
        adj       = $adj
    }
}

# --- Chạy trực tiếp (không dot-source): in tóm tắt graph ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 1) {
        Write-Host "Cách dùng: ./graph.ps1 <projectDir>" -ForegroundColor Yellow
        exit 2
    }
    $g = Get-Graph $args[0]
    Write-Host "✓ graph '$($g.name)': $($g.nodes.Count) node / $($g.edges.Count) edge · entry=$($g.entry) · max_steps=$($g.max_steps)" -ForegroundColor Green
    foreach ($n in $g.nodes) {
        $outs = @($g.adj[$n.id]) | ForEach-Object { if ($_.when) { "$($_.to)[$($_.when)]" } else { $_.to } }
        $tag  = if ($n.type -eq 'approval') { ' (approval)' } elseif (@($g.adj[$n.id]).Count -ge 2) { ' (branch)' } else { '' }
        Write-Host ("  {0,-10}{1} → {2}" -f $n.id, $tag, ($outs -join ', '))
    }
}

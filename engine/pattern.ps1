# pattern.ps1 — author/build-time helper: stamp pattern fragment → graph nodes/edges.
# Implement Phase 0 Session A.1.
#
# Engine runtime KHÔNG load fragment (quy ước #2 + C-1): patterns/*.json là author-time.
# Expand-Pattern đóng dấu fragment thành nodes/edges explicit để Builder ghép vào workflow.json
# (runtime luôn "thấy gì chạy nấy"). Đây là helper build-time, KHÔNG phải module runtime.
#
# Quy tắc stamp (chốt A.1, áp cho cả 6 pattern):
#   - Đổi placeholder '__P__<x>' → '<prefix>_<x>' CHỈ ở: node.id, edge.from, edge.to.
#   - KHÔNG đụng field khác (agent / input / output_key / type / when) — giữ nguyên văn.
#   - Số node/edge giữ nguyên; mọi field khác clone verbatim.
# Dot-source-safe (guard InvocationName/Line) + StrictMode (guard $null/.Count).

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib/json.ps1')

function Copy-ObjectWithOverrides {
    <#
    .SYNOPSIS Clone mọi property của 1 object (PSCustomObject) → ordered hashtable,
        ghi đè các key trong $Override. Giữ thứ tự field gốc.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]$Obj,
        [Parameter(Position = 1)][hashtable]$Override = @{}
    )
    $h = [ordered]@{}
    if ($null -ne $Obj) {
        foreach ($p in $Obj.PSObject.Properties) { $h[$p.Name] = $p.Value }
    }
    foreach ($k in $Override.Keys) { $h[$k] = $Override[$k] }
    return $h
}

function Expand-Pattern {
    <#
    .SYNOPSIS
        Stamp 1 fragment pattern bằng prefix → trả { nodes[]; edges[] } explicit (author-time).
    .DESCRIPTION
        Đổi '__P__<x>' → '<Prefix>_<x>' CHỈ ở node.id + edge.from/to. Mọi field khác
        (agent/input/output_key/type/when) clone nguyên văn. Số node/edge bất biến.
        Engine runtime không gọi hàm này — Builder dùng lúc soạn workflow.json.
    .PARAMETER Fragment
        Object fragment đã parse (shape { meta, nodes, edges }). meta bỏ qua khi stamp.
    .PARAMETER Prefix
        Tiền tố instance (vd 'dv'). '__P__verdict' → 'dv_verdict'.
    .OUTPUTS
        [ordered] @{ nodes = @(...); edges = @(...) }
    #>
    param(
        [Parameter(Mandatory, Position = 0)]$Fragment,
        [Parameter(Mandatory, Position = 1)][string]$Prefix
    )
    if ($null -eq $Fragment) {
        throw "Expand-Pattern: fragment là null"
    }
    if ([string]::IsNullOrWhiteSpace($Prefix)) {
        throw "Expand-Pattern: prefix rỗng"
    }

    $stamp = "${Prefix}_"
    $rewrite = {
        param($s)
        if ([string]::IsNullOrEmpty($s)) { return $s }
        return $s.Replace('__P__', $stamp)
    }

    $rawNodes = @($Fragment.PSObject.Properties.Name -contains 'nodes' ? $Fragment.nodes : @())
    if ($rawNodes.Count -eq 0) {
        throw "Expand-Pattern: fragment thiếu 'nodes' (hoặc rỗng)"
    }
    $rawEdges = @($Fragment.PSObject.Properties.Name -contains 'edges' ? $Fragment.edges : @())

    $nodes = [System.Collections.Generic.List[object]]::new()
    foreach ($n in $rawNodes) {
        $newId = & $rewrite $n.id
        $nodes.Add((Copy-ObjectWithOverrides $n @{ id = $newId }))
    }

    $edges = [System.Collections.Generic.List[object]]::new()
    foreach ($e in $rawEdges) {
        $from = & $rewrite $e.from
        $to   = & $rewrite $e.to
        $edges.Add((Copy-ObjectWithOverrides $e @{ from = $from; to = $to }))
    }

    return [ordered]@{
        nodes = @($nodes)
        edges = @($edges)
    }
}

# --- Chạy trực tiếp (không dot-source): stamp fragment, in đếm + JSON nodes/edges ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 2) {
        Write-Host "Cách dùng: ./pattern.ps1 <fragment.json> <prefix>" -ForegroundColor Yellow
        exit 2
    }
    $frag = Read-Json $args[0]
    $out  = Expand-Pattern $frag $args[1]
    Write-Host "✓ stamp '$($args[0])' prefix='$($args[1])': $($out.nodes.Count) node / $($out.edges.Count) edge" -ForegroundColor Green
    ([ordered]@{ nodes = $out.nodes; edges = $out.edges } | ConvertTo-Json -Depth 20)
}

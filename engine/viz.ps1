# viz.ps1 — graph → ASCII + Mermaid export (control flow v2)
# Implement Session 3.2.
#
# Scope 3.2: vẽ theo CẠNH ĐIỀU KHIỂN thật (from/to/when) qua Get-Graph — không còn suy
# cạnh từ {{key}} dữ liệu (mô hình pipeline cũ). Hỗ trợ router + back-edge (loop):
#   - Mermaid `graph TD`: router = diamond `id{...}`, node thường = `id[...]`,
#     cạnh mang nhãn `from -->|when| to` (when vắng → `-->`). Back-edge vẽ tự nhiên.
#   - ASCII: liệt kê node (kèm type + output_key) + danh sách cạnh có nhãn — bền với cycle
#     (không layering vì control-cycle hợp lệ, layering longest-path sẽ không hội tụ).
# Cùng nguồn Get-Graph với executor/validate nên đồ thị khớp thực thi.
# Pipeline cũ: Get-Graph quy về node tuyến tính (type=work, edge không 'when') → vẽ thành chuỗi.

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'graph.ps1')   # dot-source: Get-Graph (guard chạy-trực-tiếp không kích hoạt khi dot-source)

function Get-NodeLabel {
    <#
    .SYNOPSIS Nhãn hiển thị 1 node: id, kèm '→output_key' nếu khác id.
    #>
    param([Parameter(Mandatory, Position = 0)]$Node)
    $key = $Node.output_key
    if (-not [string]::IsNullOrWhiteSpace($key) -and $key -ne $Node.id) {
        return "$($Node.id) →$key"
    }
    return [string]$Node.id
}

function Get-GraphMermaid {
    <#
    .SYNOPSIS
        Render graph chuẩn hoá thành mảng dòng Mermaid `graph TD`.
    .DESCRIPTION
        Router (type='router') → diamond `id{"label"}`; node thường → `id["label"]`.
        Cạnh: `from -->|when| to` (when không rỗng) hoặc `from --> to`. Label escape `"`.
        Node id alphanumeric/_ → an toàn làm Mermaid id. Cùng nguồn Get-Graph nên khớp ASCII.
    .OUTPUTS
        [string[]] các dòng `.mmd`.
    #>
    param([Parameter(Mandatory, Position = 0)]$Graph)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('graph TD')

    foreach ($n in $Graph.nodes) {
        $label = (Get-NodeLabel $n).Replace('"', '&quot;')
        if ($n.type -eq 'router') {
            $lines.Add(('    {0}{{"{1}"}}' -f $n.id, $label))         # diamond
        }
        elseif ($n.type -eq 'approval') {
            $lines.Add(('    {0}{{{{"⏸ {1}"}}}}' -f $n.id, $label))   # hexagon (gate người-duyệt)
        }
        else {
            $lines.Add(('    {0}["{1}"]' -f $n.id, $label))
        }
    }
    foreach ($e in $Graph.edges) {
        if (-not [string]::IsNullOrWhiteSpace($e.when)) {
            $w = ([string]$e.when).Replace('"', '&quot;')
            $lines.Add(('    {0} -->|{1}| {2}' -f $e.from, $w, $e.to))
        }
        else {
            $lines.Add(('    {0} --> {1}' -f $e.from, $e.to))
        }
    }

    return , $lines.ToArray()
}

function Format-GraphAscii {
    <#
    .SYNOPSIS
        Render graph chuẩn hoá thành mảng dòng ASCII: header + node list + edge list (có nhãn).
    .DESCRIPTION
        Không layering (control-cycle hợp lệ → longest-path không hội tụ). Liệt kê node theo
        thứ tự khai báo (đánh dấu entry + router), rồi mọi cạnh kèm nhãn 'when'.
    .OUTPUTS
        [string[]] các dòng để in.
    #>
    param([Parameter(Mandatory, Position = 0)]$Graph)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("Workflow: $($Graph.name)  —  $($Graph.nodes.Count) node, $($Graph.edges.Count) cạnh · entry=$($Graph.entry) · max_steps=$($Graph.max_steps)")
    $lines.Add('')
    $lines.Add('Nodes:')
    foreach ($n in $Graph.nodes) {
        $tags = @()
        if ($n.id -eq $Graph.entry)   { $tags += 'entry' }
        if ($n.type -eq 'router')     { $tags += 'router' }
        if ($n.type -eq 'approval')   { $tags += 'approval' }
        $tag = if ($tags.Count -gt 0) { ' (' + ($tags -join ', ') + ')' } else { '' }
        $key = if (-not [string]::IsNullOrWhiteSpace($n.output_key)) { " →$($n.output_key)" } else { '' }
        $mark = if ($n.type -eq 'approval') { '⏸ ' } else { '' }
        $lines.Add(('  {0}{1,-10}{2}{3}' -f $mark, $n.id, $tag, $key))
    }
    if ($Graph.edges.Count -gt 0) {
        $lines.Add('')
        $lines.Add('Cạnh:')
        foreach ($e in $Graph.edges) {
            $w = if (-not [string]::IsNullOrWhiteSpace($e.when)) { " [$($e.when)]" } else { '' }
            $lines.Add(('  {0} →{1} {2}' -f $e.from, $w, $e.to))
        }
    }

    return , $lines.ToArray()
}

function Export-WorkflowMermaid {
    <#
    .SYNOPSIS
        Ghi Mermaid của projects/<name>/workflow.json ra file `.mmd`.
    .PARAMETER ProjectDir
        Thư mục project.
    .PARAMETER OutPath
        Đường dẫn file đích; mặc định `<ProjectDir>/workflow.mmd`.
    .OUTPUTS
        [string] đường dẫn file đã ghi.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Position = 1)][string]$OutPath
    )
    if (-not $OutPath) { $OutPath = Join-Path $ProjectDir 'workflow.mmd' }
    $graph = Get-Graph $ProjectDir
    $text  = (Get-GraphMermaid $graph) -join "`n"
    $dir   = Split-Path -Parent $OutPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $OutPath -Value $text -Encoding UTF8
    return $OutPath
}

function Show-Workflow {
    <#
    .SYNOPSIS In đồ thị ASCII của projects/<name>/workflow.json ra terminal.
    #>
    param([Parameter(Mandatory, Position = 0)][string]$ProjectDir)
    $graph = Get-Graph $ProjectDir
    foreach ($line in (Format-GraphAscii $graph)) { Write-Host $line }
}

# --- Chạy trực tiếp (không dot-source) ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 1) {
        Write-Host "Cách dùng: ./viz.ps1 <projectDir> [outPath.mmd]" -ForegroundColor Yellow
        exit 2
    }
    Show-Workflow $args[0]
    $outArg = if ($args.Count -ge 2) { $args[1] } else { $null }
    $out = Export-WorkflowMermaid $args[0] $outArg
    Write-Host ''
    Write-Host "Mermaid → $out" -ForegroundColor Green
    exit 0
}

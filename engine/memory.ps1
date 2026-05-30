# memory.ps1 — read-path cho memory store 2 tầng (Phase M-A.2).
#
# Scope A.2: hàm thuần `Get-Memory $ProjectDir [-Cap N]` → hashtable 3 key
#   { mem_mistakes; mem_patterns; mem_context } để bridge nạp vào context đầu vòng đời.
#   - HQ-global: company/memory/{mistakes,patterns,global}.md (resolve $PSScriptRoot/../memory).
#   - per-branch: <ProjectDir>/memory/context.md.
#   - mem_patterns = patterns.md + global.md gộp rồi cap N chung (hợp đồng bridge 3 key, README).
#   - Mỗi loại: split file theo delimiter entry `## <YYYY-MM-DD HH:MM> — <slug>` → giữ N block
#     mới nhất (cuối file) → join lại. File/thư mục thiếu → key = '' (KHÔNG throw).
#   - Bỏ qua block ví dụ trong code-fence ``` (seed .md có entry mẫu trong fence — không tính).
#
# Scope M-B.1: write-path `Write-MemoryEntry $ProjectDir $type $content` — append 1 block
#   date-stamped vào đúng tầng theo loại (mistakes/patterns/global → HQ-global company/memory/;
#   context → per-branch <ProjectDir>/memory/). Tạo file/thư mục nếu thiếu (per-branch lazy).

Set-StrictMode -Version Latest

# Loại memory hợp lệ + delimiter entry thật: header `## YYYY-MM-DD HH:MM ...` ở đầu dòng (README).
$script:MemTypes       = @('mistakes', 'patterns', 'global', 'context')
$script:MemEntryHeader = '^##\s+\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\b'
# A-23: timestamp `yyyy-MM-dd HH:mm` của block (capture group) — 1 nguồn cho đọc/sort.
$script:MemStampFormat = 'yyyy-MM-dd HH:mm'
$script:MemStampRegex  = '^##\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})\b'

function Format-MemoryHeader {
    <#
    .SYNOPSIS
        A-23: 1 nguồn DUY NHẤT sinh dòng header entry `## <yyyy-MM-dd HH:mm> — <slug>`.
        Write-MemoryEntry ghi qua hàm này; round-trip với $script:MemEntryHeader (đọc) được
        bảo đảm bằng guard trong Write-MemoryEntry → đổi format mà quên regex sẽ throw rõ ràng.
    #>
    param([Parameter(Mandatory)][datetime]$When, [Parameter(Mandatory)][string]$Slug)
    return "## $($When.ToString($script:MemStampFormat)) — $Slug"
}

function Get-MemoryEntryStamp {
    <#
    .SYNOPSIS
        Lấy chuỗi timestamp `yyyy-MM-dd HH:mm` từ dòng header của 1 block (để sort A-21).
        Định dạng này SORT-LEXICAL = SORT-CHRONOLOGICAL nên so chuỗi là đủ. Không match → ''.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Block)
    $first = @($Block -split "`r?`n")[0]
    if ($first -match $script:MemStampRegex) { return $Matches[1] }
    return ''
}

function Get-MemoryEntry {
    <#
    .SYNOPSIS
        Đọc 1 file memory → mảng block-entry (theo delimiter timestamp), bỏ qua nội dung fence.
    .DESCRIPTION
        Trả @() nếu file thiếu/rỗng. Một entry = từ dòng header `## <date> <time>` tới ngay trước
        header kế. Header nằm trong code-fence (```) KHÔNG mở block mới (seed .md chứa ví dụ trong
        fence). Phần header tài liệu của file (trước entry thật) bị loại tự nhiên — chưa có $cur.
    .OUTPUTS [string[]] các block, thứ tự xuất hiện (cũ → mới, mới nhất ở cuối).
    #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }

    $lines  = @($raw -split "`r?`n")
    $blocks = [System.Collections.Generic.List[string]]::new()
    $cur    = $null
    # A-22: fence-skip CHỈ có nghĩa ở vùng PREAMBLE (tài liệu đầu file — seed .md để header ví dụ
    # trong code-fence). Sau entry THẬT đầu tiên, fence chỉ là nội dung body → fence lẻ (mở thiếu
    # đóng) KHÔNG còn kẹt $inFence=true rồi nuốt mọi entry kế. Đếm fence để cảnh báo nếu lẻ.
    $inPreamble = $true
    $inFence    = $false
    $fenceCount = 0

    foreach ($ln in $lines) {
        $isFence = $ln -match '^\s*```'
        if ($isFence) { $fenceCount++ }

        if ($inPreamble) {
            if ($isFence) { $inFence = -not $inFence; continue }
            if ($inFence) { continue }   # header ví dụ trong fence preamble → bỏ qua
        }

        if ($ln -match $script:MemEntryHeader) {
            $inPreamble = $false
            if ($null -ne $cur) { $blocks.Add(($cur.ToArray() -join "`n").TrimEnd()) }
            $cur = [System.Collections.Generic.List[string]]::new()
            $cur.Add($ln)
        }
        elseif ($null -ne $cur) {
            $cur.Add($ln)
        }
    }
    if ($null -ne $cur) { $blocks.Add(($cur.ToArray() -join "`n").TrimEnd()) }

    if ($fenceCount % 2 -ne 0) {
        Write-Warning "Get-MemoryEntry: code-fence không cân bằng trong '$Path' ($fenceCount fence) — có thể bỏ sót entry."
    }

    return @($blocks.ToArray())
}

function Join-MemoryEntry {
    <#
    .SYNOPSIS
        Giữ N block mới nhất (cuối mảng) → join bằng dòng trống. Mảng rỗng → ''.
    #>
    param([object[]]$Blocks, [int]$Cap)
    $b = @($Blocks)
    if ($b.Count -eq 0) { return '' }
    if ($Cap -gt 0 -and $b.Count -gt $Cap) {
        $b = @($b[($b.Count - $Cap)..($b.Count - 1)])
    }
    return ($b -join "`n`n")
}

function Get-MemoryRoot {
    <#
    .SYNOPSIS
        Thư mục HQ-global memory: company/memory/ — resolve tương đối từ engine ($PSScriptRoot/..).
    #>
    return (Join-Path (Join-Path $PSScriptRoot '..') 'memory')
}

function Get-Memory {
    <#
    .SYNOPSIS
        Đọc memory 2 tầng → hashtable { mem_mistakes; mem_patterns; mem_context } (cap N/loại).
    .DESCRIPTION
        HQ-global (company/memory/): mistakes.md → mem_mistakes; patterns.md + global.md gộp →
        mem_patterns (cap N chung). Per-branch (<ProjectDir>/memory/context.md) → mem_context.
        File/thư mục thiếu → key = '' (an toàn cho project chưa có memory). Cap mặc định N=10
        (README) — giữ N entry mới nhất mỗi loại, chống phình prompt.
    .OUTPUTS [hashtable] 3 key chuỗi.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [int]$Cap = 10
    )

    $hqDir     = Get-MemoryRoot
    $branchDir = Join-Path $ProjectDir 'memory'

    $mistakes = @(Get-MemoryEntry (Join-Path $hqDir 'mistakes.md'))
    $patterns = @(Get-MemoryEntry (Join-Path $hqDir 'patterns.md'))
    $global   = @(Get-MemoryEntry (Join-Path $hqDir 'global.md'))
    $context  = @(Get-MemoryEntry (Join-Path $branchDir 'context.md'))

    # A-21: mem_patterns gộp patterns.md + global.md → cap "N MỚI NHẤT" phải theo THỜI GIAN,
    # không theo thứ tự file. Sort theo timestamp header (lexical = chronological) trước khi
    # Join-MemoryEntry cap N cuối → entry patterns.md mới hơn không bị global.md đẩy ra.
    $patternsMerged = @(@($patterns) + @($global) | Sort-Object -Stable -Property @{ Expression = { Get-MemoryEntryStamp $_ } })

    return @{
        mem_mistakes = (Join-MemoryEntry $mistakes $Cap)
        mem_patterns = (Join-MemoryEntry $patternsMerged $Cap)
        mem_context  = (Join-MemoryEntry $context $Cap)
    }
}

function Get-MemoryWriteTarget {
    <#
    .SYNOPSIS
        Loại → file đích theo tầng (bảng README A.1): mistakes/patterns/global → HQ-global
        company/memory/<type>.md; context → per-branch <ProjectDir>/memory/context.md.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Mandatory, Position = 1)][string]$Type
    )
    if ($Type -eq 'context') {
        return (Join-Path (Join-Path $ProjectDir 'memory') 'context.md')
    }
    return (Join-Path (Get-MemoryRoot) "$Type.md")
}

function Write-MemoryEntry {
    <#
    .SYNOPSIS
        Append 1 block memory date-stamped vào đúng tầng theo loại (write-path cuối vòng đời).
    .DESCRIPTION
        Block = header `## <yyyy-MM-dd HH:mm> — <slug>` (khớp delimiter Get-MemoryEntry đọc lại) +
        nội dung $Content. Loại → tầng/file theo Get-MemoryWriteTarget; tạo thư mục/file nếu thiếu
        (per-branch memory/ sinh lười ở đây). Idempotent về format: luôn đúng 1 block/lần gọi,
        ngăn cách block cũ bằng dòng trống. Loại sai → throw (validate đã chặn từ author-time).
    .OUTPUTS [string] đường dẫn file đã ghi.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$ProjectDir,
        [Parameter(Mandatory, Position = 1)][string]$Type,
        [Parameter(Mandatory, Position = 2)][AllowEmptyString()][string]$Content,
        [string]$Slug = 'record'
    )

    if ($Type -notin $script:MemTypes) {
        throw "Write-MemoryEntry: loại '$Type' không hợp lệ (cần: $($script:MemTypes -join ', '))"
    }
    if ([string]::IsNullOrWhiteSpace($Slug)) { $Slug = 'record' }

    $path = Get-MemoryWriteTarget $ProjectDir $Type
    $dir  = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # A-23: header sinh qua 1 nguồn (Format-MemoryHeader). Guard round-trip: header ghi ra PHẢI
    # khớp regex đọc ($script:MemEntryHeader) → đổi format mà quên regex sẽ throw ngay, không
    # ghi entry "câm" (đọc lại không thấy như A-22 cũ).
    $header = Format-MemoryHeader (Get-Date) $Slug
    if ($header -notmatch $script:MemEntryHeader) {
        throw "Write-MemoryEntry: header '$header' không khớp delimiter đọc ($script:MemEntryHeader) — format/regex lệch nhau."
    }
    $block = "$header`n$(([string]$Content).TrimEnd())"

    if (Test-Path -LiteralPath $path) {
        $existing = Get-Content -LiteralPath $path -Raw -Encoding utf8
        if (-not [string]::IsNullOrWhiteSpace($existing)) {
            $block = "$($existing.TrimEnd())`n`n$block"
        }
    }
    Set-Content -LiteralPath $path -Value $block -Encoding utf8
    return $path
}

# --- Chạy trực tiếp (không dot-source): in hashtable memory của project để soi tay ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 1) {
        Write-Host "Cách dùng: ./memory.ps1 <projectDir> [cap]" -ForegroundColor Yellow
        exit 2
    }
    $cap = if ($args.Count -ge 2) { [int]$args[1] } else { 10 }
    $mem = Get-Memory $args[0] $cap
    foreach ($k in @('mem_mistakes', 'mem_patterns', 'mem_context')) {
        Write-Host "=== $k ===" -ForegroundColor Cyan
        $v = [string]$mem[$k]
        if ([string]::IsNullOrEmpty($v)) { Write-Host '  (rỗng)' -ForegroundColor DarkGray }
        else { Write-Host $v }
    }
    exit 0
}

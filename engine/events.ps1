# events.ps1 — event stream emitter (Phase D-I, Session D.1 → I.A.1).
#
# Scope D.1: kênh QUAN SÁT thêm (additive) song song run.log — KHÔNG thay run.log.
#   `Write-Event $RunDir $Type [$Payload]` append 1 dòng JSON gọn vào <RunDir>/events.ndjson
#   (NDJSON: 1 event = 1 dòng `ConvertTo-Json -Compress`; UTF8-no-BOM đồng kiểu Write-Json).
#   Schema: { seq, ts, type, ...payload } — seq tự tăng theo số dòng đã có (self-sequencing,
#   stateless → dot-source-safe, resume nối tiếp đúng). payload trộn thẳng top-level (vd node,
#   agent, output, status, terminal).
#   9 loại event:
#     run_start, node_start, node_output, node_done, awaiting, resumed, diff_violation, run_end
#     (D.1 phát 5: run_start/node_start/node_output/node_done/run_end; awaiting/resumed/diff_violation D.3/D.6)
#     node_usage (I.A.1): { node, agent, step, usage:{input_tokens,output_tokens,cache_creation,
#                            cache_read,cost,mock,prompt_chars?,output_chars?} }
#   Bất biến: event là quan sát, KHÔNG phải state — lỗi ghi event KHÔNG được phá run (nuốt lỗi).

Set-StrictMode -Version Latest

# Loại event hợp lệ — 1 nguồn để D.3/D.6 mở rộng + (tuỳ) guard typo.
# Phase K (D-K4): event `awaiting` mang thêm field `kind`:
#   kind='approval' — dừng chờ người duyệt (type:approval node hoặc pause:always worker)
#   kind='input'    — dừng chờ câu trả lời (pause:ask worker, marker ASK_USER:)
# event `resumed` cũng mang `kind` tương ứng (approval: {decision,cursor} / input: {answer}).
# KHÔNG thêm loại event mới — app/SSE (Phase L) phân biệt qua field `kind`.
$script:EventTypes = @(
    'run_start', 'node_start', 'node_output', 'node_done',
    'awaiting', 'resumed', 'diff_violation', 'run_end',
    'node_usage'   # I.A.1: usage thật (real-mode) hoặc proxy chars (mock, field mock=true)
)

function Write-Event {
    <#
    .SYNOPSIS
        Append 1 event JSON-line vào <RunDir>/events.ndjson (NDJSON, UTF8-no-BOM).
    .DESCRIPTION
        Kênh quan sát THÊM song song run.log (đóng #3: live log có nội dung output thật, không
        chỉ "(N chars)"). seq tự tăng theo số dòng hiện có → stateless, resume nối tiếp đúng.
        $Payload (hashtable, tuỳ) trộn thẳng vào top-level event (node/agent/output/status/...).
        Lỗi ghi event bị NUỐT — event không phải state, không được phá run.
    .OUTPUTS Không (side-effect: append file). Không throw.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$RunDir,
        [Parameter(Mandatory, Position = 1)][string]$Type,
        [Parameter(Position = 2)][hashtable]$Payload
    )
    try {
        $path = Join-Path $RunDir 'events.ndjson'
        $seq = 0
        if (Test-Path -LiteralPath $path) {
            $seq = @(Get-Content -LiteralPath $path -Encoding utf8).Count
        }
        $evt = [ordered]@{
            seq  = $seq
            ts   = (Get-Date).ToString('o')
            type = $Type
        }
        if ($Payload) {
            foreach ($k in @($Payload.Keys)) { $evt[$k] = $Payload[$k] }
        }
        $json = $evt | ConvertTo-Json -Depth 20 -Compress
        Add-Content -LiteralPath $path -Value $json -Encoding utf8
    }
    catch {
        # event = quan sát; lỗi ghi KHÔNG phá run. Im lặng (tránh nhiễu run.log).
    }
}

# --- Chạy trực tiếp (không dot-source): đọc + in lại events.ndjson của 1 run để soi tay ---
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -lt 1) {
        Write-Host "Cách dùng: ./events.ps1 <runDir>   (in events.ndjson dạng bảng gọn)" -ForegroundColor Yellow
        exit 2
    }
    $path = Join-Path $args[0] 'events.ndjson'
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "Không có events.ndjson trong: $($args[0])" -ForegroundColor Red
        exit 1
    }
    foreach ($line in @(Get-Content -LiteralPath $path -Encoding utf8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $e = $line | ConvertFrom-Json
        $node = if ($e.PSObject.Properties.Name -contains 'node') { $e.node } else { '' }
        Write-Host ("[{0}] {1,-14} {2}" -f $e.seq, $e.type, $node) -ForegroundColor Cyan
    }
    exit 0
}

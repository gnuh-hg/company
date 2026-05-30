# bridge.ps1 — compose context: resolve {{key}} → prompt
# Implement Session 1.3.
#
# Scope 1.3: resolve mọi {{key}} trong input template của 1 step thành text thật.
# {{user_request}} = input gốc; {{output_key}} = output .txt của step trước (đã chạy).
# Engine (workflow.ps1) tích luỹ output vào $Context rồi gọi Resolve-Prompt cho mỗi step.

Set-StrictMode -Version Latest

function Resolve-Prompt {
    <#
    .SYNOPSIS
        Thay mọi token {{key}} trong $Template bằng giá trị trong $Context.
    .DESCRIPTION
        Token hợp lệ: {{ <word> }} ( [A-Za-z0-9_] , cho phép khoảng trắng quanh key ).
        - Key có trong $Context → thay bằng giá trị (string).
        - Key KHÔNG có → throw, liệt kê key chưa resolve được (lỗi thứ tự dep / sai tên key).
        Đây là chỗ duy nhất engine dịch ngữ nghĩa {{key}} → văn bản — cạnh DAG suy ra từ chính
        các token này (QĐ-1).
    .PARAMETER Template
        input của step, vd: "{{user_request}}`n{{a}}".
    .PARAMETER Context
        Hashtable key→value: gồm 'user_request' + mọi output_key của step đã chạy xong.
    .OUTPUTS
        Prompt cuối, không còn token nào.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Template,
        [Parameter(Mandatory, Position = 1)][hashtable]$Context
    )

    $pattern = '\{\{\s*([A-Za-z0-9_]+)\s*\}\}'
    $missing = [System.Collections.Generic.List[string]]::new()

    $resolved = [regex]::Replace($Template, $pattern, {
            param($m)
            $key = $m.Groups[1].Value
            if ($Context.ContainsKey($key)) {
                return [string]$Context[$key]
            }
            if (-not $missing.Contains($key)) { $missing.Add($key) }
            return $m.Value   # giữ nguyên để báo lỗi rõ ràng bên dưới
        })

    if ($missing.Count -gt 0) {
        throw "Resolve-Prompt: không resolve được key: $($missing -join ', '). Key khả dụng: $($Context.Keys -join ', ')"
    }

    return $resolved
}

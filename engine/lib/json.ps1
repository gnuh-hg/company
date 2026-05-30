# lib/json.ps1 — đọc/ghi JSON an toàn (dot-source để dùng).
# Implement Session 1.1.

Set-StrictMode -Version Latest

function Get-Prop {
    <#
    .SYNOPSIS Lấy property $Name của $Obj, trả $null nếu vắng (StrictMode-safe).
    .DESCRIPTION
        Accessor dùng chung cho mọi PSCustomObject đọc-từ-JSON (graph/validate/spec/status/e2e).
        Guard cả $Obj null lẫn $Obj.PSObject null (object lạ không có PSObject) trước khi soi
        Properties.Name → an toàn dưới StrictMode. Trả $null khi vắng property.
        (A-06: gom 4 bản/3 tên Get-Prop·Get-VProp·Get-SProp×2 → 1 nguồn tại đây.)
    #>
    param($Obj, [Parameter(Mandatory)][string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject -and ($Obj.PSObject.Properties.Name -contains $Name)) {
        return $Obj.$Name
    }
    return $null
}

function Read-Json {
    <#
    .SYNOPSIS Đọc file JSON → object. Throw nếu thiếu file hoặc JSON hỏng.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Read-Json: file không tồn tại: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Read-Json: file rỗng: $Path"
    }
    try {
        return $raw | ConvertFrom-Json
    }
    catch {
        throw "Read-Json: JSON không hợp lệ trong $Path — $($_.Exception.Message)"
    }
}

function Write-Json {
    <#
    .SYNOPSIS Ghi object → file JSON (UTF-8, tự tạo thư mục cha).
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$Path,
        [Parameter(Mandatory, Position = 1)]$Object,
        [int]$Depth = 20
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $json = $Object | ConvertTo-Json -Depth $Depth
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8
}

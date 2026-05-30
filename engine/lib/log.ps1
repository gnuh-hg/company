# lib/log.ps1 — logging chuẩn (dot-source để dùng).
# Implement Session 1.1.

Set-StrictMode -Version Latest

# Thứ tự mức log; dòng dưới ngưỡng $env:ENGINE_LOG_LEVEL sẽ bị bỏ qua khi in ra màn hình.
$script:LogLevelOrder = @{ DEBUG = 0; INFO = 1; WARN = 2; ERROR = 3 }
$script:LogLevelColor = @{ DEBUG = 'DarkGray'; INFO = 'Cyan'; WARN = 'Yellow'; ERROR = 'Red' }

function Write-Log {
    <#
    .SYNOPSIS Ghi 1 dòng log có timestamp + level. In ra màn hình; append vào -LogFile nếu có.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$Message,
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')][string]$Level = 'INFO',
        [string]$LogFile
    )
    $ts   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$ts] [$Level] $Message"

    $threshold = if ($env:ENGINE_LOG_LEVEL -and $script:LogLevelOrder.ContainsKey($env:ENGINE_LOG_LEVEL)) {
        $script:LogLevelOrder[$env:ENGINE_LOG_LEVEL]
    } else { 0 }

    if ($script:LogLevelOrder[$Level] -ge $threshold) {
        Write-Host $line -ForegroundColor $script:LogLevelColor[$Level]
    }

    if ($LogFile) {
        $dir = Split-Path -Parent $LogFile
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Add-Content -LiteralPath $LogFile -Value $line -Encoding utf8
    }
}

function Write-LogInfo  { param([Parameter(Mandatory, Position = 0)][string]$Message, [string]$LogFile) Write-Log $Message -Level INFO  -LogFile $LogFile }
function Write-LogWarn  { param([Parameter(Mandatory, Position = 0)][string]$Message, [string]$LogFile) Write-Log $Message -Level WARN  -LogFile $LogFile }
function Write-LogError { param([Parameter(Mandatory, Position = 0)][string]$Message, [string]$LogFile) Write-Log $Message -Level ERROR -LogFile $LogFile }
function Write-LogDebug { param([Parameter(Mandatory, Position = 0)][string]$Message, [string]$LogFile) Write-Log $Message -Level DEBUG -LogFile $LogFile }

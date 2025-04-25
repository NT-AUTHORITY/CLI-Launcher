# Logger.ps1
# Module for handling logging and debugging

# Write debug message
function Write-DebugLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Source = "General",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Debug")]
        [string]$Level = "Info"
    )

    # Get launcher configuration
    $config = Get-LauncherConfig

    # Determine color based on level
    $color = switch ($Level) {
        "Info" { "White" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Debug" { "Cyan" }
        default { "White" }
    }

    # Format timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Format log message
    $logMessage = "[$timestamp] [$Level] [$Source] $Message"

    # Always write to log file
    try {
        $logFile = Join-Path -Path $configPath -ChildPath "launcher.log"

        # Make sure the directory exists
        if (-not (Test-Path -Path $configPath)) {
            New-Item -Path $configPath -ItemType Directory -Force | Out-Null
        }

        # Use Out-File instead of Add-Content to avoid stream issues
        $logMessage | Out-File -FilePath $logFile -Append -Encoding utf8
    }
    catch {
        # Silently fail if we can't write to the log file
        # This prevents errors from breaking the launcher
    }

    # Only display debug messages if debug mode is enabled
    if ($config.DebugMode -or $Level -ne "Debug") {
        Write-Host $logMessage -ForegroundColor $color
    }
}

# Handle error with debug information
function Handle-Error {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$Source = "General",

        [Parameter(Mandatory = $false)]
        [string]$CustomMessage = "",

        [Parameter(Mandatory = $false)]
        [switch]$Continue
    )

    # Get launcher configuration
    $config = Get-LauncherConfig

    # Basic error message
    $errorMessage = if ($CustomMessage) { $CustomMessage } else { "An error occurred" }
    Write-DebugLog -Message $errorMessage -Source $Source -Level "Error"

    # If debug mode is enabled, show detailed error information
    if ($config.DebugMode) {
        Write-DebugLog -Message "Error details:" -Source $Source -Level "Debug"
        Write-DebugLog -Message "Exception: $($ErrorRecord.Exception.GetType().FullName)" -Source $Source -Level "Debug"
        Write-DebugLog -Message "Message: $($ErrorRecord.Exception.Message)" -Source $Source -Level "Debug"
        Write-DebugLog -Message "ScriptStackTrace: $($ErrorRecord.ScriptStackTrace)" -Source $Source -Level "Debug"

        if (-not $Continue) {
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }

    return $Continue.IsPresent
}

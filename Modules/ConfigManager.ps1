# ConfigManager.ps1
# Module for managing launcher configuration

# Initialize launcher configuration
function Initialize-LauncherConfig {
    $configFile = Join-Path -Path $configPath -ChildPath "config.json"

    if (-not (Test-Path -Path $configFile)) {
        $defaultConfig = @{
            MinMemory = 1024
            MaxMemory = 2048
            JavaPath = $null
            LastVersion = $null
            LauncherTheme = "Default"
            DebugMode = $false
            MaxDownloadThreads = 8
            UseMultithreadDownload = $true
        }

        $defaultConfig | ConvertTo-Json | Set-Content -Path $configFile
        Write-Host "Default configuration file created" -ForegroundColor Green
    }
}

# Get launcher configuration
function Get-LauncherConfig {
    $configFile = Join-Path -Path $configPath -ChildPath "config.json"

    if (-not (Test-Path -Path $configFile)) {
        Initialize-LauncherConfig
    }

    try {
        $config = Get-Content -Path $configFile -Raw | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Host "Error reading configuration file" -ForegroundColor Red
        Initialize-LauncherConfig
        return Get-LauncherConfig
    }
}

# Save launcher configuration
function Save-LauncherConfig {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    $configFile = Join-Path -Path $configPath -ChildPath "config.json"

    try {
        $Config | ConvertTo-Json | Set-Content -Path $configFile
        Write-Host "Configuration saved" -ForegroundColor Green
    }
    catch {
        Write-Host "Error saving configuration" -ForegroundColor Red
    }
}

# Update launcher configuration
function Update-LauncherConfig {
    param (
        [int]$MinMemory,
        [int]$MaxMemory,
        [string]$JavaPath,
        [string]$LauncherTheme,
        [switch]$DebugMode,
        [int]$MaxDownloadThreads,
        [switch]$UseMultithreadDownload
    )

    $config = Get-LauncherConfig

    if ($MinMemory) {
        $config.MinMemory = $MinMemory
    }

    if ($MaxMemory) {
        $config.MaxMemory = $MaxMemory
    }

    if ($JavaPath) {
        $config.JavaPath = $JavaPath
    }

    if ($LauncherTheme) {
        $config.LauncherTheme = $LauncherTheme
    }

    if ($PSBoundParameters.ContainsKey('DebugMode')) {
        $config.DebugMode = $DebugMode.IsPresent
    }

    if ($MaxDownloadThreads) {
        $config.MaxDownloadThreads = $MaxDownloadThreads
    }

    if ($PSBoundParameters.ContainsKey('UseMultithreadDownload')) {
        $config.UseMultithreadDownload = $UseMultithreadDownload.IsPresent
    }

    Save-LauncherConfig -Config $config
}

# Display settings menu
function Show-SettingsMenu {
    while ($true) {
        Clear-Host
        $config = Get-LauncherConfig

        Write-Host "===== Launcher Settings =====" -ForegroundColor Cyan
        Write-Host "1. Memory Settings (Current: Min $($config.MinMemory)MB, Max $($config.MaxMemory)MB)"
        Write-Host "2. Java Path (Current: $($config.JavaPath -or 'Auto-detect'))"
        Write-Host "3. Launcher Theme (Current: $($config.LauncherTheme))"
        $debugStatus = if ($config.DebugMode) { 'Enabled' } else { 'Disabled' }
        Write-Host "4. Debug Mode (Current: $debugStatus)"
        $multithreadStatus = if ($config.UseMultithreadDownload) { 'Enabled' } else { 'Disabled' }
        Write-Host "5. Multithread Download (Current: $multithreadStatus, Threads: $($config.MaxDownloadThreads))"
        Write-Host "6. Return to Main Menu"

        $choice = Read-Host "Please select an option"

        switch ($choice) {
            "1" {
                $minMemory = Read-Host "Enter minimum memory (MB)"
                $maxMemory = Read-Host "Enter maximum memory (MB)"

                if ([int]::TryParse($minMemory, [ref]$null) -and [int]::TryParse($maxMemory, [ref]$null)) {
                    Update-LauncherConfig -MinMemory ([int]$minMemory) -MaxMemory ([int]$maxMemory)
                }
                else {
                    Write-Host "Invalid memory values" -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
            "2" {
                $javaPath = Read-Host "Enter Java path (leave empty for auto-detection)"

                if (-not $javaPath -or (Test-Path -Path $javaPath)) {
                    Update-LauncherConfig -JavaPath $javaPath
                }
                else {
                    Write-Host "Invalid Java path" -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
            "3" {
                Write-Host "Available themes: Default, Dark, Light" -ForegroundColor Cyan
                $theme = Read-Host "Select theme"

                if ($theme -in @("Default", "Dark", "Light")) {
                    Update-LauncherConfig -LauncherTheme $theme
                }
                else {
                    Write-Host "Invalid theme" -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
            "4" {
                $debugEnabled = $config.DebugMode
                $newDebugMode = -not $debugEnabled
                Update-LauncherConfig -DebugMode:$newDebugMode
                $statusText = if ($newDebugMode) { "enabled" } else { "disabled" }
                Write-Host "Debug mode $statusText" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "5" {
                $useMultithread = Read-Host "Enable multithread download? (Y/N)"
                $useMultithreadEnabled = $useMultithread -eq "Y" -or $useMultithread -eq "y"

                if ($useMultithreadEnabled) {
                    $maxThreads = Read-Host "Enter maximum number of download threads (4-32)"
                    if ([int]::TryParse($maxThreads, [ref]$null) -and [int]$maxThreads -ge 4 -and [int]$maxThreads -le 32) {
                        Update-LauncherConfig -MaxDownloadThreads ([int]$maxThreads) -UseMultithreadDownload
                    }
                    else {
                        Write-Host "Invalid thread count. Using default of 8 threads." -ForegroundColor Yellow
                        Update-LauncherConfig -MaxDownloadThreads 8 -UseMultithreadDownload
                    }
                }
                else {
                    Update-LauncherConfig -UseMultithreadDownload:$false
                }

                $statusText = if ($useMultithreadEnabled) { "enabled" } else { "disabled" }
                Write-Host "Multithread download $statusText" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "6" {
                return
            }
            default {
                Write-Host "Invalid choice, please try again" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

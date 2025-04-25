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
            DownloadMirror = "Official"
            CustomMirrorUrl = ""
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

        # Define default configuration values
        $defaultConfig = @{
            MinMemory = 1024
            MaxMemory = 2048
            JavaPath = $null
            LastVersion = $null
            LauncherTheme = "Default"
            DebugMode = $false
            MaxDownloadThreads = 8
            UseMultithreadDownload = $true
            DownloadMirror = "Official"
            CustomMirrorUrl = ""
        }

        # Check for missing properties and add them with default values
        $configUpdated = $false
        foreach ($key in $defaultConfig.Keys) {
            if (-not (Get-Member -InputObject $config -Name $key -MemberType Properties)) {
                Write-DebugLog -Message "Adding missing config property: $key" -Source "ConfigManager" -Level "Warning"
                Add-Member -InputObject $config -MemberType NoteProperty -Name $key -Value $defaultConfig[$key]
                $configUpdated = $true
            }
        }

        # Save the updated config if needed
        if ($configUpdated) {
            Write-DebugLog -Message "Updating config file with missing properties" -Source "ConfigManager" -Level "Info"
            $config | ConvertTo-Json | Set-Content -Path $configFile
        }

        return $config
    }
    catch {
        Write-Host "Error reading configuration file" -ForegroundColor Red
        Write-DebugLog -Message "Error reading configuration file: $($_.Exception.Message)" -Source "ConfigManager" -Level "Error"
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
        [switch]$UseMultithreadDownload,
        [string]$DownloadMirror,
        [string]$CustomMirrorUrl
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

    if ($DownloadMirror) {
        $config.DownloadMirror = $DownloadMirror
    }

    if ($PSBoundParameters.ContainsKey('CustomMirrorUrl')) {
        $config.CustomMirrorUrl = $CustomMirrorUrl
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
        Write-Host "6. Download Mirror (Current: $($config.DownloadMirror))"
        Write-Host "7. Return to Main Menu"

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
                Clear-Host
                Write-Host "===== Download Mirror Settings =====" -ForegroundColor Cyan
                Write-Host "Select a download mirror:"
                Write-Host "1. Official (Mojang)"
                Write-Host "2. BMCLAPI (China)"
                Write-Host "3. MCBBS (China)"
                Write-Host "4. Custom"

                $mirrorChoice = Read-Host "Please select a mirror"

                switch ($mirrorChoice) {
                    "1" {
                        Update-LauncherConfig -DownloadMirror "Official"
                        Write-Host "Download mirror set to Official" -ForegroundColor Green
                    }
                    "2" {
                        Update-LauncherConfig -DownloadMirror "BMCLAPI"
                        Write-Host "Download mirror set to BMCLAPI" -ForegroundColor Green
                    }
                    "3" {
                        Update-LauncherConfig -DownloadMirror "MCBBS"
                        Write-Host "Download mirror set to MCBBS" -ForegroundColor Green
                    }
                    "4" {
                        $customUrl = Read-Host "Enter custom mirror base URL (e.g., https://example.com/minecraft)"
                        if ($customUrl) {
                            Update-LauncherConfig -DownloadMirror "Custom" -CustomMirrorUrl $customUrl
                            Write-Host "Download mirror set to Custom: $customUrl" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Custom mirror URL cannot be empty" -ForegroundColor Red
                        }
                    }
                    default {
                        Write-Host "Invalid choice, mirror not changed" -ForegroundColor Red
                    }
                }

                Start-Sleep -Seconds 1
            }
            "7" {
                return
            }
            default {
                Write-Host "Invalid choice, please try again" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

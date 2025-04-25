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
            AutoInstallModLoaderDependencies = $true
            DefaultModLoader = "None"
            VersionIsolation = $true
            IsolateGameDirs = $true
            IsolateSaveDirs = $true
            IsolateResourcePacks = $true
            IsolateScreenshots = $false
            IsolateShaderPacks = $true
            IsolateMods = $true
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
            AutoInstallModLoaderDependencies = $true
            DefaultModLoader = "None"
            VersionIsolation = $true
            IsolateGameDirs = $true
            IsolateSaveDirs = $true
            IsolateResourcePacks = $true
            IsolateScreenshots = $false
            IsolateShaderPacks = $true
            IsolateMods = $true
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
        [string]$CustomMirrorUrl,
        [switch]$AutoInstallModLoaderDependencies,
        [string]$DefaultModLoader,
        [string]$LastVersion,
        [switch]$VersionIsolation,
        [switch]$IsolateGameDirs,
        [switch]$IsolateSaveDirs,
        [switch]$IsolateResourcePacks,
        [switch]$IsolateScreenshots,
        [switch]$IsolateShaderPacks,
        [switch]$IsolateMods
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

    if ($PSBoundParameters.ContainsKey('AutoInstallModLoaderDependencies')) {
        $config.AutoInstallModLoaderDependencies = $AutoInstallModLoaderDependencies.IsPresent
    }

    if ($DefaultModLoader) {
        $config.DefaultModLoader = $DefaultModLoader
    }

    if ($LastVersion) {
        $config.LastVersion = $LastVersion
    }

    if ($PSBoundParameters.ContainsKey('VersionIsolation')) {
        $config.VersionIsolation = $VersionIsolation.IsPresent
    }

    if ($PSBoundParameters.ContainsKey('IsolateGameDirs')) {
        $config.IsolateGameDirs = $IsolateGameDirs.IsPresent
    }

    if ($PSBoundParameters.ContainsKey('IsolateSaveDirs')) {
        $config.IsolateSaveDirs = $IsolateSaveDirs.IsPresent
    }

    if ($PSBoundParameters.ContainsKey('IsolateResourcePacks')) {
        $config.IsolateResourcePacks = $IsolateResourcePacks.IsPresent
    }

    if ($PSBoundParameters.ContainsKey('IsolateScreenshots')) {
        $config.IsolateScreenshots = $IsolateScreenshots.IsPresent
    }

    if ($PSBoundParameters.ContainsKey('IsolateShaderPacks')) {
        $config.IsolateShaderPacks = $IsolateShaderPacks.IsPresent
    }

    if ($PSBoundParameters.ContainsKey('IsolateMods')) {
        $config.IsolateMods = $IsolateMods.IsPresent
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
        $javaPathDisplay = if ([string]::IsNullOrEmpty($config.JavaPath)) { 'Auto-detect' } else { $config.JavaPath }
        Write-Host "2. Java Path (Current: $javaPathDisplay)"
        Write-Host "3. Launcher Theme (Current: $($config.LauncherTheme))"
        $debugStatus = if ($config.DebugMode) { 'Enabled' } else { 'Disabled' }
        Write-Host "4. Debug Mode (Current: $debugStatus)"
        $multithreadStatus = if ($config.UseMultithreadDownload) { 'Enabled' } else { 'Disabled' }
        Write-Host "5. Multithread Download (Current: $multithreadStatus, Threads: $($config.MaxDownloadThreads))"
        Write-Host "6. Download Mirror (Current: $($config.DownloadMirror))"
        $autoInstallStatus = if ($config.AutoInstallModLoaderDependencies) { 'Enabled' } else { 'Disabled' }
        Write-Host "7. Mod Loader Settings (Auto-Install Dependencies: $autoInstallStatus, Default: $($config.DefaultModLoader))"
        $versionIsolationStatus = if ($config.VersionIsolation) { 'Enabled' } else { 'Disabled' }
        Write-Host "8. Version Isolation (Current: $versionIsolationStatus)"
        Write-Host "9. Return to Main Menu"

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
                Clear-Host
                Write-Host "===== Mod Loader Settings =====" -ForegroundColor Cyan

                # Auto-install dependencies
                $autoInstallStatus = if ($config.AutoInstallModLoaderDependencies) { 'Enabled' } else { 'Disabled' }
                Write-Host "1. Auto-Install Dependencies (Current: $autoInstallStatus)"

                # Default mod loader
                Write-Host "2. Default Mod Loader (Current: $($config.DefaultModLoader))"

                # Return
                Write-Host "3. Return to Settings Menu"

                $modLoaderChoice = Read-Host "Please select an option"

                switch ($modLoaderChoice) {
                    "1" {
                        $autoInstall = Read-Host "Auto-install mod loader dependencies? (Y/N)"
                        $autoInstallEnabled = $autoInstall -eq "Y" -or $autoInstall -eq "y"
                        Update-LauncherConfig -AutoInstallModLoaderDependencies:$autoInstallEnabled

                        $statusText = if ($autoInstallEnabled) { "enabled" } else { "disabled" }
                        Write-Host "Auto-install dependencies $statusText" -ForegroundColor Green
                        Start-Sleep -Seconds 1
                    }
                    "2" {
                        Clear-Host
                        Write-Host "===== Default Mod Loader =====" -ForegroundColor Cyan
                        Write-Host "Select a default mod loader:"
                        Write-Host "1. None (Vanilla)"
                        Write-Host "2. Fabric"
                        Write-Host "3. Forge"
                        Write-Host "4. NeoForge"
                        Write-Host "5. OptiFine"

                        $defaultLoaderChoice = Read-Host "Please select a default mod loader"

                        switch ($defaultLoaderChoice) {
                            "1" {
                                Update-LauncherConfig -DefaultModLoader "None"
                                Write-Host "Default mod loader set to None (Vanilla)" -ForegroundColor Green
                            }
                            "2" {
                                Update-LauncherConfig -DefaultModLoader "Fabric"
                                Write-Host "Default mod loader set to Fabric" -ForegroundColor Green
                            }
                            "3" {
                                Update-LauncherConfig -DefaultModLoader "Forge"
                                Write-Host "Default mod loader set to Forge" -ForegroundColor Green
                            }
                            "4" {
                                Update-LauncherConfig -DefaultModLoader "NeoForge"
                                Write-Host "Default mod loader set to NeoForge" -ForegroundColor Green
                            }
                            "5" {
                                Update-LauncherConfig -DefaultModLoader "OptiFine"
                                Write-Host "Default mod loader set to OptiFine" -ForegroundColor Green
                            }
                            default {
                                Write-Host "Invalid choice, default mod loader not changed" -ForegroundColor Red
                            }
                        }

                        Start-Sleep -Seconds 1
                    }
                    "3" {
                        # Return to settings menu
                    }
                    default {
                        Write-Host "Invalid choice, please try again" -ForegroundColor Red
                        Start-Sleep -Seconds 1
                    }
                }
            }
            "8" {
                Clear-Host
                Write-Host "===== Version Isolation Settings =====" -ForegroundColor Cyan

                # Main version isolation toggle
                $versionIsolationStatus = if ($config.VersionIsolation) { 'Enabled' } else { 'Disabled' }
                Write-Host "1. Version Isolation (Current: $versionIsolationStatus)"

                # Individual isolation options
                if ($config.VersionIsolation) {
                    $isolateGameDirsStatus = if ($config.IsolateGameDirs) { 'Enabled' } else { 'Disabled' }
                    Write-Host "2. Isolate Game Directories (Current: $isolateGameDirsStatus)"

                    $isolateSaveDirsStatus = if ($config.IsolateSaveDirs) { 'Enabled' } else { 'Disabled' }
                    Write-Host "3. Isolate Save Directories (Current: $isolateSaveDirsStatus)"

                    $isolateResourcePacksStatus = if ($config.IsolateResourcePacks) { 'Enabled' } else { 'Disabled' }
                    Write-Host "4. Isolate Resource Packs (Current: $isolateResourcePacksStatus)"

                    $isolateScreenshotsStatus = if ($config.IsolateScreenshots) { 'Enabled' } else { 'Disabled' }
                    Write-Host "5. Isolate Screenshots (Current: $isolateScreenshotsStatus)"

                    $isolateShaderPacksStatus = if ($config.IsolateShaderPacks) { 'Enabled' } else { 'Disabled' }
                    Write-Host "6. Isolate Shader Packs (Current: $isolateShaderPacksStatus)"

                    $isolateModsStatus = if ($config.IsolateMods) { 'Enabled' } else { 'Disabled' }
                    Write-Host "7. Isolate Mods (Current: $isolateModsStatus)"
                }

                Write-Host "0. Return to Settings Menu" -ForegroundColor Yellow

                $isolationChoice = Read-Host "Please select an option"

                switch ($isolationChoice) {
                    "1" {
                        $enableIsolation = Read-Host "Enable version isolation? (Y/N)"
                        $isolationEnabled = $enableIsolation -eq "Y" -or $enableIsolation -eq "y"
                        Update-LauncherConfig -VersionIsolation:$isolationEnabled

                        $statusText = if ($isolationEnabled) { "enabled" } else { "disabled" }
                        Write-Host "Version isolation $statusText" -ForegroundColor Green
                        Start-Sleep -Seconds 1
                    }
                    "2" {
                        if ($config.VersionIsolation) {
                            $enableIsolateGameDirs = Read-Host "Isolate game directories? (Y/N)"
                            $isolateGameDirsEnabled = $enableIsolateGameDirs -eq "Y" -or $enableIsolateGameDirs -eq "y"
                            Update-LauncherConfig -IsolateGameDirs:$isolateGameDirsEnabled

                            $statusText = if ($isolateGameDirsEnabled) { "enabled" } else { "disabled" }
                            Write-Host "Game directories isolation $statusText" -ForegroundColor Green
                            Start-Sleep -Seconds 1
                        }
                    }
                    "3" {
                        if ($config.VersionIsolation) {
                            $enableIsolateSaveDirs = Read-Host "Isolate save directories? (Y/N)"
                            $isolateSaveDirsEnabled = $enableIsolateSaveDirs -eq "Y" -or $enableIsolateSaveDirs -eq "y"
                            Update-LauncherConfig -IsolateSaveDirs:$isolateSaveDirsEnabled

                            $statusText = if ($isolateSaveDirsEnabled) { "enabled" } else { "disabled" }
                            Write-Host "Save directories isolation $statusText" -ForegroundColor Green
                            Start-Sleep -Seconds 1
                        }
                    }
                    "4" {
                        if ($config.VersionIsolation) {
                            $enableIsolateResourcePacks = Read-Host "Isolate resource packs? (Y/N)"
                            $isolateResourcePacksEnabled = $enableIsolateResourcePacks -eq "Y" -or $enableIsolateResourcePacks -eq "y"
                            Update-LauncherConfig -IsolateResourcePacks:$isolateResourcePacksEnabled

                            $statusText = if ($isolateResourcePacksEnabled) { "enabled" } else { "disabled" }
                            Write-Host "Resource packs isolation $statusText" -ForegroundColor Green
                            Start-Sleep -Seconds 1
                        }
                    }
                    "5" {
                        if ($config.VersionIsolation) {
                            $enableIsolateScreenshots = Read-Host "Isolate screenshots? (Y/N)"
                            $isolateScreenshotsEnabled = $enableIsolateScreenshots -eq "Y" -or $enableIsolateScreenshots -eq "y"
                            Update-LauncherConfig -IsolateScreenshots:$isolateScreenshotsEnabled

                            $statusText = if ($isolateScreenshotsEnabled) { "enabled" } else { "disabled" }
                            Write-Host "Screenshots isolation $statusText" -ForegroundColor Green
                            Start-Sleep -Seconds 1
                        }
                    }
                    "6" {
                        if ($config.VersionIsolation) {
                            $enableIsolateShaderPacks = Read-Host "Isolate shader packs? (Y/N)"
                            $isolateShaderPacksEnabled = $enableIsolateShaderPacks -eq "Y" -or $enableIsolateShaderPacks -eq "y"
                            Update-LauncherConfig -IsolateShaderPacks:$isolateShaderPacksEnabled

                            $statusText = if ($isolateShaderPacksEnabled) { "enabled" } else { "disabled" }
                            Write-Host "Shader packs isolation $statusText" -ForegroundColor Green
                            Start-Sleep -Seconds 1
                        }
                    }
                    "7" {
                        if ($config.VersionIsolation) {
                            $enableIsolateMods = Read-Host "Isolate mods? (Y/N)"
                            $isolateModsEnabled = $enableIsolateMods -eq "Y" -or $enableIsolateMods -eq "y"
                            Update-LauncherConfig -IsolateMods:$isolateModsEnabled

                            $statusText = if ($isolateModsEnabled) { "enabled" } else { "disabled" }
                            Write-Host "Mods isolation $statusText" -ForegroundColor Green
                            Start-Sleep -Seconds 1
                        }
                    }
                    "0" {
                        # Return to settings menu
                    }
                    default {
                        Write-Host "Invalid choice, please try again" -ForegroundColor Red
                        Start-Sleep -Seconds 1
                    }
                }
            }
            "9" {
                return
            }
            default {
                Write-Host "Invalid choice, please try again" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

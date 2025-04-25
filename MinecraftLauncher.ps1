# Minecraft Launcher - Main Script
# Author: NT_AUTHORITY
# Description: A simple Minecraft launcher using PowerShell and embedded C#

# Set error action preference
$ErrorActionPreference = "Stop"

# Create necessary folders
$launcherRoot = $PSScriptRoot
$modulesPath = Join-Path -Path $launcherRoot -ChildPath "Modules"
$configPath = Join-Path -Path $launcherRoot -ChildPath "Config"
$minecraftPath = Join-Path -Path $launcherRoot -ChildPath "Minecraft"
$versionsPath = Join-Path -Path $minecraftPath -ChildPath "versions"
$librariesPath = Join-Path -Path $minecraftPath -ChildPath "libraries"
$assetsPath = Join-Path -Path $minecraftPath -ChildPath "assets"
$instancesPath = Join-Path -Path $minecraftPath -ChildPath "instances"

# Create necessary directories
if (-not (Test-Path -Path $modulesPath)) { New-Item -Path $modulesPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $configPath)) { New-Item -Path $configPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $minecraftPath)) { New-Item -Path $minecraftPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $versionsPath)) { New-Item -Path $versionsPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $librariesPath)) { New-Item -Path $librariesPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $assetsPath)) { New-Item -Path $assetsPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $instancesPath)) { New-Item -Path $instancesPath -ItemType Directory | Out-Null }

# Import modules
. (Join-Path -Path $modulesPath -ChildPath "ConfigManager.ps1")
. (Join-Path -Path $modulesPath -ChildPath "Logger.ps1")
. (Join-Path -Path $modulesPath -ChildPath "Authentication.ps1")
. (Join-Path -Path $modulesPath -ChildPath "VersionManager.ps1")
. (Join-Path -Path $modulesPath -ChildPath "GameLauncher.ps1")
. (Join-Path -Path $modulesPath -ChildPath "UI.ps1")
. (Join-Path -Path $modulesPath -ChildPath "VersionIsolation.ps1")

# Import mod loader modules
. (Join-Path -Path $modulesPath -ChildPath "ModLoaderCommon.ps1")
. (Join-Path -Path $modulesPath -ChildPath "FabricManager.ps1")
. (Join-Path -Path $modulesPath -ChildPath "ForgeManager.ps1")
. (Join-Path -Path $modulesPath -ChildPath "NeoForgeManager.ps1")
. (Join-Path -Path $modulesPath -ChildPath "OptiFineManager.ps1")

# Initialize configuration
Initialize-LauncherConfig

# Display welcome message
Write-DebugLog -Message "Minecraft Launcher starting" -Source "Main" -Level "Info"
Write-Host "Welcome to Minecraft Launcher!" -ForegroundColor Green
Write-Host "Initializing..." -ForegroundColor Cyan

# Get configuration
$config = Get-LauncherConfig
Write-DebugLog -Message "Configuration loaded" -Source "Main" -Level "Debug"
Write-DebugLog -Message "Debug mode: $($config.DebugMode)" -Source "Main" -Level "Debug"

# Synchronize installed versions list
Write-DebugLog -Message "Synchronizing installed versions list" -Source "Main" -Level "Debug"
Sync-InstalledVersions -Silent

# Check authentication status
$authStatus = Get-AuthenticationStatus
if ($authStatus.IsAuthenticated) {
    Write-Host "Logged in as: $($authStatus.Username)" -ForegroundColor Green
}
else {
    Write-Host "Not logged in" -ForegroundColor Yellow
}

# Main menu loop
while ($true) {
    Show-MainMenu
    $choice = Read-Host "Please select an option"

    switch ($choice) {
        "1" { # Login/Logout
            Show-LoginMenu
        }
        "2" { # Version management
            Show-VersionMenu
        }
        "3" { # Launch game
            $installedVersions = Get-InstalledVersions

            if ($installedVersions.Count -eq 0) {
                Write-Host "No versions installed. Please install a version first." -ForegroundColor Yellow
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }

            # Check if user is authenticated
            $authStatus = Get-AuthenticationStatus
            if (-not $authStatus.IsAuthenticated) {
                Write-Host "You need to login first." -ForegroundColor Yellow
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }

            # If there's a last version, use it as default
            $config = Get-LauncherConfig
            $defaultVersion = if ($config.LastVersion -and $installedVersions -contains $config.LastVersion) { $config.LastVersion } else { $installedVersions[0] }

            # Display installed versions
            Write-Host "Installed versions:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $installedVersions.Count; $i++) {
                $version = $installedVersions[$i]
                if ($version -eq $defaultVersion) {
                    Write-Host "$($i+1). $version (default)" -ForegroundColor Green
                } else {
                    Write-Host "$($i+1). $version"
                }
            }

            $versionChoice = Read-Host "Select version to launch (default: $defaultVersion)"

            if ([string]::IsNullOrWhiteSpace($versionChoice)) {
                $selectedVersion = $defaultVersion
            } else {
                $index = [int]$versionChoice - 1
                if ($index -ge 0 -and $index -lt $installedVersions.Count) {
                    $selectedVersion = $installedVersions[$index]
                } else {
                    Write-Host "Invalid choice. Using default version: $defaultVersion" -ForegroundColor Yellow
                    $selectedVersion = $defaultVersion
                }
            }

            # Launch the game
            Write-Host "Launching Minecraft $selectedVersion..." -ForegroundColor Green
            Start-MinecraftGame -Version $selectedVersion

            # Update last version in config
            Update-LauncherConfig -LastVersion $selectedVersion
        }
        "4" { # Launch game with mod loader
            $installedVersions = Get-InstalledVersions

            if ($installedVersions.Count -eq 0) {
                Write-Host "No versions installed. Please install a version first." -ForegroundColor Yellow
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }

            # Check if user is authenticated
            $authStatus = Get-AuthenticationStatus
            if (-not $authStatus.IsAuthenticated) {
                Write-Host "You need to login first." -ForegroundColor Yellow
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }

            # Display installed versions
            Clear-Host
            Write-Host "===== Launch with Mod Loader =====" -ForegroundColor Green
            Write-Host "Step 1: Select Minecraft version" -ForegroundColor Cyan

            for ($i = 0; $i -lt $installedVersions.Count; $i++) {
                Write-Host "$($i+1). $($installedVersions[$i])"
            }

            Write-Host "0. Return to main menu" -ForegroundColor Yellow

            $versionChoice = Read-Host "Select Minecraft version"

            if ($versionChoice -eq "0") {
                continue
            }

            $versionIndex = [int]$versionChoice - 1

            if ($versionIndex -ge 0 -and $versionIndex -lt $installedVersions.Count) {
                $selectedVersion = $installedVersions[$versionIndex]

                # Get mod loaders for this version
                $modLoaders = Get-InstalledModLoaders -MinecraftVersion $selectedVersion

                if ($modLoaders.Count -eq 0) {
                    Write-Host "No mod loaders installed for Minecraft $selectedVersion" -ForegroundColor Yellow
                    Write-Host "Would you like to install a mod loader now? (Y/N)" -ForegroundColor Cyan
                    $installChoice = Read-Host

                    if ($installChoice -eq "Y" -or $installChoice -eq "y") {
                        Show-ModLoaderMenu -MinecraftVersion $selectedVersion

                        # Check again if mod loaders were installed
                        $modLoaders = Get-InstalledModLoaders -MinecraftVersion $selectedVersion

                        if ($modLoaders.Count -eq 0) {
                            Write-Host "No mod loaders installed. Returning to main menu." -ForegroundColor Yellow
                            Write-Host "Press any key to continue..." -ForegroundColor Gray
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            continue
                        }
                    } else {
                        continue
                    }
                }

                # Display installed mod loaders
                Clear-Host
                Write-Host "===== Launch with Mod Loader =====" -ForegroundColor Green
                Write-Host "Step 2: Select mod loader for Minecraft $selectedVersion" -ForegroundColor Cyan

                for ($i = 0; $i -lt $modLoaders.Count; $i++) {
                    Write-Host "$($i+1). $($modLoaders[$i].Type) $($modLoaders[$i].Version)" -ForegroundColor White
                }

                Write-Host "0. Return to main menu" -ForegroundColor Yellow

                $modLoaderChoice = Read-Host "Select mod loader"

                if ($modLoaderChoice -eq "0") {
                    continue
                }

                $modLoaderIndex = [int]$modLoaderChoice - 1

                if ($modLoaderIndex -ge 0 -and $modLoaderIndex -lt $modLoaders.Count) {
                    $selectedModLoader = $modLoaders[$modLoaderIndex]

                    # Launch the game with mod loader
                    Write-Host "Launching Minecraft $selectedVersion with $($selectedModLoader.Type) $($selectedModLoader.Version)..." -ForegroundColor Green
                    Start-MinecraftGame -Version $selectedVersion -UseModLoader -ModLoaderType $selectedModLoader.Type -ModLoaderVersion $selectedModLoader.Version

                    # Update last version in config
                    Update-LauncherConfig -LastVersion $selectedVersion
                } else {
                    Write-Host "Invalid choice" -ForegroundColor Red
                    Write-Host "Press any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            } else {
                Write-Host "Invalid choice" -ForegroundColor Red
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        "5" { # Settings
            Show-SettingsMenu
        }
        "6" { # Exit
            Write-Host "Thank you for using Minecraft Launcher!" -ForegroundColor Green
            exit
        }
        default {
            Write-Host "Invalid choice, please try again" -ForegroundColor Red
        }
    }
}

# Minecraft Launcher - Main Script
# Author: Augment Agent
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

# Create necessary directories
if (-not (Test-Path -Path $modulesPath)) { New-Item -Path $modulesPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $configPath)) { New-Item -Path $configPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $minecraftPath)) { New-Item -Path $minecraftPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $versionsPath)) { New-Item -Path $versionsPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $librariesPath)) { New-Item -Path $librariesPath -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $assetsPath)) { New-Item -Path $assetsPath -ItemType Directory | Out-Null }

# Import modules
. (Join-Path -Path $modulesPath -ChildPath "ConfigManager.ps1")
. (Join-Path -Path $modulesPath -ChildPath "Logger.ps1")
. (Join-Path -Path $modulesPath -ChildPath "Authentication.ps1")
. (Join-Path -Path $modulesPath -ChildPath "VersionManager.ps1")
. (Join-Path -Path $modulesPath -ChildPath "GameLauncher.ps1")
. (Join-Path -Path $modulesPath -ChildPath "UI.ps1")

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
            $version = Read-Host "Enter the Minecraft version to launch (e.g., 1.20.1)"
            Start-MinecraftGame -Version $version
        }
        "4" { # Settings
            Show-SettingsMenu
        }
        "5" { # Exit
            Write-Host "Thank you for using Minecraft Launcher!" -ForegroundColor Green
            exit
        }
        default {
            Write-Host "Invalid choice, please try again" -ForegroundColor Red
        }
    }
}

# UI.ps1
# Module for handling user interface

# Display main menu
function Show-MainMenu {
    Clear-Host

    # Get authentication status
    $authStatus = Get-AuthenticationStatus

    # Get configuration
    $config = Get-LauncherConfig

    # Display title
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "          Minecraft Launcher" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Cyan

    # Display login status
    if ($authStatus.IsAuthenticated) {
        if ($authStatus.IsOffline) {
            Write-Host "Logged in as: $($authStatus.Username) (Offline Mode)" -ForegroundColor Yellow
        } else {
            Write-Host "Logged in as: $($authStatus.Username)" -ForegroundColor Green
        }
    }
    else {
        Write-Host "Not logged in" -ForegroundColor Yellow
    }

    # Display last launched version
    if ($config.LastVersion) {
        Write-Host "Last launched version: $($config.LastVersion)" -ForegroundColor Cyan
    }

    # Display menu options
    Write-Host ""
    Write-Host "1. Login/Logout"
    Write-Host "2. Version Management"
    Write-Host "3. Launch Game"
    Write-Host "4. Settings"
    Write-Host "5. Exit"
    Write-Host ""
}

# Display login menu
function Show-LoginMenu {
    Clear-Host

    # Get authentication status
    $authStatus = Get-AuthenticationStatus

    Write-Host "===== Account Management =====" -ForegroundColor Cyan

    if ($authStatus.IsAuthenticated) {
        if ($authStatus.IsOffline) {
            Write-Host "Currently logged in as: $($authStatus.Username) (Offline Mode)" -ForegroundColor Yellow
        } else {
            Write-Host "Currently logged in as: $($authStatus.Username)" -ForegroundColor Green
        }
        Write-Host ""
        Write-Host "1. Logout"
        Write-Host "2. Return to main menu"

        $choice = Read-Host "Please select an option"

        switch ($choice) {
            "1" {
                Invoke-Logout
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                return
            }
            default {
                Write-Host "Invalid choice, please try again" -ForegroundColor Red
                Start-Sleep -Seconds 1
                Show-LoginMenu
            }
        }
    }
    else {
        Write-Host "You are not logged in" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Login with Microsoft account"
        Write-Host "2. Login in offline mode"
        Write-Host "3. Return to main menu"

        $choice = Read-Host "Please select an option"

        switch ($choice) {
            "1" {
                Invoke-Authentication
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Write-Host ""
                Write-Host "=== Offline Login ===" -ForegroundColor Cyan
                Write-Host "Warning: Offline mode allows you to play without Microsoft authentication," -ForegroundColor Yellow
                Write-Host "but you won't be able to connect to online servers." -ForegroundColor Yellow
                Write-Host ""

                $username = Read-Host "Enter your username"

                if ([string]::IsNullOrWhiteSpace($username)) {
                    Write-Host "Username cannot be empty" -ForegroundColor Red
                } else {
                    Invoke-OfflineLogin -Username $username
                }

                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                return
            }
            default {
                Write-Host "Invalid choice, please try again" -ForegroundColor Red
                Start-Sleep -Seconds 1
                Show-LoginMenu
            }
        }
    }
}

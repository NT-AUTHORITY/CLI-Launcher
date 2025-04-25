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

    # Get accounts list
    $accounts = Get-AccountsList

    Write-Host "===== Account Management =====" -ForegroundColor Cyan

    if ($authStatus.IsAuthenticated) {
        if ($authStatus.IsOffline) {
            Write-Host "Currently logged in as: $($authStatus.Username) (Offline Mode)" -ForegroundColor Yellow
        } else {
            Write-Host "Currently logged in as: $($authStatus.Username)" -ForegroundColor Green
        }
        Write-Host ""
        Write-Host "1. Switch Account"
        Write-Host "2. Add Account"
        Write-Host "3. Delete Current Account"
        Write-Host "4. Return to main menu"

        $choice = Read-Host "Please select an option"

        switch ($choice) {
            "1" {
                Show-AccountSwitchMenu
            }
            "2" {
                Show-AddAccountMenu
            }
            "3" {
                Show-DeleteAccountConfirmation
            }
            "4" {
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

        if ($accounts.Count -gt 0) {
            Write-Host "1. Switch to existing account"
            Write-Host "2. Login with Microsoft account"
            Write-Host "3. Login in offline mode"
            Write-Host "4. Return to main menu"

            $choice = Read-Host "Please select an option"

            switch ($choice) {
                "1" {
                    Show-AccountSwitchMenu
                }
                "2" {
                    Invoke-Authentication
                    Write-Host "Press any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
                "3" {
                    Show-OfflineLoginMenu
                }
                "4" {
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
                    Show-OfflineLoginMenu
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
}

# Display account switch menu
function Show-AccountSwitchMenu {
    Clear-Host

    # Get accounts list
    $accounts = Get-AccountsList

    Write-Host "===== Switch Account =====" -ForegroundColor Cyan

    if ($accounts.Count -eq 0) {
        Write-Host "No accounts found. Please login first." -ForegroundColor Yellow
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # Sort accounts by last used date (most recent first)
    $sortedAccounts = $accounts | Sort-Object -Property { [DateTime]::Parse($_.LastUsed) } -Descending

    # Display accounts
    for ($i = 0; $i -lt $sortedAccounts.Count; $i++) {
        $account = $sortedAccounts[$i]
        $accountType = if ($account.IsOffline) { "(Offline)" } else { "(Microsoft)" }
        Write-Host "$($i+1). $($account.Username) $accountType" -ForegroundColor $(if ($account.IsOffline) { "Yellow" } else { "Green" })
    }

    Write-Host "$(($sortedAccounts.Count) + 1). Return to previous menu"

    $choice = Read-Host "Please select an account"

    if ([int]::TryParse($choice, [ref]$null)) {
        $index = [int]$choice - 1

        if ($index -ge 0 -and $index -lt $sortedAccounts.Count) {
            $selectedAccount = $sortedAccounts[$index]
            Switch-ToAccount -Account $selectedAccount
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
        elseif ($index -eq $sortedAccounts.Count) {
            return
        }
    }

    Write-Host "Invalid choice, please try again" -ForegroundColor Red
    Start-Sleep -Seconds 1
    Show-AccountSwitchMenu
}

# Display offline login menu
function Show-OfflineLoginMenu {
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

# Display add account menu
function Show-AddAccountMenu {
    Clear-Host
    Write-Host "===== Add New Account =====" -ForegroundColor Cyan
    Write-Host "1. Add Microsoft account"
    Write-Host "2. Add offline account"
    Write-Host "3. Return to previous menu"

    $choice = Read-Host "Please select an option"

    switch ($choice) {
        "1" {
            # First logout from current account
            Invoke-Logout -Silent

            # Then authenticate with Microsoft
            Invoke-Authentication
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "2" {
            # First logout from current account
            Invoke-Logout -Silent

            # Then show offline login menu
            Show-OfflineLoginMenu
        }
        "3" {
            return
        }
        default {
            Write-Host "Invalid choice, please try again" -ForegroundColor Red
            Start-Sleep -Seconds 1
            Show-AddAccountMenu
        }
    }
}

# Display delete account confirmation
function Show-DeleteAccountConfirmation {
    Clear-Host

    # Get current account info
    $authStatus = Get-AuthenticationStatus
    $username = $authStatus.Username
    $isOffline = $authStatus.IsOffline

    Write-Host "===== Delete Account =====" -ForegroundColor Cyan
    Write-Host "Are you sure you want to delete the account: $username?" -ForegroundColor Yellow
    if ($isOffline) {
        Write-Host "(This is an offline account)" -ForegroundColor Yellow
    } else {
        Write-Host "(This is a Microsoft account)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "1. Yes, delete this account"
    Write-Host "2. No, keep this account"

    $choice = Read-Host "Please select an option"

    switch ($choice) {
        "1" {
            # Delete the account from the list
            Remove-AccountFromList -Username $username -IsOffline:$isOffline

            # Logout
            Invoke-Logout

            Write-Host "Account deleted successfully" -ForegroundColor Green
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "2" {
            return
        }
        default {
            Write-Host "Invalid choice, please try again" -ForegroundColor Red
            Start-Sleep -Seconds 1
            Show-DeleteAccountConfirmation
        }
    }
}

# ModLoaderCommon.ps1
# Common functions for mod loader management

# Get installed mod loaders for a specific Minecraft version
function Get-InstalledModLoaders {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )

    $modLoadersFile = Join-Path -Path $configPath -ChildPath "modloaders.json"

    if (-not (Test-Path -Path $modLoadersFile)) {
        return @()
    }

    try {
        $content = Get-Content -Path $modLoadersFile -Raw
        if ([string]::IsNullOrWhiteSpace($content)) {
            return @()
        }

        $modLoaders = $content | ConvertFrom-Json

        # Filter out null entries and filter by Minecraft version
        $versionModLoaders = $modLoaders | Where-Object {
            $_ -ne $null -and $_.MinecraftVersion -eq $MinecraftVersion
        }

        Write-DebugLog -Message "Found $($versionModLoaders.Count) mod loaders for Minecraft $MinecraftVersion" -Source "ModLoaderCommon" -Level "Debug"

        if ($versionModLoaders -and $versionModLoaders.Count -gt 0) {
            # Debug output
            foreach ($loader in $versionModLoaders) {
                Write-DebugLog -Message "Found mod loader: $($loader.Type) $($loader.Version) (Profile: $($loader.ProfileName))" -Source "ModLoaderCommon" -Level "Debug"
            }
            return $versionModLoaders
        } else {
            Write-DebugLog -Message "No mod loaders found for Minecraft $MinecraftVersion" -Source "ModLoaderCommon" -Level "Debug"
            return @()
        }
    }
    catch {
        Write-DebugLog -Message "Error reading mod loaders list: $($_.Exception.Message)" -Source "ModLoaderCommon" -Level "Error"
        Write-Host "Error reading mod loaders list" -ForegroundColor Red
        return @()
    }
}

# Add mod loader to installed list
function Add-ModLoader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,

        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [string]$ProfileName = "",

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalData = @{}
    )

    $modLoadersFile = Join-Path -Path $configPath -ChildPath "modloaders.json"

    try {
        # Create default profile name if not provided
        if ([string]::IsNullOrWhiteSpace($ProfileName)) {
            $ProfileName = "$MinecraftVersion-$Type-$Version"
        }

        # Create mod loader entry
        $modLoaderEntry = @{
            MinecraftVersion = $MinecraftVersion
            Type = $Type
            Version = $Version
            ProfileName = $ProfileName
            InstallDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }

        # Add additional data if provided
        foreach ($key in $AdditionalData.Keys) {
            $modLoaderEntry[$key] = $AdditionalData[$key]
        }

        # Read existing mod loaders
        if (Test-Path -Path $modLoadersFile) {
            $content = Get-Content -Path $modLoadersFile -Raw
            if ([string]::IsNullOrWhiteSpace($content)) {
                $modLoaders = @()
            } else {
                $modLoaders = $content | ConvertFrom-Json

                # Ensure it's an array
                if ($modLoaders -isnot [Array]) {
                    $modLoaders = @($modLoaders)
                }
            }
        } else {
            $modLoaders = @()
        }

        # Check if this mod loader is already in the list
        $existingIndex = -1
        for ($i = 0; $i -lt $modLoaders.Count; $i++) {
            if ($modLoaders[$i].MinecraftVersion -eq $MinecraftVersion -and
                $modLoaders[$i].Type -eq $Type -and
                $modLoaders[$i].Version -eq $Version) {
                $existingIndex = $i
                break
            }
        }

        # Update or add the mod loader
        if ($existingIndex -ge 0) {
            $modLoaders[$existingIndex] = [PSCustomObject]$modLoaderEntry
        } else {
            $modLoaders += [PSCustomObject]$modLoaderEntry
        }

        # Save to file
        $json = ConvertTo-Json -InputObject $modLoaders -Depth 5
        Set-Content -Path $modLoadersFile -Value $json

        Write-DebugLog -Message "Added mod loader: $Type $Version for Minecraft $MinecraftVersion" -Source "ModLoaderCommon" -Level "Info"
        return $true
    }
    catch {
        Write-DebugLog -Message "Error adding mod loader to list: $($_.Exception.Message)" -Source "ModLoaderCommon" -Level "Error"
        Write-Host "Error adding mod loader to list" -ForegroundColor Red
        return $false
    }
}

# Remove mod loader from installed list
function Remove-ModLoader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,

        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $modLoadersFile = Join-Path -Path $configPath -ChildPath "modloaders.json"

    if (-not (Test-Path -Path $modLoadersFile)) {
        return $false
    }

    try {
        $content = Get-Content -Path $modLoadersFile -Raw
        if ([string]::IsNullOrWhiteSpace($content)) {
            return $false
        }

        $modLoaders = $content | ConvertFrom-Json

        # Ensure it's an array
        if ($modLoaders -isnot [Array]) {
            $modLoaders = @($modLoaders)
        }

        # Filter out the mod loader to remove
        $newModLoaders = $modLoaders | Where-Object {
            -not ($_.MinecraftVersion -eq $MinecraftVersion -and
                  $_.Type -eq $Type -and
                  $_.Version -eq $Version)
        }

        # Save to file
        $json = ConvertTo-Json -InputObject $newModLoaders -Depth 5
        Set-Content -Path $modLoadersFile -Value $json

        Write-DebugLog -Message "Removed mod loader: $Type $Version for Minecraft $MinecraftVersion" -Source "ModLoaderCommon" -Level "Info"
        return $true
    }
    catch {
        Write-DebugLog -Message "Error removing mod loader from list: $($_.Exception.Message)" -Source "ModLoaderCommon" -Level "Error"
        Write-Host "Error removing mod loader from list" -ForegroundColor Red
        return $false
    }
}

# Show mod loader menu
function Show-ModLoaderMenu {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )

    while ($true) {
        Clear-Host
        Write-Host "===== Mod Loader Management for Minecraft $MinecraftVersion =====" -ForegroundColor Green
        Write-Host "1. Install Fabric"
        Write-Host "2. Install Forge"
        Write-Host "3. Install NeoForge"
        Write-Host "4. Install OptiFine"
        Write-Host "5. View Installed Mod Loaders"
        Write-Host "6. Remove Mod Loader"
        Write-Host "7. Return to Version Menu"

        $choice = Read-Host "Please select an option"

        switch ($choice) {
            "1" {
                Show-FabricInstallMenu -MinecraftVersion $MinecraftVersion
            }
            "2" {
                Show-ForgeInstallMenu -MinecraftVersion $MinecraftVersion
            }
            "3" {
                Show-NeoForgeInstallMenu -MinecraftVersion $MinecraftVersion
            }
            "4" {
                Show-OptiFineInstallMenu -MinecraftVersion $MinecraftVersion
            }
            "5" {
                Show-InstalledModLoaders -MinecraftVersion $MinecraftVersion
            }
            "6" {
                Show-RemoveModLoaderMenu -MinecraftVersion $MinecraftVersion
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

# Show installed mod loaders
function Show-InstalledModLoaders {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )

    Clear-Host
    Write-Host "===== Installed Mod Loaders for Minecraft $MinecraftVersion =====" -ForegroundColor Green

    $modLoaders = Get-InstalledModLoaders -MinecraftVersion $MinecraftVersion

    if ($modLoaders.Count -eq 0) {
        Write-Host "No mod loaders installed for this version" -ForegroundColor Yellow
    } else {
        foreach ($modLoader in $modLoaders) {
            Write-Host "$($modLoader.Type) $($modLoader.Version) - Profile: $($modLoader.ProfileName)" -ForegroundColor Cyan
        }
    }

    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Show remove mod loader menu
function Show-RemoveModLoaderMenu {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )

    Clear-Host
    Write-Host "===== Remove Mod Loader for Minecraft $MinecraftVersion =====" -ForegroundColor Green

    $modLoaders = Get-InstalledModLoaders -MinecraftVersion $MinecraftVersion

    if ($modLoaders.Count -eq 0) {
        Write-Host "No mod loaders installed for this version" -ForegroundColor Yellow
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    for ($i = 0; $i -lt $modLoaders.Count; $i++) {
        Write-Host "$($i+1). $($modLoaders[$i].Type) $($modLoaders[$i].Version) - Profile: $($modLoaders[$i].ProfileName)" -ForegroundColor Cyan
    }

    Write-Host "0. Cancel" -ForegroundColor Yellow

    $choice = Read-Host "Select mod loader to remove"

    if ($choice -eq "0") {
        return
    }

    $index = [int]$choice - 1

    if ($index -ge 0 -and $index -lt $modLoaders.Count) {
        $modLoader = $modLoaders[$index]

        Write-Host "Are you sure you want to remove $($modLoader.Type) $($modLoader.Version)? (Y/N)" -ForegroundColor Yellow
        $confirm = Read-Host

        if ($confirm -eq "Y" -or $confirm -eq "y") {
            # Call the appropriate removal function based on mod loader type
            $removed = $false

            switch ($modLoader.Type) {
                "Fabric" {
                    $removed = Remove-FabricModLoader -MinecraftVersion $MinecraftVersion -Version $modLoader.Version
                }
                "Forge" {
                    $removed = Remove-ForgeModLoader -MinecraftVersion $MinecraftVersion -Version $modLoader.Version
                }
                "NeoForge" {
                    $removed = Remove-NeoForgeModLoader -MinecraftVersion $MinecraftVersion -Version $modLoader.Version
                }
                "OptiFine" {
                    $removed = Remove-OptiFineModLoader -MinecraftVersion $MinecraftVersion -Version $modLoader.Version
                }
            }

            if ($removed) {
                Write-Host "Mod loader removed successfully" -ForegroundColor Green
            } else {
                Write-Host "Failed to remove mod loader" -ForegroundColor Red
            }

            Start-Sleep -Seconds 2
        }
    } else {
        Write-Host "Invalid choice" -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}

# Launch game with mod loader
function Start-ModLoaderGame {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,

        [Parameter(Mandatory = $true)]
        [string]$ModLoaderType,

        [Parameter(Mandatory = $true)]
        [string]$ModLoaderVersion
    )

    Write-DebugLog -Message "Starting mod loader game launch for Minecraft $MinecraftVersion with $ModLoaderType $ModLoaderVersion" -Source "ModLoaderCommon" -Level "Info"

    $modLoaders = Get-InstalledModLoaders -MinecraftVersion $MinecraftVersion

    Write-DebugLog -Message "Found $($modLoaders.Count) mod loaders for Minecraft $MinecraftVersion" -Source "ModLoaderCommon" -Level "Debug"

    if ($modLoaders.Count -eq 0) {
        Write-DebugLog -Message "No mod loaders found for Minecraft $MinecraftVersion" -Source "ModLoaderCommon" -Level "Error"
        Write-Host "No mod loaders found for Minecraft $MinecraftVersion" -ForegroundColor Red
        return $false
    }

    $targetModLoader = $modLoaders | Where-Object {
        $_.Type -eq $ModLoaderType -and $_.Version -eq $ModLoaderVersion
    } | Select-Object -First 1

    if (-not $targetModLoader) {
        Write-DebugLog -Message "Mod loader not found: $ModLoaderType $ModLoaderVersion for Minecraft $MinecraftVersion" -Source "ModLoaderCommon" -Level "Error"
        Write-Host "Mod loader not found: $ModLoaderType $ModLoaderVersion for Minecraft $MinecraftVersion" -ForegroundColor Red

        # List available mod loaders for debugging
        Write-Host "Available mod loaders:" -ForegroundColor Yellow
        foreach ($loader in $modLoaders) {
            Write-Host "  - $($loader.Type) $($loader.Version)" -ForegroundColor Yellow
        }

        return $false
    }

    # Launch the game with the appropriate profile
    $profileName = $targetModLoader.ProfileName

    Write-Host "Launching Minecraft $MinecraftVersion with $ModLoaderType $ModLoaderVersion (profile: $profileName)..." -ForegroundColor Green

    # Check if the profile exists in the versions directory
    $versionDir = Join-Path -Path $versionsPath -ChildPath $profileName
    $versionJsonPath = Join-Path -Path $versionDir -ChildPath "$profileName.json"

    if (-not (Test-Path -Path $versionJsonPath)) {
        Write-DebugLog -Message "Mod loader profile JSON $profileName not found" -Source "ModLoaderCommon" -Level "Error"
        Write-Host "Error: Mod loader profile $profileName not found. Please reinstall the mod loader." -ForegroundColor Red
        return $false
    }

    # For Fabric mod loader, we don't need to check for the JAR file
    # because Fabric uses the base game JAR file
    if ($ModLoaderType -ne "Fabric") {
        $versionJarPath = Join-Path -Path $versionDir -ChildPath "$profileName.jar"
        if (-not (Test-Path -Path $versionJarPath)) {
            Write-DebugLog -Message "Mod loader profile JAR $profileName not found" -Source "ModLoaderCommon" -Level "Warning"
            Write-Host "Warning: Mod loader JAR file not found. Will try to launch anyway." -ForegroundColor Yellow
        }
    }

    # Launch the game with the profile name as the version
    Start-MinecraftGame -Version $profileName

    return $true
}

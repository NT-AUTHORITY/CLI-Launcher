# ForgeManager.ps1
# Module for managing Forge mod loader

# Get available Forge versions for a specific Minecraft version
function Get-ForgeVersions {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )

    try {
        Write-DebugLog -Message "Fetching Forge versions for Minecraft $MinecraftVersion" -Source "ForgeManager" -Level "Debug"

        # Use the Forge Maven repository to get versions
        $url = "https://files.minecraftforge.net/maven/net/minecraftforge/forge/maven-metadata.xml"
        $metadataXml = Get-WebContent -Url $url

        # Parse XML
        $metadata = [xml]$metadataXml
        $allVersions = $metadata.metadata.versioning.versions.version

        # Filter versions for the specified Minecraft version
        $forgeVersions = @()
        foreach ($version in $allVersions) {
            if ($version -match "^$MinecraftVersion-") {
                $forgeVersions += $version
            }
        }

        # Sort versions in descending order (newest first)
        $forgeVersions = $forgeVersions | Sort-Object -Descending

        Write-DebugLog -Message "Retrieved Forge versions: $($forgeVersions.Count) versions" -Source "ForgeManager" -Level "Debug"
        return $forgeVersions
    }
    catch {
        Write-DebugLog -Message "Error getting Forge versions: $($_.Exception.Message)" -Source "ForgeManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "ForgeManager" -CustomMessage "Error getting Forge versions" -Continue
        return @()
    }
}

# Install Forge for a specific Minecraft version
function Install-ForgeModLoader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,

        [Parameter(Mandatory = $true)]
        [string]$ForgeVersion
    )

    try {
        Write-DebugLog -Message "Installing Forge $ForgeVersion for Minecraft $MinecraftVersion" -Source "ForgeManager" -Level "Info"

        # First, ensure the base Minecraft version is installed
        $installedVersions = Get-InstalledVersions
        if ($installedVersions -notcontains $MinecraftVersion) {
            Write-Host "Installing base Minecraft $MinecraftVersion first..." -ForegroundColor Cyan
            Install-MinecraftVersion -Version $MinecraftVersion
        }

        # Create profile name
        $profileName = "forge-$MinecraftVersion-$ForgeVersion"
        $fullForgeVersion = "$MinecraftVersion-$ForgeVersion"

        # Create temporary directory for Forge installer
        $tempDir = Join-Path -Path $env:TEMP -ChildPath "ForgeInstaller"
        if (-not (Test-Path -Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }

        # Download Forge installer
        $installerUrl = "https://maven.minecraftforge.net/net/minecraftforge/forge/$fullForgeVersion/forge-$fullForgeVersion-installer.jar"
        $installerPath = Join-Path -Path $tempDir -ChildPath "forge-$fullForgeVersion-installer.jar"

        Write-Host "Downloading Forge installer..." -ForegroundColor Cyan
        Save-WebFile -Url $installerUrl -FilePath $installerPath

        # Create version directory
        $versionDir = Join-Path -Path $versionsPath -ChildPath $profileName
        if (-not (Test-Path -Path $versionDir)) {
            New-Item -Path $versionDir -ItemType Directory -Force | Out-Null
        }

        # Get Java path
        $javaPath = Get-JavaPath
        if (-not $javaPath) {
            Write-DebugLog -Message "Java not found" -Source "ForgeManager" -Level "Error"
            Write-Host "Cannot find Java. Please make sure Java is installed" -ForegroundColor Red
            return $false
        }

        # Run Forge installer in headless mode
        Write-Host "Running Forge installer..." -ForegroundColor Cyan

        # Create installer arguments
        $installerArgs = @(
            "-jar",
            $installerPath,
            "--installClient",
            $minecraftPath
        )

        # Start the installer process
        $process = Start-Process -FilePath $javaPath -ArgumentList $installerArgs -NoNewWindow -PassThru -Wait

        if ($process.ExitCode -ne 0) {
            Write-DebugLog -Message "Forge installer failed with exit code $($process.ExitCode)" -Source "ForgeManager" -Level "Error"
            Write-Host "Forge installation failed" -ForegroundColor Red
            return $false
        }

        # Check if the installation was successful
        $forgeJsonPath = Join-Path -Path $versionsPath -ChildPath "$MinecraftVersion-forge-$ForgeVersion" -AdditionalChildPath "$MinecraftVersion-forge-$ForgeVersion.json"

        if (-not (Test-Path -Path $forgeJsonPath)) {
            Write-DebugLog -Message "Forge JSON file not found after installation" -Source "ForgeManager" -Level "Error"
            Write-Host "Forge installation failed: JSON file not found" -ForegroundColor Red
            return $false
        }

        # Rename the version directory to match our naming convention
        $forgeVersionDir = Join-Path -Path $versionsPath -ChildPath "$MinecraftVersion-forge-$ForgeVersion"
        if (Test-Path -Path $forgeVersionDir) {
            # Copy files instead of renaming to avoid issues
            Copy-Item -Path "$forgeVersionDir\*" -Destination $versionDir -Recurse -Force

            # Rename the JSON file
            $originalJsonPath = Join-Path -Path $versionDir -ChildPath "$MinecraftVersion-forge-$ForgeVersion.json"
            $newJsonPath = Join-Path -Path $versionDir -ChildPath "$profileName.json"

            if (Test-Path -Path $originalJsonPath) {
                Move-Item -Path $originalJsonPath -Destination $newJsonPath -Force
            }
        }

        # Add to installed mod loaders list
        Add-ModLoader -MinecraftVersion $MinecraftVersion -Type "Forge" -Version $ForgeVersion -ProfileName $profileName

        Write-DebugLog -Message "Forge $ForgeVersion installation complete for Minecraft $MinecraftVersion" -Source "ForgeManager" -Level "Info"
        Write-Host "Forge $ForgeVersion installation complete for Minecraft $MinecraftVersion!" -ForegroundColor Green

        # Clean up
        if (Test-Path -Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }

        return $true
    }
    catch {
        Write-DebugLog -Message "Error installing Forge: $($_.Exception.Message)" -Source "ForgeManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "ForgeManager" -CustomMessage "Error installing Forge"
        return $false
    }
}

# Remove Forge mod loader
function Remove-ForgeModLoader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    try {
        Write-DebugLog -Message "Removing Forge $Version for Minecraft $MinecraftVersion" -Source "ForgeManager" -Level "Info"

        # Get the mod loader details
        $modLoaders = Get-InstalledModLoaders -MinecraftVersion $MinecraftVersion
        $forgeLoader = $modLoaders | Where-Object {
            $_.Type -eq "Forge" -and $_.Version -eq $Version
        } | Select-Object -First 1

        if (-not $forgeLoader) {
            Write-DebugLog -Message "Forge $Version not found for Minecraft $MinecraftVersion" -Source "ForgeManager" -Level "Warning"
            return $false
        }

        # Remove the version directory
        $profileName = $forgeLoader.ProfileName
        $versionDir = Join-Path -Path $versionsPath -ChildPath $profileName

        if (Test-Path -Path $versionDir) {
            Write-DebugLog -Message "Removing version directory: $versionDir" -Source "ForgeManager" -Level "Debug"
            Remove-Item -Path $versionDir -Recurse -Force
        }

        # Remove from installed mod loaders list
        Remove-ModLoader -MinecraftVersion $MinecraftVersion -Type "Forge" -Version $Version

        Write-DebugLog -Message "Forge $Version removed for Minecraft $MinecraftVersion" -Source "ForgeManager" -Level "Info"
        return $true
    }
    catch {
        Write-DebugLog -Message "Error removing Forge: $($_.Exception.Message)" -Source "ForgeManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "ForgeManager" -CustomMessage "Error removing Forge" -Continue
        return $false
    }
}

# Show Forge installation menu
function Show-ForgeInstallMenu {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )

    Clear-Host
    Write-Host "===== Install Forge for Minecraft $MinecraftVersion =====" -ForegroundColor Green

    # Get available Forge versions
    Write-Host "Fetching available Forge versions..." -ForegroundColor Cyan
    $forgeVersions = Get-ForgeVersions -MinecraftVersion $MinecraftVersion

    if ($forgeVersions.Count -eq 0) {
        Write-Host "No Forge versions found for Minecraft $MinecraftVersion" -ForegroundColor Yellow
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # Display latest 10 versions
    Write-Host "Available Forge Versions for Minecraft $MinecraftVersion" -ForegroundColor Cyan
    $displayVersions = $forgeVersions | Select-Object -First 10

    for ($i = 0; $i -lt $displayVersions.Count; $i++) {
        # Extract just the Forge version number (after the Minecraft version)
        $forgeVersionNumber = $displayVersions[$i] -replace "^$MinecraftVersion-", ""
        Write-Host "$($i+1). $forgeVersionNumber" -ForegroundColor White
    }

    Write-Host "0. Cancel" -ForegroundColor Yellow

    $choice = Read-Host "Select Forge version to install (or 0 to cancel)"

    if ($choice -eq "0") {
        return
    }

    $index = [int]$choice - 1

    if ($index -ge 0 -and $index -lt $displayVersions.Count) {
        # Extract just the Forge version number (after the Minecraft version)
        $fullForgeVersion = $displayVersions[$index]
        $forgeVersionNumber = $fullForgeVersion -replace "^$MinecraftVersion-", ""

        # Install Forge
        Write-Host "Installing Forge $forgeVersionNumber for Minecraft $MinecraftVersion..." -ForegroundColor Cyan
        $success = Install-ForgeModLoader -MinecraftVersion $MinecraftVersion -ForgeVersion $forgeVersionNumber

        if ($success) {
            Write-Host "Forge installation complete!" -ForegroundColor Green
        } else {
            Write-Host "Forge installation failed" -ForegroundColor Red
        }

        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } else {
        Write-Host "Invalid choice" -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}

# NeoForgeManager.ps1
# Module for managing NeoForge mod loader

# Get available NeoForge versions for a specific Minecraft version
function Get-NeoForgeVersions {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )

    try {
        Write-DebugLog -Message "Fetching NeoForge versions for Minecraft $MinecraftVersion" -Source "NeoForgeManager" -Level "Debug"

        # Use the NeoForge Maven repository to get versions
        $url = "https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml"
        $metadataXml = Get-WebContent -Url $url

        # Parse XML
        $metadata = [xml]$metadataXml
        $allVersions = $metadata.metadata.versioning.versions.version

        # Filter versions for the specified Minecraft version
        $neoforgeVersions = @()
        foreach ($version in $allVersions) {
            if ($version -match "^$MinecraftVersion-") {
                $neoforgeVersions += $version
            }
        }

        # Sort versions in descending order (newest first)
        $neoforgeVersions = $neoforgeVersions | Sort-Object -Descending

        Write-DebugLog -Message "Retrieved NeoForge versions: $($neoforgeVersions.Count) versions" -Source "NeoForgeManager" -Level "Debug"
        return $neoforgeVersions
    }
    catch {
        Write-DebugLog -Message "Error getting NeoForge versions: $($_.Exception.Message)" -Source "NeoForgeManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "NeoForgeManager" -CustomMessage "Error getting NeoForge versions" -Continue
        return @()
    }
}

# Install NeoForge for a specific Minecraft version
function Install-NeoForgeModLoader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,

        [Parameter(Mandatory = $true)]
        [string]$NeoForgeVersion
    )

    try {
        Write-DebugLog -Message "Installing NeoForge $NeoForgeVersion for Minecraft $MinecraftVersion" -Source "NeoForgeManager" -Level "Info"

        # First, ensure the base Minecraft version is installed
        $installedVersions = Get-InstalledVersions
        if ($installedVersions -notcontains $MinecraftVersion) {
            Write-Host "Installing base Minecraft $MinecraftVersion first..." -ForegroundColor Cyan
            Install-MinecraftVersion -Version $MinecraftVersion
        }

        # Create profile name
        $profileName = "neoforge-$MinecraftVersion-$NeoForgeVersion"
        $fullNeoForgeVersion = "$MinecraftVersion-$NeoForgeVersion"

        # Create temporary directory for NeoForge installer
        $tempDir = Join-Path -Path $env:TEMP -ChildPath "NeoForgeInstaller"
        if (-not (Test-Path -Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }

        # Download NeoForge installer
        $installerUrl = "https://maven.neoforged.net/releases/net/neoforged/neoforge/$fullNeoForgeVersion/neoforge-$fullNeoForgeVersion-installer.jar"
        $installerPath = Join-Path -Path $tempDir -ChildPath "neoforge-$fullNeoForgeVersion-installer.jar"

        Write-Host "Downloading NeoForge installer..." -ForegroundColor Cyan
        Save-WebFile -Url $installerUrl -FilePath $installerPath

        # Create version directory
        $versionDir = Join-Path -Path $versionsPath -ChildPath $profileName
        if (-not (Test-Path -Path $versionDir)) {
            New-Item -Path $versionDir -ItemType Directory -Force | Out-Null
        }

        # Get Java path
        $javaPath = Get-JavaPath
        if (-not $javaPath) {
            Write-DebugLog -Message "Java not found" -Source "NeoForgeManager" -Level "Error"
            Write-Host "Cannot find Java. Please make sure Java is installed" -ForegroundColor Red
            return $false
        }

        # Run NeoForge installer in headless mode
        Write-Host "Running NeoForge installer..." -ForegroundColor Cyan

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
            Write-DebugLog -Message "NeoForge installer failed with exit code $($process.ExitCode)" -Source "NeoForgeManager" -Level "Error"
            Write-Host "NeoForge installation failed" -ForegroundColor Red
            return $false
        }

        # Check if the installation was successful
        $neoforgeJsonPath = Join-Path -Path $versionsPath -ChildPath "$MinecraftVersion-neoforge-$NeoForgeVersion" -AdditionalChildPath "$MinecraftVersion-neoforge-$NeoForgeVersion.json"

        if (-not (Test-Path -Path $neoforgeJsonPath)) {
            Write-DebugLog -Message "NeoForge JSON file not found after installation" -Source "NeoForgeManager" -Level "Error"
            Write-Host "NeoForge installation failed: JSON file not found" -ForegroundColor Red
            return $false
        }

        # Rename the version directory to match our naming convention
        $neoforgeVersionDir = Join-Path -Path $versionsPath -ChildPath "$MinecraftVersion-neoforge-$NeoForgeVersion"
        if (Test-Path -Path $neoforgeVersionDir) {
            # Copy files instead of renaming to avoid issues
            Copy-Item -Path "$neoforgeVersionDir\*" -Destination $versionDir -Recurse -Force

            # Rename the JSON file
            $originalJsonPath = Join-Path -Path $versionDir -ChildPath "$MinecraftVersion-neoforge-$NeoForgeVersion.json"
            $newJsonPath = Join-Path -Path $versionDir -ChildPath "$profileName.json"

            if (Test-Path -Path $originalJsonPath) {
                Move-Item -Path $originalJsonPath -Destination $newJsonPath -Force
            }
        }

        # Add to installed mod loaders list
        Add-ModLoader -MinecraftVersion $MinecraftVersion -Type "NeoForge" -Version $NeoForgeVersion -ProfileName $profileName

        Write-DebugLog -Message "NeoForge $NeoForgeVersion installation complete for Minecraft $MinecraftVersion" -Source "NeoForgeManager" -Level "Info"
        Write-Host "NeoForge $NeoForgeVersion installation complete for Minecraft $MinecraftVersion!" -ForegroundColor Green

        # Clean up
        if (Test-Path -Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }

        return $true
    }
    catch {
        Write-DebugLog -Message "Error installing NeoForge: $($_.Exception.Message)" -Source "NeoForgeManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "NeoForgeManager" -CustomMessage "Error installing NeoForge"
        return $false
    }
}

# Remove NeoForge mod loader
function Remove-NeoForgeModLoader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    try {
        Write-DebugLog -Message "Removing NeoForge $Version for Minecraft $MinecraftVersion" -Source "NeoForgeManager" -Level "Info"

        # Get the mod loader details
        $modLoaders = Get-InstalledModLoaders -MinecraftVersion $MinecraftVersion
        $neoforgeLoader = $modLoaders | Where-Object {
            $_.Type -eq "NeoForge" -and $_.Version -eq $Version
        } | Select-Object -First 1

        if (-not $neoforgeLoader) {
            Write-DebugLog -Message "NeoForge $Version not found for Minecraft $MinecraftVersion" -Source "NeoForgeManager" -Level "Warning"
            return $false
        }

        # Remove the version directory
        $profileName = $neoforgeLoader.ProfileName
        $versionDir = Join-Path -Path $versionsPath -ChildPath $profileName

        if (Test-Path -Path $versionDir) {
            Write-DebugLog -Message "Removing version directory: $versionDir" -Source "NeoForgeManager" -Level "Debug"
            Remove-Item -Path $versionDir -Recurse -Force
        }

        # Remove from installed mod loaders list
        Remove-ModLoader -MinecraftVersion $MinecraftVersion -Type "NeoForge" -Version $Version

        Write-DebugLog -Message "NeoForge $Version removed for Minecraft $MinecraftVersion" -Source "NeoForgeManager" -Level "Info"
        return $true
    }
    catch {
        Write-DebugLog -Message "Error removing NeoForge: $($_.Exception.Message)" -Source "NeoForgeManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "NeoForgeManager" -CustomMessage "Error removing NeoForge" -Continue
        return $false
    }
}

# Show NeoForge installation menu
function Show-NeoForgeInstallMenu {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )

    Clear-Host
    Write-Host "===== Install NeoForge for Minecraft $MinecraftVersion =====" -ForegroundColor Green

    # Get available NeoForge versions
    Write-Host "Fetching available NeoForge versions..." -ForegroundColor Cyan
    $neoforgeVersions = Get-NeoForgeVersions -MinecraftVersion $MinecraftVersion

    if ($neoforgeVersions.Count -eq 0) {
        Write-Host "No NeoForge versions found for Minecraft $MinecraftVersion" -ForegroundColor Yellow
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # Display latest 10 versions
    Write-Host "Available NeoForge Versions for Minecraft $MinecraftVersion" -ForegroundColor Cyan
    $displayVersions = $neoforgeVersions | Select-Object -First 10

    for ($i = 0; $i -lt $displayVersions.Count; $i++) {
        # Extract just the NeoForge version number (after the Minecraft version)
        $neoforgeVersionNumber = $displayVersions[$i] -replace "^$MinecraftVersion-", ""
        Write-Host "$($i+1). $neoforgeVersionNumber" -ForegroundColor White
    }

    Write-Host "0. Cancel" -ForegroundColor Yellow

    $choice = Read-Host "Select NeoForge version to install (or 0 to cancel)"

    if ($choice -eq "0") {
        return
    }

    $index = [int]$choice - 1

    if ($index -ge 0 -and $index -lt $displayVersions.Count) {
        # Extract just the NeoForge version number (after the Minecraft version)
        $fullNeoForgeVersion = $displayVersions[$index]
        $neoforgeVersionNumber = $fullNeoForgeVersion -replace "^$MinecraftVersion-", ""

        # Install NeoForge
        Write-Host "Installing NeoForge $neoforgeVersionNumber for Minecraft $MinecraftVersion..." -ForegroundColor Cyan
        $success = Install-NeoForgeModLoader -MinecraftVersion $MinecraftVersion -NeoForgeVersion $neoforgeVersionNumber

        if ($success) {
            Write-Host "NeoForge installation complete!" -ForegroundColor Green
        } else {
            Write-Host "NeoForge installation failed" -ForegroundColor Red
        }

        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } else {
        Write-Host "Invalid choice" -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}

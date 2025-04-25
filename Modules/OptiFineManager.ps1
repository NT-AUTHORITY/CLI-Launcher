# OptiFineManager.ps1
# Module for managing OptiFine installation

# Get available OptiFine versions for a specific Minecraft version
function Get-OptiFineVersions {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )

    try {
        Write-DebugLog -Message "Fetching OptiFine versions for Minecraft $MinecraftVersion" -Source "OptiFineManager" -Level "Debug"

        # Use the OptiFine download page to get versions
        $url = "https://optifine.net/downloads"
        $html = Get-WebContent -Url $url

        # Parse HTML to extract versions
        $optifineVersions = @()

        # Extract version links using regex
        $pattern = "downloadx\?f=OptiFine_$MinecraftVersion[^'`"]*\.jar"
        $matches = [regex]::Matches($html, $pattern)

        foreach ($match in $matches) {
            $fileName = $match.Value -replace "downloadx\?f=", ""

            # Extract version from filename
            if ($fileName -match "OptiFine_$MinecraftVersion(_([A-Za-z0-9_]+))\.jar") {
                $version = $matches[2].Value
                $optifineVersions += @{
                    "Version" = $version
                    "FileName" = $fileName
                    "DownloadUrl" = "https://optifine.net/$($match.Value)"
                }
            }
        }

        Write-DebugLog -Message "Retrieved OptiFine versions: $($optifineVersions.Count) versions" -Source "OptiFineManager" -Level "Debug"
        return $optifineVersions
    }
    catch {
        Write-DebugLog -Message "Error getting OptiFine versions: $($_.Exception.Message)" -Source "OptiFineManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "OptiFineManager" -CustomMessage "Error getting OptiFine versions" -Continue
        return @()
    }
}

# Install OptiFine for a specific Minecraft version
function Install-OptiFineModLoader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,

        [Parameter(Mandatory = $true)]
        [string]$OptiFineVersion,

        [Parameter(Mandatory = $true)]
        [string]$DownloadUrl
    )

    try {
        Write-DebugLog -Message "Installing OptiFine $OptiFineVersion for Minecraft $MinecraftVersion" -Source "OptiFineManager" -Level "Info"

        # First, ensure the base Minecraft version is installed
        $installedVersions = Get-InstalledVersions
        if ($installedVersions -notcontains $MinecraftVersion) {
            Write-Host "Installing base Minecraft $MinecraftVersion first..." -ForegroundColor Cyan
            Install-MinecraftVersion -Version $MinecraftVersion
        }

        # Create profile name
        $profileName = "optifine-$MinecraftVersion-$OptiFineVersion"

        # Create temporary directory for OptiFine installer
        $tempDir = Join-Path -Path $env:TEMP -ChildPath "OptiFineInstaller"
        if (-not (Test-Path -Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }

        # Download OptiFine installer
        $installerPath = Join-Path -Path $tempDir -ChildPath "OptiFine_$MinecraftVersion`_$OptiFineVersion.jar"

        Write-Host "Downloading OptiFine installer..." -ForegroundColor Cyan
        Save-WebFile -Url $DownloadUrl -FilePath $installerPath

        # Create version directory
        $versionDir = Join-Path -Path $versionsPath -ChildPath $profileName
        if (-not (Test-Path -Path $versionDir)) {
            New-Item -Path $versionDir -ItemType Directory -Force | Out-Null
        }

        # Get Java path
        $javaPath = Get-JavaPath
        if (-not $javaPath) {
            Write-DebugLog -Message "Java not found" -Source "OptiFineManager" -Level "Error"
            Write-Host "Cannot find Java. Please make sure Java is installed" -ForegroundColor Red
            return $false
        }

        # Extract OptiFine installer
        Write-Host "Extracting OptiFine installer..." -ForegroundColor Cyan

        # Create a temporary directory for extraction
        $extractDir = Join-Path -Path $tempDir -ChildPath "extract"
        if (-not (Test-Path -Path $extractDir)) {
            New-Item -Path $extractDir -ItemType Directory -Force | Out-Null
        }

        # Extract the JAR file
        $extractArgs = @(
            "-jar",
            $installerPath,
            "extract",
            $extractDir
        )

        $process = Start-Process -FilePath $javaPath -ArgumentList $extractArgs -NoNewWindow -PassThru -Wait

        if ($process.ExitCode -ne 0) {
            Write-DebugLog -Message "OptiFine extraction failed with exit code $($process.ExitCode)" -Source "OptiFineManager" -Level "Error"
            Write-Host "OptiFine extraction failed" -ForegroundColor Red
            return $false
        }

        # Find the extracted OptiFine JAR
        $optifineJar = Get-ChildItem -Path $extractDir -Filter "*.jar" | Where-Object { $_.Name -match "OptiFine" } | Select-Object -First 1

        if (-not $optifineJar) {
            Write-DebugLog -Message "OptiFine JAR not found after extraction" -Source "OptiFineManager" -Level "Error"
            Write-Host "OptiFine installation failed: JAR file not found" -ForegroundColor Red
            return $false
        }

        # Copy the OptiFine JAR to the version directory
        $optifineJarPath = Join-Path -Path $versionDir -ChildPath "$profileName.jar"
        Copy-Item -Path $optifineJar.FullName -Destination $optifineJarPath -Force

        # Create the JSON file
        $baseVersionJsonPath = Join-Path -Path $versionsPath -ChildPath $MinecraftVersion -AdditionalChildPath "$MinecraftVersion.json"
        $optifineJsonPath = Join-Path -Path $versionDir -ChildPath "$profileName.json"

        if (Test-Path -Path $baseVersionJsonPath) {
            $baseVersionJson = Get-Content -Path $baseVersionJsonPath -Raw | ConvertFrom-Json

            # Modify the JSON for OptiFine
            $baseVersionJson.id = $profileName
            $baseVersionJson.mainClass = "net.minecraft.launchwrapper.Launch"

            # Add OptiFine as a library
            $optifineLibrary = @{
                "name" = "optifine:OptiFine:$MinecraftVersion`_$OptiFineVersion"
                "downloads" = @{
                    "artifact" = @{
                        "path" = "optifine/OptiFine/$MinecraftVersion`_$OptiFineVersion/OptiFine-$MinecraftVersion`_$OptiFineVersion.jar"
                        "url" = ""
                        "size" = (Get-Item -Path $optifineJarPath).Length
                    }
                }
            }

            # Add LaunchWrapper library if not present
            $launchWrapperLibrary = @{
                "name" = "net.minecraft:launchwrapper:1.12"
                "downloads" = @{
                    "artifact" = @{
                        "path" = "net/minecraft/launchwrapper/1.12/launchwrapper-1.12.jar"
                        "url" = "https://libraries.minecraft.net/net/minecraft/launchwrapper/1.12/launchwrapper-1.12.jar"
                        "size" = 32921
                    }
                }
            }

            # Add libraries
            if (-not $baseVersionJson.libraries) {
                $baseVersionJson.libraries = @()
            }

            $baseVersionJson.libraries = @($launchWrapperLibrary) + $baseVersionJson.libraries + @($optifineLibrary)

            # Add OptiFine tweaker
            if ($baseVersionJson.arguments -and $baseVersionJson.arguments.game) {
                # Modern format (1.13+)
                $baseVersionJson.arguments.game += "--tweakClass"
                $baseVersionJson.arguments.game += "optifine.OptiFineTweaker"
            } else {
                # Legacy format
                if (-not $baseVersionJson.minecraftArguments) {
                    $baseVersionJson.minecraftArguments = ""
                }
                $baseVersionJson.minecraftArguments += " --tweakClass optifine.OptiFineTweaker"
            }

            # Save the modified JSON
            $baseVersionJson | ConvertTo-Json -Depth 100 | Set-Content -Path $optifineJsonPath
        } else {
            Write-DebugLog -Message "Base version JSON not found: $baseVersionJsonPath" -Source "OptiFineManager" -Level "Error"
            Write-Host "OptiFine installation failed: Base version JSON not found" -ForegroundColor Red
            return $false
        }

        # Add to installed mod loaders list
        Add-ModLoader -MinecraftVersion $MinecraftVersion -Type "OptiFine" -Version $OptiFineVersion -ProfileName $profileName

        Write-DebugLog -Message "OptiFine $OptiFineVersion installation complete for Minecraft $MinecraftVersion" -Source "OptiFineManager" -Level "Info"
        Write-Host "OptiFine $OptiFineVersion installation complete for Minecraft $MinecraftVersion!" -ForegroundColor Green

        # Clean up
        if (Test-Path -Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }

        return $true
    }
    catch {
        Write-DebugLog -Message "Error installing OptiFine: $($_.Exception.Message)" -Source "OptiFineManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "OptiFineManager" -CustomMessage "Error installing OptiFine"
        return $false
    }
}

# Remove OptiFine mod loader
function Remove-OptiFineModLoader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    try {
        Write-DebugLog -Message "Removing OptiFine $Version for Minecraft $MinecraftVersion" -Source "OptiFineManager" -Level "Info"

        # Get the mod loader details
        $modLoaders = Get-InstalledModLoaders -MinecraftVersion $MinecraftVersion
        $optifineLoader = $modLoaders | Where-Object {
            $_.Type -eq "OptiFine" -and $_.Version -eq $Version
        } | Select-Object -First 1

        if (-not $optifineLoader) {
            Write-DebugLog -Message "OptiFine $Version not found for Minecraft $MinecraftVersion" -Source "OptiFineManager" -Level "Warning"
            return $false
        }

        # Remove the version directory
        $profileName = $optifineLoader.ProfileName
        $versionDir = Join-Path -Path $versionsPath -ChildPath $profileName

        if (Test-Path -Path $versionDir) {
            Write-DebugLog -Message "Removing version directory: $versionDir" -Source "OptiFineManager" -Level "Debug"
            Remove-Item -Path $versionDir -Recurse -Force
        }

        # Remove from installed mod loaders list
        Remove-ModLoader -MinecraftVersion $MinecraftVersion -Type "OptiFine" -Version $Version

        Write-DebugLog -Message "OptiFine $Version removed for Minecraft $MinecraftVersion" -Source "OptiFineManager" -Level "Info"
        return $true
    }
    catch {
        Write-DebugLog -Message "Error removing OptiFine: $($_.Exception.Message)" -Source "OptiFineManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "OptiFineManager" -CustomMessage "Error removing OptiFine" -Continue
        return $false
    }
}

# Show OptiFine installation menu
function Show-OptiFineInstallMenu {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )

    Clear-Host
    Write-Host "===== Install OptiFine for Minecraft $MinecraftVersion =====" -ForegroundColor Green

    # Get available OptiFine versions
    Write-Host "Fetching available OptiFine versions..." -ForegroundColor Cyan
    $optifineVersions = Get-OptiFineVersions -MinecraftVersion $MinecraftVersion

    if ($optifineVersions.Count -eq 0) {
        Write-Host "No OptiFine versions found for Minecraft $MinecraftVersion" -ForegroundColor Yellow
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # Display all versions
    Write-Host "Available OptiFine Versions for Minecraft $MinecraftVersion" -ForegroundColor Cyan

    for ($i = 0; $i -lt $optifineVersions.Count; $i++) {
        Write-Host "$($i+1). $($optifineVersions[$i].Version)" -ForegroundColor White
    }

    Write-Host "0. Cancel" -ForegroundColor Yellow

    $choice = Read-Host "Select OptiFine version to install (or 0 to cancel)"

    if ($choice -eq "0") {
        return
    }

    $index = [int]$choice - 1

    if ($index -ge 0 -and $index -lt $optifineVersions.Count) {
        $selectedVersion = $optifineVersions[$index].Version
        $downloadUrl = $optifineVersions[$index].DownloadUrl

        # Install OptiFine
        Write-Host "Installing OptiFine $selectedVersion for Minecraft $MinecraftVersion..." -ForegroundColor Cyan
        $success = Install-OptiFineModLoader -MinecraftVersion $MinecraftVersion -OptiFineVersion $selectedVersion -DownloadUrl $downloadUrl

        if ($success) {
            Write-Host "OptiFine installation complete!" -ForegroundColor Green
        } else {
            Write-Host "OptiFine installation failed" -ForegroundColor Red
        }

        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } else {
        Write-Host "Invalid choice" -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}

# FabricManager.ps1
# Module for managing Fabric mod loader

# Get available Fabric loader versions
function Get-FabricLoaderVersions {
    try {
        Write-DebugLog -Message "Fetching Fabric loader versions" -Source "FabricManager" -Level "Debug"
        $url = "https://meta.fabricmc.net/v2/versions/loader"
        $versionsJson = Get-WebContent -Url $url
        $versions = $versionsJson | ConvertFrom-Json
        
        Write-DebugLog -Message "Retrieved Fabric loader versions: $($versions.Count) versions" -Source "FabricManager" -Level "Debug"
        return $versions
    }
    catch {
        Write-DebugLog -Message "Error getting Fabric loader versions: $($_.Exception.Message)" -Source "FabricManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "FabricManager" -CustomMessage "Error getting Fabric loader versions" -Continue
        return @()
    }
}

# Get available Fabric API versions for a specific Minecraft version
function Get-FabricAPIVersions {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )
    
    try {
        Write-DebugLog -Message "Fetching Fabric API versions for Minecraft $MinecraftVersion" -Source "FabricManager" -Level "Debug"
        
        # Use Modrinth API to get Fabric API versions
        $url = "https://api.modrinth.com/v2/project/fabric-api/version?game_versions=[%22$MinecraftVersion%22]"
        $versionsJson = Get-WebContent -Url $url
        $versions = $versionsJson | ConvertFrom-Json
        
        Write-DebugLog -Message "Retrieved Fabric API versions: $($versions.Count) versions" -Source "FabricManager" -Level "Debug"
        return $versions
    }
    catch {
        Write-DebugLog -Message "Error getting Fabric API versions: $($_.Exception.Message)" -Source "FabricManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "FabricManager" -CustomMessage "Error getting Fabric API versions" -Continue
        return @()
    }
}

# Install Fabric loader for a specific Minecraft version
function Install-FabricLoader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$LoaderVersion,
        
        [Parameter(Mandatory = $false)]
        [string]$APIVersion = ""
    )
    
    try {
        Write-DebugLog -Message "Installing Fabric loader $LoaderVersion for Minecraft $MinecraftVersion" -Source "FabricManager" -Level "Info"
        
        # First, ensure the base Minecraft version is installed
        $installedVersions = Get-InstalledVersions
        if ($installedVersions -notcontains $MinecraftVersion) {
            Write-Host "Installing base Minecraft $MinecraftVersion first..." -ForegroundColor Cyan
            Install-MinecraftVersion -Version $MinecraftVersion
        }
        
        # Create profile name
        $profileName = "fabric-loader-$LoaderVersion-$MinecraftVersion"
        
        # Create version directory
        $versionDir = Join-Path -Path $versionsPath -ChildPath $profileName
        if (-not (Test-Path -Path $versionDir)) {
            Write-DebugLog -Message "Creating version directory: $versionDir" -Source "FabricManager" -Level "Debug"
            New-Item -Path $versionDir -ItemType Directory | Out-Null
        }
        
        # Download Fabric JSON
        $fabricJsonUrl = "https://meta.fabricmc.net/v2/versions/loader/$MinecraftVersion/$LoaderVersion/profile/json"
        $fabricJsonPath = Join-Path -Path $versionDir -ChildPath "$profileName.json"
        Write-DebugLog -Message "Downloading Fabric JSON from $fabricJsonUrl" -Source "FabricManager" -Level "Debug"
        $fabricJson = Get-WebContent -Url $fabricJsonUrl
        $fabricJsonObj = $fabricJson | ConvertFrom-Json
        
        # Save Fabric JSON
        $fabricJson | Set-Content -Path $fabricJsonPath
        Write-DebugLog -Message "Saved Fabric JSON to $fabricJsonPath" -Source "FabricManager" -Level "Debug"
        
        # Download libraries
        Write-Host "Downloading Fabric libraries..." -ForegroundColor Cyan
        foreach ($library in $fabricJsonObj.libraries) {
            if ($library.downloads.artifact) {
                $libraryPath = $library.downloads.artifact.path -replace '/', '\'
                $libraryUrl = $library.downloads.artifact.url
                $libraryFilePath = Join-Path -Path $librariesPath -ChildPath $libraryPath
                $libraryDir = Split-Path -Path $libraryFilePath -Parent
                
                if (-not (Test-Path -Path $libraryDir)) {
                    New-Item -Path $libraryDir -ItemType Directory -Force | Out-Null
                }
                
                if (-not (Test-Path -Path $libraryFilePath)) {
                    Write-DebugLog -Message "Downloading library: $libraryUrl" -Source "FabricManager" -Level "Debug"
                    Save-WebFile -Url $libraryUrl -FilePath $libraryFilePath
                }
            }
        }
        
        # Install Fabric API if specified
        if (-not [string]::IsNullOrWhiteSpace($APIVersion)) {
            Write-Host "Installing Fabric API $APIVersion..." -ForegroundColor Cyan
            
            # Get API version details
            $apiVersions = Get-FabricAPIVersions -MinecraftVersion $MinecraftVersion
            $apiVersion = $apiVersions | Where-Object { $_.version_number -eq $APIVersion } | Select-Object -First 1
            
            if ($apiVersion) {
                # Create mods directory if it doesn't exist
                $modsDir = Join-Path -Path $minecraftPath -ChildPath "mods"
                if (-not (Test-Path -Path $modsDir)) {
                    New-Item -Path $modsDir -ItemType Directory -Force | Out-Null
                }
                
                # Download Fabric API jar
                $apiFile = $apiVersion.files | Where-Object { $_.primary -eq $true } | Select-Object -First 1
                if ($apiFile) {
                    $apiFilePath = Join-Path -Path $modsDir -ChildPath $apiFile.filename
                    Write-DebugLog -Message "Downloading Fabric API from $($apiFile.url)" -Source "FabricManager" -Level "Debug"
                    Save-WebFile -Url $apiFile.url -FilePath $apiFilePath
                    Write-DebugLog -Message "Saved Fabric API to $apiFilePath" -Source "FabricManager" -Level "Debug"
                }
            }
        }
        
        # Add to installed mod loaders list
        $additionalData = @{
            "APIVersion" = $APIVersion
        }
        
        Add-ModLoader -MinecraftVersion $MinecraftVersion -Type "Fabric" -Version $LoaderVersion -ProfileName $profileName -AdditionalData $additionalData
        
        Write-DebugLog -Message "Fabric loader $LoaderVersion installation complete for Minecraft $MinecraftVersion" -Source "FabricManager" -Level "Info"
        Write-Host "Fabric loader $LoaderVersion installation complete for Minecraft $MinecraftVersion!" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-DebugLog -Message "Error installing Fabric loader: $($_.Exception.Message)" -Source "FabricManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "FabricManager" -CustomMessage "Error installing Fabric loader"
        return $false
    }
}

# Remove Fabric mod loader
function Remove-FabricModLoader {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    
    try {
        Write-DebugLog -Message "Removing Fabric loader $Version for Minecraft $MinecraftVersion" -Source "FabricManager" -Level "Info"
        
        # Get the mod loader details
        $modLoaders = Get-InstalledModLoaders -MinecraftVersion $MinecraftVersion
        $fabricLoader = $modLoaders | Where-Object { 
            $_.Type -eq "Fabric" -and $_.Version -eq $Version 
        } | Select-Object -First 1
        
        if (-not $fabricLoader) {
            Write-DebugLog -Message "Fabric loader $Version not found for Minecraft $MinecraftVersion" -Source "FabricManager" -Level "Warning"
            return $false
        }
        
        # Remove the version directory
        $profileName = $fabricLoader.ProfileName
        $versionDir = Join-Path -Path $versionsPath -ChildPath $profileName
        
        if (Test-Path -Path $versionDir) {
            Write-DebugLog -Message "Removing version directory: $versionDir" -Source "FabricManager" -Level "Debug"
            Remove-Item -Path $versionDir -Recurse -Force
        }
        
        # Remove from installed mod loaders list
        Remove-ModLoader -MinecraftVersion $MinecraftVersion -Type "Fabric" -Version $Version
        
        Write-DebugLog -Message "Fabric loader $Version removed for Minecraft $MinecraftVersion" -Source "FabricManager" -Level "Info"
        return $true
    }
    catch {
        Write-DebugLog -Message "Error removing Fabric loader: $($_.Exception.Message)" -Source "FabricManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "FabricManager" -CustomMessage "Error removing Fabric loader" -Continue
        return $false
    }
}

# Show Fabric installation menu
function Show-FabricInstallMenu {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MinecraftVersion
    )
    
    Clear-Host
    Write-Host "===== Install Fabric for Minecraft $MinecraftVersion =====" -ForegroundColor Green
    
    # Get available Fabric loader versions
    Write-Host "Fetching available Fabric loader versions..." -ForegroundColor Cyan
    $loaderVersions = Get-FabricLoaderVersions
    
    if ($loaderVersions.Count -eq 0) {
        Write-Host "Failed to retrieve Fabric loader versions" -ForegroundColor Red
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    # Display latest 10 versions
    Write-Host "Available Fabric Loader Versions:" -ForegroundColor Cyan
    $displayVersions = $loaderVersions | Select-Object -First 10
    
    for ($i = 0; $i -lt $displayVersions.Count; $i++) {
        Write-Host "$($i+1). $($displayVersions[$i].version)" -ForegroundColor White
    }
    
    Write-Host "0. Cancel" -ForegroundColor Yellow
    
    $choice = Read-Host "Select Fabric loader version to install (or 0 to cancel)"
    
    if ($choice -eq "0") {
        return
    }
    
    $index = [int]$choice - 1
    
    if ($index -ge 0 -and $index -lt $displayVersions.Count) {
        $selectedVersion = $displayVersions[$index].version
        
        # Ask if user wants to install Fabric API
        Write-Host "Do you want to install Fabric API? (Y/N)" -ForegroundColor Yellow
        $installAPI = Read-Host
        
        $apiVersion = ""
        
        if ($installAPI -eq "Y" -or $installAPI -eq "y") {
            # Get available Fabric API versions
            Write-Host "Fetching available Fabric API versions..." -ForegroundColor Cyan
            $apiVersions = Get-FabricAPIVersions -MinecraftVersion $MinecraftVersion
            
            if ($apiVersions.Count -eq 0) {
                Write-Host "No Fabric API versions found for Minecraft $MinecraftVersion" -ForegroundColor Yellow
            } else {
                # Display latest 5 API versions
                Write-Host "Available Fabric API Versions:" -ForegroundColor Cyan
                $displayAPIVersions = $apiVersions | Select-Object -First 5
                
                for ($i = 0; $i -lt $displayAPIVersions.Count; $i++) {
                    Write-Host "$($i+1). $($displayAPIVersions[$i].version_number)" -ForegroundColor White
                }
                
                Write-Host "0. Skip Fabric API installation" -ForegroundColor Yellow
                
                $apiChoice = Read-Host "Select Fabric API version to install (or 0 to skip)"
                
                if ($apiChoice -ne "0") {
                    $apiIndex = [int]$apiChoice - 1
                    
                    if ($apiIndex -ge 0 -and $apiIndex -lt $displayAPIVersions.Count) {
                        $apiVersion = $displayAPIVersions[$apiIndex].version_number
                    }
                }
            }
        }
        
        # Install Fabric loader
        Write-Host "Installing Fabric loader $selectedVersion for Minecraft $MinecraftVersion..." -ForegroundColor Cyan
        $success = Install-FabricLoader -MinecraftVersion $MinecraftVersion -LoaderVersion $selectedVersion -APIVersion $apiVersion
        
        if ($success) {
            Write-Host "Fabric installation complete!" -ForegroundColor Green
        } else {
            Write-Host "Fabric installation failed" -ForegroundColor Red
        }
        
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } else {
        Write-Host "Invalid choice" -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}

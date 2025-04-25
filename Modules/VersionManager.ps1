# VersionManager.ps1
# Module for managing Minecraft versions

# Define mirror URLs
$MIRROR_URLS = @{
    "Official" = @{
        "VersionManifest" = "https://launchermeta.mojang.com/mc/game/version_manifest.json"
        "LauncherMeta" = "https://launchermeta.mojang.com"
        "Resources" = "https://resources.download.minecraft.net"
        "Libraries" = "https://libraries.minecraft.net"
    }
    "BMCLAPI" = @{
        "VersionManifest" = "https://bmclapi2.bangbang93.com/mc/game/version_manifest.json"
        "LauncherMeta" = "https://bmclapi2.bangbang93.com"
        "Resources" = "https://bmclapi2.bangbang93.com/assets"
        "Libraries" = "https://bmclapi2.bangbang93.com/maven"
    }
    "MCBBS" = @{
        "VersionManifest" = "https://download.mcbbs.net/mc/game/version_manifest.json"
        "LauncherMeta" = "https://download.mcbbs.net"
        "Resources" = "https://download.mcbbs.net/assets"
        "Libraries" = "https://download.mcbbs.net/maven"
    }
}

# Function to convert URLs based on selected mirror
function Convert-ToMirrorUrl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $config = Get-LauncherConfig
    $mirror = $config.DownloadMirror

    # If using official mirror or mirror not configured, return original URL
    if ($mirror -eq "Official" -or -not $MIRROR_URLS.ContainsKey($mirror)) {
        return $Url
    }

    # If using custom mirror
    if ($mirror -eq "Custom" -and $config.CustomMirrorUrl) {
        $customBase = $config.CustomMirrorUrl.TrimEnd('/')

        # Handle version manifest
        if ($Url -eq "https://launchermeta.mojang.com/mc/game/version_manifest.json") {
            return "$customBase/mc/game/version_manifest.json"
        }

        # Handle launcher meta URLs
        if ($Url -match "^https://launchermeta\.mojang\.com/(.+)$") {
            return "$customBase/$($matches[1])"
        }

        # Handle resource URLs
        if ($Url -match "^https://resources\.download\.minecraft\.net/(.+)$") {
            return "$customBase/assets/$($matches[1])"
        }

        # Handle library URLs
        if ($Url -match "^https://libraries\.minecraft\.net/(.+)$") {
            return "$customBase/maven/$($matches[1])"
        }

        # If no pattern matches, return original URL
        return $Url
    }

    # Handle known mirrors (BMCLAPI, MCBBS)
    $mirrorUrls = $MIRROR_URLS[$mirror]

    # Handle version manifest
    if ($Url -eq "https://launchermeta.mojang.com/mc/game/version_manifest.json") {
        return $mirrorUrls.VersionManifest
    }

    # Handle launcher meta URLs
    if ($Url -match "^https://launchermeta\.mojang\.com/(.+)$") {
        return "$($mirrorUrls.LauncherMeta)/$($matches[1])"
    }

    # Handle resource URLs
    if ($Url -match "^https://resources\.download\.minecraft\.net/(.+)$") {
        return "$($mirrorUrls.Resources)/$($matches[1])"
    }

    # Handle library URLs
    if ($Url -match "^https://libraries\.minecraft\.net/(.+)$") {
        return "$($mirrorUrls.Libraries)/$($matches[1])"
    }

    # If no pattern matches, return original URL
    return $Url
}

# Define PowerShell functions for web requests
function Get-WebContent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        # Convert URL to mirror URL if needed
        $mirrorUrl = Convert-ToMirrorUrl -Url $Url

        if ($mirrorUrl -ne $Url) {
            Write-DebugLog -Message "Using mirror URL: $mirrorUrl (original: $Url)" -Source "VersionManager" -Level "Debug"
        }

        $response = Invoke-WebRequest -Uri $mirrorUrl -UseBasicParsing
        return $response.Content
    }
    catch {
        Write-DebugLog -Message "Error downloading content from $Url - $($_.Exception.Message)" -Source "VersionManager" -Level "Error"

        # If using a mirror and it failed, try the original URL as fallback
        $config = Get-LauncherConfig
        if ($config.DownloadMirror -ne "Official" -and $Url -ne (Convert-ToMirrorUrl -Url $Url)) {
            try {
                Write-DebugLog -Message "Mirror download failed, trying official URL as fallback" -Source "VersionManager" -Level "Warning"
                Write-Host "  Mirror download failed, trying official URL..." -ForegroundColor Yellow

                $response = Invoke-WebRequest -Uri $Url -UseBasicParsing
                return $response.Content
            }
            catch {
                Write-DebugLog -Message "Fallback download also failed - $($_.Exception.Message)" -Source "VersionManager" -Level "Error"
                throw
            }
        }
        else {
            throw
        }
    }
}

function Save-WebFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    try {
        $directory = Split-Path -Path $FilePath -Parent
        if (-not (Test-Path -Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        # Convert URL to mirror URL if needed
        $mirrorUrl = Convert-ToMirrorUrl -Url $Url

        if ($mirrorUrl -ne $Url) {
            Write-DebugLog -Message "Using mirror URL: $mirrorUrl (original: $Url)" -Source "VersionManager" -Level "Debug"
        }

        Invoke-WebRequest -Uri $mirrorUrl -OutFile $FilePath -UseBasicParsing
    }
    catch {
        Write-DebugLog -Message "Error downloading file from $Url to $FilePath - $($_.Exception.Message)" -Source "VersionManager" -Level "Error"

        # If using a mirror and it failed, try the original URL as fallback
        $config = Get-LauncherConfig
        if ($config.DownloadMirror -ne "Official" -and $Url -ne (Convert-ToMirrorUrl -Url $Url)) {
            try {
                Write-DebugLog -Message "Mirror download failed, trying official URL as fallback" -Source "VersionManager" -Level "Warning"
                Write-Host "  Mirror download failed, trying official URL..." -ForegroundColor Yellow

                Invoke-WebRequest -Uri $Url -OutFile $FilePath -UseBasicParsing
            }
            catch {
                Write-DebugLog -Message "Fallback download also failed - $($_.Exception.Message)" -Source "VersionManager" -Level "Error"
                throw
            }
        }
        else {
            throw
        }
    }
}

# Multi-threaded download functions
function Start-MultiThreadedDownload {
    param (
        [Parameter(Mandatory = $true)]
        [array]$DownloadList,

        [Parameter(Mandatory = $false)]
        [int]$MaxThreads = 8,

        [Parameter(Mandatory = $false)]
        [string]$ActivityName = "Downloading files"
    )

    try {
        $config = Get-LauncherConfig

        # Check if multithread download is enabled
        if (-not $config.UseMultithreadDownload) {
            Write-DebugLog -Message "Multithread download is disabled, using single-threaded download" -Source "VersionManager" -Level "Info"

            $totalFiles = $DownloadList.Count
            $currentFile = 0

            foreach ($item in $DownloadList) {
                $currentFile++
                $percentComplete = [math]::Round(($currentFile / $totalFiles) * 100, 0)
                Write-Progress -Activity $ActivityName -Status "$percentComplete% complete" -PercentComplete $percentComplete -CurrentOperation "Downloading $($item.Name)"

                Save-WebFile -Url $item.Url -FilePath $item.FilePath
            }

            Write-Progress -Activity $ActivityName -Completed
            return
        }

        # Use the configured max threads
        $maxConcurrentJobs = $config.MaxDownloadThreads
        if ($MaxThreads -lt $maxConcurrentJobs) {
            $maxConcurrentJobs = $MaxThreads
        }

        Write-DebugLog -Message "Starting multi-threaded download with $maxConcurrentJobs threads" -Source "VersionManager" -Level "Info"

        # Create a runspace pool
        $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $maxConcurrentJobs, $sessionState, $Host)
        $pool.Open()

        $scriptBlock = {
            param($url, $filePath, $originalUrl)

            try {
                $directory = Split-Path -Path $filePath -Parent
                if (-not (Test-Path -Path $directory)) {
                    New-Item -Path $directory -ItemType Directory -Force | Out-Null
                }

                Invoke-WebRequest -Uri $url -OutFile $filePath -UseBasicParsing
                return @{
                    Success = $true
                    FilePath = $filePath
                    Error = $null
                }
            }
            catch {
                # If we have an original URL and it's different from the mirror URL, try it as fallback
                if ($originalUrl -and $originalUrl -ne $url) {
                    try {
                        Invoke-WebRequest -Uri $originalUrl -OutFile $filePath -UseBasicParsing
                        return @{
                            Success = $true
                            FilePath = $filePath
                            Error = $null
                            Fallback = $true
                        }
                    }
                    catch {
                        return @{
                            Success = $false
                            FilePath = $filePath
                            Error = $_.Exception.Message
                        }
                    }
                }
                else {
                    return @{
                        Success = $false
                        FilePath = $filePath
                        Error = $_.Exception.Message
                    }
                }
            }
        }

        # Create and start jobs
        $jobs = @()
        $totalFiles = $DownloadList.Count

        foreach ($item in $DownloadList) {
            # Convert URL to mirror URL if needed
            $originalUrl = $item.Url
            $mirrorUrl = Convert-ToMirrorUrl -Url $originalUrl

            if ($mirrorUrl -ne $originalUrl) {
                Write-DebugLog -Message "Using mirror URL for $($item.Name): $mirrorUrl" -Source "VersionManager" -Level "Debug"
            }

            $powershell = [powershell]::Create().AddScript($scriptBlock).AddArgument($mirrorUrl).AddArgument($item.FilePath).AddArgument($originalUrl)
            $powershell.RunspacePool = $pool

            $jobs += [PSCustomObject]@{
                PowerShell = $powershell
                Handle = $powershell.BeginInvoke()
                Item = $item
                MirrorUrl = $mirrorUrl
                OriginalUrl = $originalUrl
            }
        }

        # Monitor jobs and update progress
        $completed = 0
        $failed = 0

        while ($jobs.Handle.IsCompleted -contains $false) {
            $completedJobs = $jobs.Handle | Where-Object { $_.IsCompleted -eq $true }
            $currentCompleted = $completedJobs.Count

            if ($currentCompleted -gt $completed) {
                $completed = $currentCompleted
                $percentComplete = [math]::Round(($completed / $totalFiles) * 100, 0)
                Write-Progress -Activity $ActivityName -Status "$percentComplete% complete" -PercentComplete $percentComplete -CurrentOperation "$completed of $totalFiles files"
            }

            Start-Sleep -Milliseconds 100
        }

        # Process results
        foreach ($job in $jobs) {
            $result = $job.PowerShell.EndInvoke($job.Handle)

            if (-not $result.Success) {
                $failed++
                Write-DebugLog -Message "Failed to download file to $($result.FilePath): $($result.Error)" -Source "VersionManager" -Level "Error"
            }

            $job.PowerShell.Dispose()
        }

        # Clean up
        $pool.Close()
        $pool.Dispose()

        Write-Progress -Activity $ActivityName -Completed

        if ($failed -gt 0) {
            Write-DebugLog -Message "Completed multi-threaded download with $failed failures out of $totalFiles files" -Source "VersionManager" -Level "Warning"
        }
        else {
            Write-DebugLog -Message "Successfully completed multi-threaded download of $totalFiles files" -Source "VersionManager" -Level "Info"
        }
    }
    catch {
        Write-DebugLog -Message "Error in multi-threaded download: $($_.Exception.Message)" -Source "VersionManager" -Level "Error"
        throw
    }
}

# Get available Minecraft versions list
function Get-MinecraftVersions {
    try {
        Write-DebugLog -Message "Fetching Minecraft version manifest" -Source "VersionManager" -Level "Debug"
        $manifestJson = Get-WebContent -Url "https://launchermeta.mojang.com/mc/game/version_manifest.json"
        $manifest = $manifestJson | ConvertFrom-Json

        Write-DebugLog -Message "Retrieved version list with $($manifest.versions.Count) versions" -Source "VersionManager" -Level "Debug"
        return $manifest.versions
    }
    catch {
        Write-DebugLog -Message "Error getting Minecraft version list: $($_.Exception.Message)" -Source "VersionManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "VersionManager" -CustomMessage "Error getting Minecraft version list" -Continue
        return @()
    }
}

# Get specific version details
function Get-VersionInfo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    try {
        Write-DebugLog -Message "Getting information for version $Version" -Source "VersionManager" -Level "Debug"
        $versions = Get-MinecraftVersions
        $versionInfo = $versions | Where-Object { $_.id -eq $Version } | Select-Object -First 1

        if (-not $versionInfo) {
            Write-DebugLog -Message "Version $Version not found in version manifest" -Source "VersionManager" -Level "Warning"
            Write-Host "Version $Version not found" -ForegroundColor Red
            return $null
        }

        Write-DebugLog -Message "Fetching detailed information for version $Version from $($versionInfo.url)" -Source "VersionManager" -Level "Debug"
        $versionJson = Get-WebContent -Url $versionInfo.url
        $versionDetails = $versionJson | ConvertFrom-Json
        Write-DebugLog -Message "Retrieved version details for $Version" -Source "VersionManager" -Level "Debug"

        return $versionDetails
    }
    catch {
        Write-DebugLog -Message "Error getting version $Version information: $($_.Exception.Message)" -Source "VersionManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "VersionManager" -CustomMessage "Error getting version $Version information" -Continue
        return $null
    }
}

# Download Minecraft version
function Install-MinecraftVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    try {
        Write-DebugLog -Message "Starting installation of Minecraft version $Version" -Source "VersionManager" -Level "Info"
        Write-Host "Getting information for version $Version..." -ForegroundColor Cyan
        $versionInfo = Get-VersionInfo -Version $Version

        if (-not $versionInfo) {
            Write-DebugLog -Message "Cannot install version $Version - Version information not found" -Source "VersionManager" -Level "Error"
            return
        }

        # Create version directory
        $versionDir = Join-Path -Path $versionsPath -ChildPath $Version
        if (-not (Test-Path -Path $versionDir)) {
            Write-DebugLog -Message "Creating version directory: $versionDir" -Source "VersionManager" -Level "Debug"
            New-Item -Path $versionDir -ItemType Directory | Out-Null
        }

        # Save version JSON
        $versionJsonPath = Join-Path -Path $versionDir -ChildPath "$Version.json"
        Write-DebugLog -Message "Saving version JSON to $versionJsonPath" -Source "VersionManager" -Level "Debug"
        $versionInfo | ConvertTo-Json -Depth 100 | Set-Content -Path $versionJsonPath

        # Download client JAR
        $clientJarPath = Join-Path -Path $versionDir -ChildPath "$Version.jar"
        Write-DebugLog -Message "Downloading client JAR from $($versionInfo.downloads.client.url)" -Source "VersionManager" -Level "Debug"
        Write-Host "Downloading Minecraft client ($Version)..." -ForegroundColor Cyan
        Save-WebFile -Url $versionInfo.downloads.client.url -FilePath $clientJarPath
        Write-DebugLog -Message "Client JAR downloaded to $clientJarPath" -Source "VersionManager" -Level "Debug"

        # Download library files
        Write-DebugLog -Message "Starting download of library files" -Source "VersionManager" -Level "Debug"
        Write-Host "Downloading library files..." -ForegroundColor Cyan
        $libraryCount = $versionInfo.libraries.Count
        Write-DebugLog -Message "Total libraries to process: $libraryCount" -Source "VersionManager" -Level "Debug"

        # Prepare library download list
        $libraryDownloadList = @()

        foreach ($library in $versionInfo.libraries) {
            if ($library.downloads.artifact) {
                $libraryPath = Join-Path -Path $librariesPath -ChildPath $library.downloads.artifact.path

                if (-not (Test-Path -Path $libraryPath)) {
                    $libraryDownloadList += [PSCustomObject]@{
                        Name = $library.name
                        Url = $library.downloads.artifact.url
                        FilePath = $libraryPath
                    }
                }
                else {
                    Write-DebugLog -Message "Library already exists: $($library.name)" -Source "VersionManager" -Level "Debug"
                }
            }
        }

        # Download libraries using multi-threaded download
        if ($libraryDownloadList.Count -gt 0) {
            Write-Host "  Downloading $($libraryDownloadList.Count) libraries..." -ForegroundColor Gray
            Start-MultiThreadedDownload -DownloadList $libraryDownloadList -ActivityName "Downloading library files"
        }
        else {
            Write-Host "  All libraries already downloaded" -ForegroundColor Gray
        }

        # Download asset index
        Write-DebugLog -Message "Starting download of asset index" -Source "VersionManager" -Level "Debug"
        Write-Host "Downloading asset index..." -ForegroundColor Cyan
        $assetIndexPath = Join-Path -Path $assetsPath -ChildPath "indexes"
        if (-not (Test-Path -Path $assetIndexPath)) {
            Write-DebugLog -Message "Creating asset index directory: $assetIndexPath" -Source "VersionManager" -Level "Debug"
            New-Item -Path $assetIndexPath -ItemType Directory -Force | Out-Null
        }

        $assetIndexFile = Join-Path -Path $assetIndexPath -ChildPath "$($versionInfo.assetIndex.id).json"
        Write-DebugLog -Message "Downloading asset index from $($versionInfo.assetIndex.url)" -Source "VersionManager" -Level "Debug"
        Save-WebFile -Url $versionInfo.assetIndex.url -FilePath $assetIndexFile
        Write-DebugLog -Message "Asset index downloaded to $assetIndexFile" -Source "VersionManager" -Level "Debug"

        # Download asset files
        Write-DebugLog -Message "Starting download of asset files" -Source "VersionManager" -Level "Debug"
        Write-Host "Downloading asset files..." -ForegroundColor Cyan
        $assetIndex = Get-Content -Path $assetIndexFile -Raw | ConvertFrom-Json
        $objectsPath = Join-Path -Path $assetsPath -ChildPath "objects"

        if (-not (Test-Path -Path $objectsPath)) {
            Write-DebugLog -Message "Creating objects directory: $objectsPath" -Source "VersionManager" -Level "Debug"
            New-Item -Path $objectsPath -ItemType Directory -Force | Out-Null
        }

        $totalAssets = ($assetIndex.objects | Get-Member -MemberType NoteProperty).Count
        Write-DebugLog -Message "Total assets to process: $totalAssets" -Source "VersionManager" -Level "Debug"

        # Prepare asset download list
        $assetDownloadList = @()
        $assetCount = 0

        foreach ($asset in $assetIndex.objects.PSObject.Properties) {
            $hash = $asset.Value.hash
            $hashPrefix = $hash.Substring(0, 2)
            $assetDir = Join-Path -Path $objectsPath -ChildPath $hashPrefix
            $assetPath = Join-Path -Path $assetDir -ChildPath $hash

            # Create directory if it doesn't exist
            if (-not (Test-Path -Path $assetDir)) {
                New-Item -Path $assetDir -ItemType Directory -Force | Out-Null
            }

            if (-not (Test-Path -Path $assetPath)) {
                $assetUrl = "https://resources.download.minecraft.net/$hashPrefix/$hash"
                $assetDownloadList += [PSCustomObject]@{
                    Name = $asset.Name
                    Url = $assetUrl
                    FilePath = $assetPath
                }
                $assetCount++
            }
        }

        # Download assets using multi-threaded download
        if ($assetDownloadList.Count -gt 0) {
            Write-Host "  Downloading $assetCount of $totalAssets asset files..." -ForegroundColor Gray

            # Use a lower thread count for assets as there are many small files
            $config = Get-LauncherConfig
            $assetThreads = [Math]::Min($config.MaxDownloadThreads, 16)

            Start-MultiThreadedDownload -DownloadList $assetDownloadList -ActivityName "Downloading asset files" -MaxThreads $assetThreads
        }
        else {
            Write-Host "  All asset files already downloaded" -ForegroundColor Gray
        }

        Write-DebugLog -Message "Minecraft version $Version installation complete" -Source "VersionManager" -Level "Info"
        Write-Host "Minecraft version $Version installation complete!" -ForegroundColor Green

        # Add version to installed list
        Add-InstalledVersion -Version $Version
    }
    catch {
        Write-DebugLog -Message "Error installing Minecraft version $Version - $($_.Exception.Message)" -Source "VersionManager" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "VersionManager" -CustomMessage "Error installing Minecraft version $Version"
    }
}

# Get installed versions list
function Get-InstalledVersions {
    $configFile = Join-Path -Path $configPath -ChildPath "installed.json"

    if (-not (Test-Path -Path $configFile)) {
        Write-DebugLog -Message "installed.json file not found" -Source "VersionManager" -Level "Warning"
        return @()
    }

    try {
        $content = Get-Content -Path $configFile -Raw
        Write-DebugLog -Message "Raw content of installed.json: $content" -Source "VersionManager" -Level "Debug"

        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-DebugLog -Message "installed.json is empty" -Source "VersionManager" -Level "Warning"
            return @()
        }

        # Parse the JSON content
        $installedVersions = @()

        try {
            # Try to parse the JSON content
            $parsedContent = $content | ConvertFrom-Json

            # Check if the parsed content is an array
            if ($parsedContent -is [Array]) {
                Write-DebugLog -Message "Parsed content is an array with $($parsedContent.Count) items" -Source "VersionManager" -Level "Debug"
                $installedVersions = $parsedContent
            }
            # Check if the parsed content is a string (single item)
            elseif ($parsedContent -is [String]) {
                Write-DebugLog -Message "Parsed content is a string: $parsedContent" -Source "VersionManager" -Level "Debug"
                $installedVersions = @($parsedContent)
            }
            # Check if the parsed content is a PSCustomObject (JSON object)
            elseif ($parsedContent -is [PSCustomObject]) {
                Write-DebugLog -Message "Parsed content is a PSCustomObject" -Source "VersionManager" -Level "Debug"
                # Extract properties as versions if applicable
                $properties = $parsedContent | Get-Member -MemberType NoteProperty
                if ($properties) {
                    foreach ($prop in $properties) {
                        $installedVersions += $parsedContent.($prop.Name)
                    }
                }
            }
            else {
                Write-DebugLog -Message "Parsed content is of unknown type: $($parsedContent.GetType().FullName)" -Source "VersionManager" -Level "Warning"
            }
        }
        catch {
            Write-DebugLog -Message "Error parsing JSON: $($_.Exception.Message)" -Source "VersionManager" -Level "Warning"
        }

        # If parsing failed or returned empty array, try to scan versions directory
        if ($installedVersions.Count -eq 0) {
            Write-DebugLog -Message "No versions found in config, scanning versions directory" -Source "VersionManager" -Level "Info"

            if (Test-Path -Path $versionsPath) {
                $versionDirs = Get-ChildItem -Path $versionsPath -Directory

                foreach ($dir in $versionDirs) {
                    $versionId = $dir.Name
                    $versionJsonFile = Join-Path -Path $dir.FullName -ChildPath "$versionId.json"
                    $versionJarFile = Join-Path -Path $dir.FullName -ChildPath "$versionId.jar"

                    # Check if version files exist
                    if ((Test-Path -Path $versionJsonFile) -and (Test-Path -Path $versionJarFile)) {
                        $installedVersions += $versionId
                        Write-DebugLog -Message "Found installed version: $versionId" -Source "VersionManager" -Level "Debug"
                    }
                }

                # Save the discovered versions to the config file
                if ($installedVersions.Count -gt 0) {
                    $json = ConvertTo-Json -InputObject $installedVersions -Depth 1
                    Set-Content -Path $configFile -Value $json
                    Write-DebugLog -Message "Updated installed.json with discovered versions" -Source "VersionManager" -Level "Info"
                }
            }
        }

        # Convert each element to string to avoid PowerShell's string interpolation issues
        $result = @()
        Write-DebugLog -Message "Converting array elements to strings" -Source "VersionManager" -Level "Debug"
        foreach ($version in $installedVersions) {
            Write-DebugLog -Message "Processing version: $version (Type: $($version.GetType().FullName))" -Source "VersionManager" -Level "Debug"
            $result += $version.ToString()
        }

        Write-DebugLog -Message "Returning versions: $($result -join ', ')" -Source "VersionManager" -Level "Debug"
        return $result
    }
    catch {
        Write-DebugLog -Message "Error reading installed versions list: $($_.Exception.Message)" -Source "VersionManager" -Level "Error"
        Write-Host "Error reading installed versions list" -ForegroundColor Red
        return @()
    }
}

# Add version to installed list
function Add-InstalledVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $configFile = Join-Path -Path $configPath -ChildPath "installed.json"

    try {
        if (Test-Path -Path $configFile) {
            $content = Get-Content -Path $configFile -Raw
            if ([string]::IsNullOrWhiteSpace($content)) {
                $installedVersions = @()
            }
            else {
                try {
                    # Parse the JSON content
                    $installedVersions = @()

                    try {
                        # Try to parse the JSON content
                        $parsedContent = $content | ConvertFrom-Json

                        # Check if the parsed content is an array
                        if ($parsedContent -is [Array]) {
                            $installedVersions = $parsedContent
                        }
                        # Check if the parsed content is a string (single item)
                        elseif ($parsedContent -is [String]) {
                            $installedVersions = @($parsedContent)
                        }
                        # Check if the parsed content is a PSCustomObject (JSON object)
                        elseif ($parsedContent -is [PSCustomObject]) {
                            # Extract properties as versions if applicable
                            $properties = $parsedContent | Get-Member -MemberType NoteProperty
                            if ($properties) {
                                foreach ($prop in $properties) {
                                    $installedVersions += $parsedContent.($prop.Name)
                                }
                            }
                        }
                    }
                    catch {
                        Write-DebugLog -Message "Error parsing JSON: $($_.Exception.Message)" -Source "VersionManager" -Level "Warning"
                        $installedVersions = @()
                    }
                }
                catch {
                    Write-DebugLog -Message "Error parsing installed.json, creating new array" -Source "VersionManager" -Level "Warning"
                    $installedVersions = @()
                }
            }
        }
        else {
            $installedVersions = @()
        }

        # Check if version is already in the array
        $versionExists = $false
        foreach ($v in $installedVersions) {
            if ($v -eq $Version) {
                $versionExists = $true
                break
            }
        }

        # Add version if it doesn't exist
        if (-not $versionExists) {
            $installedVersions += $Version
        }

        # Ensure array format when converting to JSON
        $json = ConvertTo-Json -InputObject $installedVersions -Depth 1
        Set-Content -Path $configFile -Value $json

        Write-DebugLog -Message "Added version $Version to installed list" -Source "VersionManager" -Level "Debug"
    }
    catch {
        Write-DebugLog -Message "Error adding version to installed list: $($_.Exception.Message)" -Source "VersionManager" -Level "Error"
        Write-Host "Error adding version to installed list" -ForegroundColor Red
    }
}

# Synchronize installed versions list with actual installed versions
function Sync-InstalledVersions {
    param (
        [switch]$Silent
    )

    $configFile = Join-Path -Path $configPath -ChildPath "installed.json"

    try {
        Write-DebugLog -Message "Synchronizing installed versions list" -Source "VersionManager" -Level "Info"

        # Get current installed versions from config
        $currentInstalledVersions = Get-InstalledVersions
        Write-DebugLog -Message "Current installed versions from config: $($currentInstalledVersions -join ', ')" -Source "VersionManager" -Level "Debug"

        # Scan versions directory for actual installed versions
        $actualInstalledVersions = @()

        if (Test-Path -Path $versionsPath) {
            $versionDirs = Get-ChildItem -Path $versionsPath -Directory
            Write-DebugLog -Message "Found version directories: $($versionDirs.Count)" -Source "VersionManager" -Level "Debug"

            foreach ($dir in $versionDirs) {
                $versionId = $dir.Name
                Write-DebugLog -Message "Processing version directory: $versionId" -Source "VersionManager" -Level "Debug"
                $versionJsonFile = Join-Path -Path $dir.FullName -ChildPath "$versionId.json"
                $versionJarFile = Join-Path -Path $dir.FullName -ChildPath "$versionId.jar"

                # Check if version files exist
                $jsonExists = Test-Path -Path $versionJsonFile
                $jarExists = Test-Path -Path $versionJarFile
                Write-DebugLog -Message "Version $versionId - JSON exists: $jsonExists, JAR exists: $jarExists" -Source "VersionManager" -Level "Debug"

                if ($jsonExists -and $jarExists) {
                    $actualInstalledVersions += $versionId
                    Write-DebugLog -Message "Added $versionId to actual installed versions" -Source "VersionManager" -Level "Debug"
                }
                else {
                    Write-DebugLog -Message "Incomplete version found: $versionId" -Source "VersionManager" -Level "Warning"
                }
            }
        }
        else {
            Write-DebugLog -Message "Versions directory does not exist: $versionsPath" -Source "VersionManager" -Level "Warning"
        }

        # Compare lists
        $added = @()
        $removed = @()

        # Find versions that are installed but not in the list
        Write-DebugLog -Message "Comparing actual versions with config versions" -Source "VersionManager" -Level "Debug"
        foreach ($version in $actualInstalledVersions) {
            Write-DebugLog -Message "Checking if $version is in config list" -Source "VersionManager" -Level "Debug"
            if ($currentInstalledVersions -notcontains $version) {
                Write-DebugLog -Message "Version $version is not in config list, adding to 'added' list" -Source "VersionManager" -Level "Debug"
                $added += $version
            }
        }

        # Find versions that are in the list but not actually installed
        foreach ($version in $currentInstalledVersions) {
            Write-DebugLog -Message "Checking if $version is actually installed" -Source "VersionManager" -Level "Debug"
            if ($actualInstalledVersions -notcontains $version) {
                Write-DebugLog -Message "Version $version is in config but not actually installed, adding to 'removed' list" -Source "VersionManager" -Level "Debug"
                $removed += $version
            }
        }

        # Update installed.json if changes were found
        if ($added.Count -gt 0 -or $removed.Count -gt 0) {
            Write-DebugLog -Message "Changes found: Added $($added.Count), Removed $($removed.Count)" -Source "VersionManager" -Level "Info"
            Write-DebugLog -Message "Added versions: $($added -join ', ')" -Source "VersionManager" -Level "Debug"
            Write-DebugLog -Message "Removed versions: $($removed -join ', ')" -Source "VersionManager" -Level "Debug"

            # Ensure $actualInstalledVersions is an array before converting to JSON
            if ($actualInstalledVersions -isnot [Array]) {
                Write-DebugLog -Message "Converting actualInstalledVersions to array" -Source "VersionManager" -Level "Warning"
                $actualInstalledVersions = @($actualInstalledVersions)
            }

            # Create a clean array of strings
            $cleanVersions = @()
            foreach ($version in $actualInstalledVersions) {
                if ($version) {
                    $cleanVersions += $version.ToString()
                }
            }

            # Save the updated list
            $json = ConvertTo-Json -InputObject $cleanVersions -Depth 1
            Write-DebugLog -Message "Saving updated JSON: $json" -Source "VersionManager" -Level "Debug"
            Set-Content -Path $configFile -Value $json

            Write-DebugLog -Message "Updated installed versions list: Added $($added.Count), Removed $($removed.Count)" -Source "VersionManager" -Level "Info"

            if (-not $Silent) {
                if ($added.Count -gt 0) {
                    Write-Host "Added $($added.Count) version(s) to installed list:" -ForegroundColor Green
                    foreach ($version in $added) {
                        Write-Host "  - $version" -ForegroundColor Green
                    }
                }

                if ($removed.Count -gt 0) {
                    Write-Host "Removed $($removed.Count) version(s) from installed list:" -ForegroundColor Yellow
                    foreach ($version in $removed) {
                        Write-Host "  - $version" -ForegroundColor Yellow
                    }
                }
            }

            return $true
        }
        else {
            Write-DebugLog -Message "Installed versions list is up to date" -Source "VersionManager" -Level "Debug"
            Write-DebugLog -Message "Current versions: $($actualInstalledVersions -join ', ')" -Source "VersionManager" -Level "Debug"
            return $false
        }
    }
    catch {
        Write-DebugLog -Message "Error synchronizing installed versions list: $($_.Exception.Message)" -Source "VersionManager" -Level "Error"
        if (-not $Silent) {
            Write-Host "Error synchronizing installed versions list" -ForegroundColor Red
        }
        return $false
    }
}

# Display version menu
function Show-VersionMenu {
    while ($true) {
        Clear-Host
        Write-Host "===== Minecraft Version Management =====" -ForegroundColor Cyan
        Write-Host "1. View available versions"
        Write-Host "2. View installed versions"
        Write-Host "3. Install version"
        Write-Host "4. Manage mod loaders"
        Write-Host "5. Return to main menu"

        $choice = Read-Host "Please select an option"

        switch ($choice) {
            "1" {
                Clear-Host
                Write-Host "Getting available Minecraft versions..." -ForegroundColor Cyan
                $versions = Get-MinecraftVersions

                Write-Host "===== Available Minecraft Versions =====" -ForegroundColor Green
                $versions | ForEach-Object {
                    $releaseType = switch ($_.type) {
                        "release" { "Release" }
                        "snapshot" { "Snapshot" }
                        "old_beta" { "Beta" }
                        "old_alpha" { "Alpha" }
                        default { $_.type }
                    }

                    Write-Host "$($_.id) - $releaseType - $($_.releaseTime)"
                }

                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Clear-Host
                Write-Host "===== Installed Minecraft Versions =====" -ForegroundColor Green

                # Sync installed versions before displaying
                Sync-InstalledVersions

                $installedVersions = Get-InstalledVersions

                if ($installedVersions.Count -eq 0) {
                    Write-Host "No versions installed yet" -ForegroundColor Yellow
                }
                else {
                    foreach ($version in $installedVersions) {
                        Write-Host $version
                    }
                }

                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                $version = Read-Host "Enter the Minecraft version to install (e.g., 1.20.1)"
                Install-MinecraftVersion -Version $version

                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "4" {
                # Mod loader management
                Clear-Host
                Write-Host "===== Mod Loader Management =====" -ForegroundColor Green

                # Sync installed versions before displaying
                Sync-InstalledVersions

                $installedVersions = Get-InstalledVersions

                if ($installedVersions.Count -eq 0) {
                    Write-Host "No Minecraft versions installed yet. Please install a version first." -ForegroundColor Yellow
                    Write-Host "Press any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "Select a Minecraft version to manage mod loaders:" -ForegroundColor Cyan

                    for ($i = 0; $i -lt $installedVersions.Count; $i++) {
                        Write-Host "$($i+1). $($installedVersions[$i])" -ForegroundColor White
                    }

                    Write-Host "0. Return to version menu" -ForegroundColor Yellow

                    $versionChoice = Read-Host "Please select a version"

                    if ($versionChoice -ne "0") {
                        $versionIndex = [int]$versionChoice - 1

                        if ($versionIndex -ge 0 -and $versionIndex -lt $installedVersions.Count) {
                            $selectedVersion = $installedVersions[$versionIndex]
                            Show-ModLoaderMenu -MinecraftVersion $selectedVersion
                        } else {
                            Write-Host "Invalid choice" -ForegroundColor Red
                            Start-Sleep -Seconds 1
                        }
                    }
                }
            }
            "5" {
                return
            }
            default {
                Write-Host "Invalid choice, please try again" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

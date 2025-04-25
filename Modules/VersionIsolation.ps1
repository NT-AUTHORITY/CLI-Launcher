# VersionIsolation.ps1
# Module for handling version isolation

# Get isolated game directory for a specific version
function Get-IsolatedGameDirectory {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $false)]
        [string]$ModLoaderType,
        
        [Parameter(Mandatory = $false)]
        [string]$ModLoaderVersion
    )
    
    $config = Get-LauncherConfig
    
    # If version isolation is disabled, return the default game directory
    if (-not $config.VersionIsolation -or -not $config.IsolateGameDirs) {
        return $minecraftPath
    }
    
    # Build the isolated directory path
    $isolatedDirName = $Version
    
    # If mod loader is specified, include it in the directory name
    if ($ModLoaderType -and $ModLoaderVersion) {
        $isolatedDirName = "$isolatedDirName-$ModLoaderType-$ModLoaderVersion"
    }
    
    $isolatedGameDir = Join-Path -Path $minecraftPath -ChildPath "instances\$isolatedDirName"
    
    # Create the directory if it doesn't exist
    if (-not (Test-Path -Path $isolatedGameDir)) {
        Write-DebugLog -Message "Creating isolated game directory: $isolatedGameDir" -Source "VersionIsolation" -Level "Info"
        New-Item -Path $isolatedGameDir -ItemType Directory -Force | Out-Null
    }
    
    return $isolatedGameDir
}

# Get isolated directory path for a specific version and directory type
function Get-IsolatedDirectory {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("saves", "resourcepacks", "screenshots", "shaderpacks", "mods")]
        [string]$DirectoryType,
        
        [Parameter(Mandatory = $false)]
        [string]$ModLoaderType,
        
        [Parameter(Mandatory = $false)]
        [string]$ModLoaderVersion
    )
    
    $config = Get-LauncherConfig
    
    # Check if version isolation is enabled
    if (-not $config.VersionIsolation) {
        # If isolation is disabled, return the default directory
        $defaultDir = Join-Path -Path $minecraftPath -ChildPath $DirectoryType
        
        # Create the directory if it doesn't exist
        if (-not (Test-Path -Path $defaultDir)) {
            Write-DebugLog -Message "Creating default directory: $defaultDir" -Source "VersionIsolation" -Level "Info"
            New-Item -Path $defaultDir -ItemType Directory -Force | Out-Null
        }
        
        return $defaultDir
    }
    
    # Check if the specific directory type should be isolated
    $isolateDir = switch ($DirectoryType) {
        "saves" { $config.IsolateSaveDirs }
        "resourcepacks" { $config.IsolateResourcePacks }
        "screenshots" { $config.IsolateScreenshots }
        "shaderpacks" { $config.IsolateShaderPacks }
        "mods" { $config.IsolateMods }
        default { $false }
    }
    
    if (-not $isolateDir) {
        # If this directory type is not isolated, return the default directory
        $defaultDir = Join-Path -Path $minecraftPath -ChildPath $DirectoryType
        
        # Create the directory if it doesn't exist
        if (-not (Test-Path -Path $defaultDir)) {
            Write-DebugLog -Message "Creating default directory: $defaultDir" -Source "VersionIsolation" -Level "Info"
            New-Item -Path $defaultDir -ItemType Directory -Force | Out-Null
        }
        
        return $defaultDir
    }
    
    # Get the isolated game directory
    $isolatedGameDir = Get-IsolatedGameDirectory -Version $Version -ModLoaderType $ModLoaderType -ModLoaderVersion $ModLoaderVersion
    
    # Build the isolated directory path
    $isolatedDir = Join-Path -Path $isolatedGameDir -ChildPath $DirectoryType
    
    # Create the directory if it doesn't exist
    if (-not (Test-Path -Path $isolatedDir)) {
        Write-DebugLog -Message "Creating isolated directory: $isolatedDir" -Source "VersionIsolation" -Level "Info"
        New-Item -Path $isolatedDir -ItemType Directory -Force | Out-Null
    }
    
    return $isolatedDir
}

# Ensure isolated directories exist for a specific version
function Ensure-IsolatedDirectories {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $false)]
        [string]$ModLoaderType,
        
        [Parameter(Mandatory = $false)]
        [string]$ModLoaderVersion
    )
    
    $config = Get-LauncherConfig
    
    # If version isolation is disabled, return
    if (-not $config.VersionIsolation) {
        return
    }
    
    # Create the isolated game directory
    $isolatedGameDir = Get-IsolatedGameDirectory -Version $Version -ModLoaderType $ModLoaderType -ModLoaderVersion $ModLoaderVersion
    
    # Create all necessary directories
    $directoryTypes = @("saves", "resourcepacks", "screenshots", "shaderpacks", "mods")
    
    foreach ($dirType in $directoryTypes) {
        $isolatedDir = Get-IsolatedDirectory -Version $Version -DirectoryType $dirType -ModLoaderType $ModLoaderType -ModLoaderVersion $ModLoaderVersion
        Write-DebugLog -Message "Ensured isolated directory exists: $isolatedDir" -Source "VersionIsolation" -Level "Debug"
    }
}

# GameLauncher.ps1
# Module for handling Minecraft game launching

# Load necessary .NET types only if they don't already exist
if (-not ([System.Management.Automation.PSTypeName]'MinecraftLauncher.GameLauncher').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Diagnostics;
using System.Text;
using System.Collections.Generic;

namespace MinecraftLauncher {
    public class GameLauncher {
        private static StreamWriter logWriter;

        public static Process LaunchGame(string javaPath, string[] args, string logFilePath) {
            // Create log file directory if it doesn't exist
            string logDirectory = Path.GetDirectoryName(logFilePath);
            if (!Directory.Exists(logDirectory)) {
                Directory.CreateDirectory(logDirectory);
            }

            // Open log file for writing
            logWriter = new StreamWriter(logFilePath, false, Encoding.UTF8);
            logWriter.AutoFlush = true;

            // Write header to log file
            logWriter.WriteLine("=== Minecraft Game Log ===");
            logWriter.WriteLine("Started: " + DateTime.Now.ToString());
            logWriter.WriteLine("Java Path: " + javaPath);
            logWriter.WriteLine("Command Line: " + javaPath + " " + string.Join(" ", args));
            logWriter.WriteLine("==============================");
            logWriter.WriteLine();

            ProcessStartInfo startInfo = new ProcessStartInfo {
                FileName = javaPath,
                Arguments = string.Join(" ", args),
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = false
            };

            Process process = new Process {
                StartInfo = startInfo,
                EnableRaisingEvents = true
            };

            // Use a flag to track if the log file has been closed
            bool logClosed = false;

            process.OutputDataReceived += (sender, e) => {
                if (!string.IsNullOrEmpty(e.Data) && !logClosed) {
                    try {
                        // Write to log file only
                        logWriter.WriteLine(e.Data);
                    }
                    catch (ObjectDisposedException) {
                        // Log writer was already closed
                        logClosed = true;
                    }
                }
            };

            process.ErrorDataReceived += (sender, e) => {
                if (!string.IsNullOrEmpty(e.Data) && !logClosed) {
                    try {
                        // Write to log file only
                        logWriter.WriteLine("ERROR: " + e.Data);
                    }
                    catch (ObjectDisposedException) {
                        // Log writer was already closed
                        logClosed = true;
                    }
                }
            };

            // Handle process exit to close log file
            process.Exited += (sender, e) => {
                if (!logClosed) {
                    try {
                        logWriter.WriteLine();
                        logWriter.WriteLine("=== Game Exited ===");
                        logWriter.WriteLine("Time: " + DateTime.Now.ToString());
                        logWriter.WriteLine("Exit Code: " + process.ExitCode);
                        logWriter.Close();
                        logClosed = true;
                    }
                    catch (Exception ex) {
                        // Handle any exceptions during log closing
                        Console.WriteLine("Error closing log file: " + ex.Message);
                    }
                }
            };

            // Register for application domain unload to ensure log file is closed
            AppDomain.CurrentDomain.ProcessExit += (sender, e) => {
                if (!logClosed) {
                    try {
                        logWriter.WriteLine();
                        logWriter.WriteLine("=== Application Exit ===");
                        logWriter.WriteLine("Time: " + DateTime.Now.ToString());
                        logWriter.Close();
                        logClosed = true;
                    }
                    catch {
                        // Ignore errors during shutdown
                    }
                }
            };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            return process;
        }

        public static string BuildClassPath(string librariesPath, string versionJar, List<string> libraries) {
            StringBuilder sb = new StringBuilder();

            foreach (string library in libraries) {
                string fullPath = Path.Combine(librariesPath, library);

                // Check if the path contains spaces, if so, wrap in quotes
                if (fullPath.Contains(" ") && !fullPath.StartsWith("\"") && !fullPath.EndsWith("\"")) {
                    sb.Append("\"").Append(fullPath).Append("\"");
                } else {
                    sb.Append(fullPath);
                }

                sb.Append(";");
            }

            // Check if version jar path contains spaces
            if (versionJar.Contains(" ") && !versionJar.StartsWith("\"") && !versionJar.EndsWith("\"")) {
                sb.Append("\"").Append(versionJar).Append("\"");
            } else {
                sb.Append(versionJar);
            }

            return sb.ToString();
        }
    }
}
"@
}

# Launch Minecraft game
function Start-MinecraftGame {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [switch]$UseModLoader,

        [Parameter(Mandatory = $false)]
        [string]$ModLoaderType,

        [Parameter(Mandatory = $false)]
        [string]$ModLoaderVersion
    )

    try {
        Write-DebugLog -Message "Starting game launch process for version $Version" -Source "GameLauncher" -Level "Info"

        # Check if we should use a mod loader - this is now handled directly in MinecraftLauncher.ps1
        # to avoid circular references
        if ($UseModLoader -and $ModLoaderType -and $ModLoaderVersion) {
            Write-DebugLog -Message "Using mod loader: $ModLoaderType $ModLoaderVersion" -Source "GameLauncher" -Level "Info"
            Write-Host "This code path should not be reached. Please report this as a bug." -ForegroundColor Red
            return
        }

        # Check if the version is a mod loader profile
        if ($Version -match "^(fabric|forge|neoforge|optifine)") {
            Write-DebugLog -Message "Detected mod loader profile: $Version" -Source "GameLauncher" -Level "Debug"
        }

        # Sync installed versions list
        Write-DebugLog -Message "Synchronizing installed versions list" -Source "GameLauncher" -Level "Debug"
        Sync-InstalledVersions -Silent

        # Check if version is installed
        $installedVersions = Get-InstalledVersions
        Write-DebugLog -Message "Checking if version $Version is installed" -Source "GameLauncher" -Level "Debug"

        # Special handling for mod loader profiles
        $isModLoaderProfile = $Version -match "^(fabric|forge|neoforge|optifine)"

        if ($installedVersions -notcontains $Version) {
            # If it's a mod loader profile, check if the directory exists directly
            if ($isModLoaderProfile) {
                $versionDir = Join-Path -Path $versionsPath -ChildPath $Version
                $versionJsonPath = Join-Path -Path $versionDir -ChildPath "$Version.json"
                $versionJarPath = Join-Path -Path $versionDir -ChildPath "$Version.jar"

                # For Fabric mod loader, we only check if the JSON file exists
                if ($Version -match "^fabric-") {
                    if (Test-Path -Path $versionJsonPath) {
                        Write-DebugLog -Message "Fabric mod loader profile $Version exists but is not in installed.json, adding it" -Source "GameLauncher" -Level "Info"
                        Add-InstalledVersion -Version $Version
                    } else {
                        Write-DebugLog -Message "Fabric mod loader profile $Version does not exist" -Source "GameLauncher" -Level "Warning"
                        Write-Host "Fabric mod loader profile $Version does not exist. Please reinstall the mod loader." -ForegroundColor Red
                        return
                    }
                } elseif ((Test-Path -Path $versionJsonPath) -and (Test-Path -Path $versionJarPath)) {
                    Write-DebugLog -Message "Mod loader profile $Version exists but is not in installed.json, adding it" -Source "GameLauncher" -Level "Info"
                    Add-InstalledVersion -Version $Version
                } else {
                    Write-DebugLog -Message "Mod loader profile $Version does not exist" -Source "GameLauncher" -Level "Warning"
                    Write-Host "Mod loader profile $Version does not exist. Please reinstall the mod loader." -ForegroundColor Red
                    return
                }
            } else {
                Write-DebugLog -Message "Version $Version is not installed" -Source "GameLauncher" -Level "Warning"
                Write-Host "Version $Version is not installed. Install now? (Y/N)" -ForegroundColor Yellow
                $install = Read-Host

                if ($install -eq "Y" -or $install -eq "y") {
                    Write-DebugLog -Message "Installing version $Version" -Source "GameLauncher" -Level "Debug"
                    Install-MinecraftVersion -Version $Version
                }
                else {
                    Write-DebugLog -Message "Game launch canceled by user" -Source "GameLauncher" -Level "Info"
                    Write-Host "Game launch canceled" -ForegroundColor Red
                    return
                }
            }
        }

        # Check authentication status
        Write-DebugLog -Message "Checking authentication status" -Source "GameLauncher" -Level "Debug"
        $authStatus = Get-AuthenticationStatus

        if (-not $authStatus.IsAuthenticated) {
            Write-DebugLog -Message "User is not authenticated" -Source "GameLauncher" -Level "Warning"
            Write-Host "You are not logged in. Please log in first" -ForegroundColor Yellow
            Invoke-Authentication

            # Recheck authentication status
            Write-DebugLog -Message "Rechecking authentication status" -Source "GameLauncher" -Level "Debug"
            $authStatus = Get-AuthenticationStatus

            if (-not $authStatus.IsAuthenticated) {
                Write-DebugLog -Message "Authentication failed, cannot launch game" -Source "GameLauncher" -Level "Error"
                Write-Host "Cannot launch game: Authentication failed" -ForegroundColor Red
                return
            }
        }

        if ($authStatus.IsOffline) {
            Write-DebugLog -Message "User authenticated in offline mode as $($authStatus.Username)" -Source "GameLauncher" -Level "Debug"
            Write-Host "Note: You are playing in offline mode. Online servers will not be accessible." -ForegroundColor Yellow
        } else {
            Write-DebugLog -Message "User authenticated with Microsoft account as $($authStatus.Username)" -Source "GameLauncher" -Level "Debug"
        }

        # Get version information
        $versionDir = Join-Path -Path $versionsPath -ChildPath $Version
        $versionJsonPath = Join-Path -Path $versionDir -ChildPath "$Version.json"
        $versionJarPath = Join-Path -Path $versionDir -ChildPath "$Version.jar"

        Write-DebugLog -Message "Checking version files integrity" -Source "GameLauncher" -Level "Debug"

        # Check if this is a Fabric mod loader profile
        $isFabricProfile = $Version -match "^fabric-"

        if (-not (Test-Path -Path $versionJsonPath)) {
            Write-DebugLog -Message "Version JSON file not found, reinstalling" -Source "GameLauncher" -Level "Warning"
            Write-Host "Version JSON file not found, reinstalling..." -ForegroundColor Yellow
            Install-MinecraftVersion -Version $Version
        }

        # For Fabric mod loader, we don't need to check for the JAR file
        # because Fabric uses the base game JAR file
        if (-not $isFabricProfile -and -not (Test-Path -Path $versionJarPath)) {
            Write-DebugLog -Message "Version JAR file not found, reinstalling" -Source "GameLauncher" -Level "Warning"
            Write-Host "Version JAR file not found, reinstalling..." -ForegroundColor Yellow
            Install-MinecraftVersion -Version $Version
        }

        Write-DebugLog -Message "Loading version information from $versionJsonPath" -Source "GameLauncher" -Level "Debug"
        $versionInfo = Get-Content -Path $versionJsonPath -Raw | ConvertFrom-Json

        # Get Java path
        Write-DebugLog -Message "Getting Java path" -Source "GameLauncher" -Level "Debug"
        $javaPath = Get-JavaPath

        if (-not $javaPath) {
            Write-DebugLog -Message "Java not found" -Source "GameLauncher" -Level "Error"
            Write-Host "Cannot find Java. Please make sure Java is installed" -ForegroundColor Red
            return
        }

        Write-DebugLog -Message "Using Java from: $javaPath" -Source "GameLauncher" -Level "Debug"

        # Get launcher configuration
        $launcherConfig = Get-LauncherConfig
        Write-DebugLog -Message "Using memory settings: Min=$($launcherConfig.MinMemory)MB, Max=$($launcherConfig.MaxMemory)MB" -Source "GameLauncher" -Level "Debug"

        # Build library file path list
        Write-DebugLog -Message "Building library paths list" -Source "GameLauncher" -Level "Debug"
        $libraryPaths = @()
        foreach ($library in $versionInfo.libraries) {
            if ($library.downloads.artifact) {
                $libraryPath = $library.downloads.artifact.path -replace '/', '\'
                $libraryPaths += $libraryPath
            }
        }

        Write-DebugLog -Message "Total libraries: $($libraryPaths.Count)" -Source "GameLauncher" -Level "Debug"

        # Build classpath
        Write-DebugLog -Message "Building classpath" -Source "GameLauncher" -Level "Debug"

        # For Fabric mod loader, we need to use the base game JAR file
        if ($Version -match "^fabric-") {
            # Extract the base Minecraft version from the Fabric profile name
            if ($Version -match "fabric-loader-[\d\.]+-(.+)") {
                $baseVersion = $matches[1]
                Write-DebugLog -Message "Fabric profile detected, using base Minecraft version: $baseVersion" -Source "GameLauncher" -Level "Info"

                # Get the base game JAR path
                $baseVersionDir = Join-Path -Path $versionsPath -ChildPath $baseVersion
                $baseVersionJarPath = Join-Path -Path $baseVersionDir -ChildPath "$baseVersion.jar"

                if (Test-Path -Path $baseVersionJarPath) {
                    Write-DebugLog -Message "Using base game JAR: $baseVersionJarPath" -Source "GameLauncher" -Level "Debug"
                    $versionJarPath = $baseVersionJarPath
                } else {
                    Write-DebugLog -Message "Base game JAR not found: $baseVersionJarPath" -Source "GameLauncher" -Level "Warning"
                    Write-Host "Base game JAR not found. Please make sure Minecraft $baseVersion is installed." -ForegroundColor Yellow

                    # Try to install the base version if it's not installed
                    Write-Host "Do you want to install Minecraft $baseVersion now? (Y/N)" -ForegroundColor Yellow
                    $install = Read-Host

                    if ($install -eq "Y" -or $install -eq "y") {
                        Write-DebugLog -Message "Installing base version $baseVersion" -Source "GameLauncher" -Level "Debug"
                        Install-MinecraftVersion -Version $baseVersion

                        # Check if installation was successful
                        if (Test-Path -Path $baseVersionJarPath) {
                            Write-DebugLog -Message "Base version installed successfully, using JAR: $baseVersionJarPath" -Source "GameLauncher" -Level "Debug"
                            $versionJarPath = $baseVersionJarPath
                        } else {
                            Write-DebugLog -Message "Failed to install base version $baseVersion" -Source "GameLauncher" -Level "Error"
                            Write-Host "Failed to install Minecraft $baseVersion. Cannot launch with Fabric mod loader." -ForegroundColor Red
                            return
                        }
                    } else {
                        Write-DebugLog -Message "User declined to install base version $baseVersion" -Source "GameLauncher" -Level "Info"
                        Write-Host "Cannot launch with Fabric mod loader without the base game. Aborting." -ForegroundColor Red
                        return
                    }
                }
            } else {
                Write-DebugLog -Message "Could not extract base version from Fabric profile name: $Version" -Source "GameLauncher" -Level "Error"
                Write-Host "Could not determine base Minecraft version from Fabric profile. Cannot launch." -ForegroundColor Red
                return
            }
        }

        $classPath = [MinecraftLauncher.GameLauncher]::BuildClassPath($librariesPath, $versionJarPath, $libraryPaths)

        # Build game arguments
        Write-DebugLog -Message "Building game arguments" -Source "GameLauncher" -Level "Debug"
        $gameArgs = @()

        # Add JVM arguments
        $gameArgs += "-Xmx$($launcherConfig.MaxMemory)M"
        $gameArgs += "-Xms$($launcherConfig.MinMemory)M"

        # Add Java agent arguments (if any)
        if ($versionInfo.arguments.jvm) {
            Write-DebugLog -Message "Using modern JVM arguments format" -Source "GameLauncher" -Level "Debug"
            foreach ($arg in $versionInfo.arguments.jvm) {
                if ($arg -is [string]) {
                    $processedArg = $arg
                    $processedArg = $processedArg.Replace('${natives_directory}', (Join-Path -Path $versionDir -ChildPath "natives"))
                    $processedArg = $processedArg.Replace('${launcher_name}', "CLI-Launcher")
                    $processedArg = $processedArg.Replace('${launcher_version}', "1.0")
                    $processedArg = $processedArg.Replace('${classpath}', $classPath)
                    $gameArgs += $processedArg
                    Write-DebugLog -Message "Added JVM arg: $processedArg" -Source "GameLauncher" -Level "Debug"
                }
            }
        }
        else {
            # Legacy version compatibility
            Write-DebugLog -Message "Using legacy JVM arguments format" -Source "GameLauncher" -Level "Debug"
            $nativesPath = Join-Path -Path $versionDir -ChildPath "natives"
            $gameArgs += "-Djava.library.path=$nativesPath"
            $gameArgs += "-cp"
            $gameArgs += "`"$classPath`""
        }

        # Add main class
        Write-DebugLog -Message "Using main class: $($versionInfo.mainClass)" -Source "GameLauncher" -Level "Debug"
        $gameArgs += $versionInfo.mainClass

        # Add game arguments
        if ($versionInfo.arguments.game) {
            Write-DebugLog -Message "Using modern game arguments format" -Source "GameLauncher" -Level "Debug"
            foreach ($arg in $versionInfo.arguments.game) {
                if ($arg -is [string]) {
                    $processedArg = $arg
                    # Get isolated game directory if version isolation is enabled
                    $gameDir = Get-IsolatedGameDirectory -Version $Version -ModLoaderType $ModLoaderType -ModLoaderVersion $ModLoaderVersion

                    # Ensure all isolated directories exist
                    Ensure-IsolatedDirectories -Version $Version -ModLoaderType $ModLoaderType -ModLoaderVersion $ModLoaderVersion

                    $processedArg = $processedArg.Replace('${auth_player_name}', $authStatus.Username)
                    $processedArg = $processedArg.Replace('${version_name}', $Version)
                    $processedArg = $processedArg.Replace('${game_directory}', $gameDir)
                    $processedArg = $processedArg.Replace('${assets_root}', $assetsPath)
                    $processedArg = $processedArg.Replace('${assets_index_name}', $versionInfo.assetIndex.id)
                    $processedArg = $processedArg.Replace('${auth_uuid}', $authStatus.UUID)
                    $processedArg = $processedArg.Replace('${auth_access_token}', $authStatus.AccessToken)
                    $processedArg = $processedArg.Replace('${user_type}', "msa")
                    $processedArg = $processedArg.Replace('${version_type}', $versionInfo.type)
                    $gameArgs += $processedArg
                }
            }
        }
        else {
            # Legacy version compatibility
            Write-DebugLog -Message "Using legacy game arguments format" -Source "GameLauncher" -Level "Debug"
            # Get isolated game directory if version isolation is enabled
            $gameDir = Get-IsolatedGameDirectory -Version $Version -ModLoaderType $ModLoaderType -ModLoaderVersion $ModLoaderVersion

            # Ensure all isolated directories exist
            Ensure-IsolatedDirectories -Version $Version -ModLoaderType $ModLoaderType -ModLoaderVersion $ModLoaderVersion

            $gameArgs += "--username"
            $gameArgs += $authStatus.Username
            $gameArgs += "--version"
            $gameArgs += $Version
            $gameArgs += "--gameDir"
            $gameArgs += $gameDir
            $gameArgs += "--assetsDir"
            $gameArgs += $assetsPath
            $gameArgs += "--assetIndex"
            $gameArgs += $versionInfo.assetIndex.id
            $gameArgs += "--uuid"
            $gameArgs += $authStatus.UUID
            $gameArgs += "--accessToken"
            $gameArgs += $authStatus.AccessToken
            $gameArgs += "--userType"
            $gameArgs += "msa"
            $gameArgs += "--versionType"
            $gameArgs += $versionInfo.type
        }

        # Launch game
        Write-DebugLog -Message "Launching game with Java: $javaPath" -Source "GameLauncher" -Level "Info"
        Write-Host "Launching Minecraft $Version..." -ForegroundColor Green

        # Debug mode: show command line
        $config = Get-LauncherConfig
        if ($config.DebugMode) {
            $commandLine = "$javaPath " + ($gameArgs -join " ")
            Write-DebugLog -Message "Command line: $commandLine" -Source "GameLauncher" -Level "Debug"
        }

        # Set up log file path
        $gameLogPath = Join-Path -Path $configPath -ChildPath "game.log"
        Write-DebugLog -Message "Game log will be saved to: $gameLogPath" -Source "GameLauncher" -Level "Info"

        # Launch game with log redirection
        $process = [MinecraftLauncher.GameLauncher]::LaunchGame($javaPath, $gameArgs, $gameLogPath)

        Write-DebugLog -Message "Game launched with process ID: $($process.Id)" -Source "GameLauncher" -Level "Info"
        Write-Host "Game launched, process ID: $($process.Id)" -ForegroundColor Cyan
        Write-Host "Game log is being saved to: $gameLogPath" -ForegroundColor Cyan

        # Record last launched version
        $launcherConfig.LastVersion = $Version
        Save-LauncherConfig -Config $launcherConfig

        # If debug mode is enabled, wait for the process to exit
        if ($config.DebugMode) {
            try {
                Write-Host "Debug mode is enabled. Press Ctrl+C to return to launcher..." -ForegroundColor Yellow
                # Wait for the process to exit or for user to press Ctrl+C
                $process.WaitForExit()
                Write-Host "Game process has exited with code: $($process.ExitCode)" -ForegroundColor Cyan
            }
            catch {
                Write-DebugLog -Message "Error waiting for game process: $($_.Exception.Message)" -Source "GameLauncher" -Level "Warning"
            }
        }
    }
    catch {
        Write-DebugLog -Message "Error launching game: $($_.Exception.Message)" -Source "GameLauncher" -Level "Error"
        Handle-Error -ErrorRecord $_ -Source "GameLauncher" -CustomMessage "Error launching game"
    }
}

# Get Java path
function Get-JavaPath {
    Write-DebugLog -Message "Searching for Java installation" -Source "GameLauncher" -Level "Debug"

    # First check Java path in configuration
    $launcherConfig = Get-LauncherConfig
    if ($launcherConfig.JavaPath -and (Test-Path -Path $launcherConfig.JavaPath)) {
        Write-DebugLog -Message "Using Java from configuration: $($launcherConfig.JavaPath)" -Source "GameLauncher" -Level "Debug"
        return $launcherConfig.JavaPath
    }

    # Check environment variables
    $javaHome = $env:JAVA_HOME
    if ($javaHome -and (Test-Path -Path $javaHome)) {
        $javaPath = Join-Path -Path $javaHome -ChildPath "bin\java.exe"
        if (Test-Path -Path $javaPath) {
            Write-DebugLog -Message "Using Java from JAVA_HOME: $javaPath" -Source "GameLauncher" -Level "Debug"
            return $javaPath
        }
    }

    # Look for Java in PATH
    try {
        $javaPath = Get-Command -Name java -ErrorAction SilentlyContinue
        if ($javaPath) {
            Write-DebugLog -Message "Using Java from PATH: $($javaPath.Source)" -Source "GameLauncher" -Level "Debug"
            return $javaPath.Source
        }
    }
    catch {
        Write-DebugLog -Message "Java not found in PATH" -Source "GameLauncher" -Level "Debug"
    }

    # Look for Java in common locations
    Write-DebugLog -Message "Searching for Java in common locations" -Source "GameLauncher" -Level "Debug"
    $commonPaths = @(
        "C:\Program Files\Java\*\bin\java.exe",
        "C:\Program Files (x86)\Java\*\bin\java.exe"
    )

    foreach ($path in $commonPaths) {
        try {
            $javaPaths = Resolve-Path -Path $path -ErrorAction SilentlyContinue
            if ($javaPaths) {
                Write-DebugLog -Message "Found Java in common location: $($javaPaths[0].Path)" -Source "GameLauncher" -Level "Debug"
                return $javaPaths[0].Path
            }
        }
        catch {
            Write-DebugLog -Message "Error searching path $path" -Source "GameLauncher" -Level "Debug"
        }
    }

    Write-DebugLog -Message "No Java installation found" -Source "GameLauncher" -Level "Warning"
    return $null
}

# CLI-Launcher

A simple Minecraft launcher implemented using PowerShell and embedded C#.

## Features

- Microsoft account authentication with offline mode support
  - Note: Microsoft authentication is not available now...
  - You can still use offline mode to play without Microsoft authentication
- Account management with multiple account support
  - Switch between different accounts without re-entering credentials
  - Add multiple accounts (both Microsoft and offline)
  - Delete accounts you no longer need
  - Support for both Microsoft and offline accounts
- Minecraft version management (download and installation)
  - Automatic detection and synchronization of installed versions
  - Multi-threaded download support for faster installation
  - Mirror download support for faster downloads in different regions
- Game launching
- Configuration management
- Debug mode for troubleshooting

## Usage

1. Make sure PowerShell 5.1 or higher is installed
2. Make sure .NET Framework 4.7.2 or higher is installed
3. Make sure Java is installed (Java 8 or higher recommended)
4. Run the `MinecraftLauncher.ps1` script

```powershell
.\MinecraftLauncher.ps1
```

## File Structure

- `MinecraftLauncher.ps1` - Main launcher script
- `Modules/` - Functional modules
  - `Authentication.ps1` - Handles Microsoft account authentication
  - `VersionManager.ps1` - Manages Minecraft versions
  - `GameLauncher.ps1` - Handles game launching
  - `ConfigManager.ps1` - Manages configuration and settings
  - `UI.ps1` - User interface functionality
- `Config/` - Configuration folder
  - `config.json` - Launcher configuration
  - `auth.json` - Authentication information (created automatically after login)
  - `accounts.json` - Saved accounts list (created automatically when logging in)
  - `installed.json` - List of installed versions (created automatically after installing versions)
- `Minecraft/` - Minecraft game files
  - `versions/` - Game versions
  - `libraries/` - Game library files
  - `assets/` - Game asset files

## Notes

- The launcher will automatically download the selected Minecraft version and its dependencies
- You can adjust memory allocation and Java path in the settings
- Multi-threaded download can be enabled/disabled in the settings menu
  - When enabled, you can configure the maximum number of concurrent download threads (4-32)
  - This significantly improves download speed for game files, especially on fast connections
- Debug mode can be enabled in the settings menu to help troubleshoot issues
  - When enabled, detailed logs are displayed and errors don't automatically return to the menu
  - All logs are saved to `Config/launcher.log` regardless of debug mode status
- Game logs are saved to `Config/game.log` but not displayed in the console

## References

- [PCL2 (Plain Craft Launcher 2)](https://github.com/Hex-Dragon/PCL2)
- [Minecraft Official Launcher](https://www.minecraft.net/)

## Open Source

This project is open source and available under the [GNU GPLv3 license](LICENSE).

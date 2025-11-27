# LBAutoLaunch.ps1

A PowerShell script that monitors system idle time and automatically manages LaunchBox/BigBox processes and other applications. When the system is idle, it closes specified processes and activates the screensaver. When activity is detected, it restores BigBox and optionally restarts other configured processes.

## Features

- 🎮 Monitors system idle time
- 🔄 Automatically closes LaunchBox/BigBox and other processes during idle
- 🖥️ Activates screensaver when idle threshold is reached
- ⚡ Automatically restores BigBox when user returns
- 📊 Clean, timestamped logging with color-coded messages
- ⚙️ Highly configurable process management

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- LaunchBox/BigBox installed
- Administrator privileges (recommended for process management)

## Installation

1. Clone or download this repository
2. Open `LBAutoLaunch.ps1` in a text editor
3. Configure the script according to your needs (see Configuration section)

## Configuration

### Basic Settings

Edit the configuration section at the top of the script:

```powershell
# Idle time threshold to trigger actions (in seconds)
$idleThresholdSeconds = 180

# BigBox.exe path
$bigBoxPath = "C:\emu\LaunchBox\BigBox.exe"

# Check interval (in seconds)
$checkIntervalSeconds = 5
```

### Process Management

#### Processes to Close During Idle

Edit the `$procsToKill` array to specify which processes should be closed when idle:

```powershell
$procsToKill = @(
    "LaunchBox",
    "BigBox",
    "brave"            # Brave Browser
    # Add more processes here
)
```

**⚠️ Important: Array Syntax**

When editing arrays in PowerShell, pay attention to commas:
- **Items in the middle** must have a comma at the end: `"LaunchBox",`
- **The last item** should NOT have a comma: `"brave"` (not `"brave",`)

**Correct example:**
```powershell
$procsToKill = @(
    "LaunchBox",      # ✅ Comma here
    "BigBox",         # ✅ Comma here
    "brave"           # ✅ NO comma on last item
)
```

**Incorrect example:**
```powershell
$procsToKill = @(
    "LaunchBox",      # ✅ Comma here
    "BigBox",         # ✅ Comma here
    "brave",          # ❌ Extra comma on last item - will cause syntax error!
)
```

#### Optional Processes to Restart

Configure processes that should be restarted when the user returns:

```powershell
$procsToRestart = @(
    # "Discord",          # Restart Discord when returning
    # "Steam",            # Restart Steam when returning
)
```

**⚠️ Same comma rule applies here!** The last item should not have a comma.

If you need to specify custom paths for restarting processes:

```powershell
$procPathsToRestart = @{
    "Discord" = "C:\Users\$env:USERNAME\AppData\Local\Discord\Update.exe"
    "Steam" = "C:\Program Files (x86)\Steam\steam.exe"
}
```

## Usage

### Manual Execution

1. Open PowerShell (as Administrator recommended)
2. Navigate to the script directory
3. Run the script:

```powershell
.\LBAutoLaunch.ps1
```

### Running with Execution Policy

If you encounter execution policy errors, run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then run the script again.

## Auto-Start on Windows Boot

To make the script run automatically when Windows starts, you can add it to the Startup folder.

### Method 1: Using Startup Folder (Recommended)

1. Press `Win + R` to open the Run dialog
2. Type `shell:startup` and press Enter
   - This opens your user's Startup folder: `C:\Users\YourUsername\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup`
3. Create a shortcut to the PowerShell script:
   - Right-click in the Startup folder
   - Select "New" → "Shortcut"
   - Browse to your `LBAutoLaunch.ps1` file
   - Click "Next" and give it a name (e.g., "LBAutoLaunch")
   - Click "Finish"

4. **Important:** Edit the shortcut properties:
   - Right-click the shortcut → "Properties"
   - In the "Target" field, change it to:
     ```
     powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "Z:\LBAutoLaunch.ps1"
     ```
     (Replace `Z:\LBAutoLaunch.ps1` with your actual script path)
   - Click "OK"

### Method 2: Using Task Scheduler (Advanced)

1. Open Task Scheduler (`Win + R` → `taskschd.msc`)
2. Click "Create Basic Task" in the right panel
3. Name it "LBAutoLaunch" and click "Next"
4. Select "When I log on" and click "Next"
5. Select "Start a program" and click "Next"
6. Configure:
   - **Program/script:** `powershell.exe`
   - **Add arguments:** `-WindowStyle Hidden -ExecutionPolicy Bypass -File "Z:\LBAutoLaunch.ps1"`
   - (Replace with your actual script path)
7. Click "Next" → "Finish"

### Method 3: Using Registry (PowerShell)

Run this in PowerShell (as Administrator):

```powershell
$scriptPath = "Z:\LBAutoLaunch.ps1"  # Change to your script path
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "LBAutoLaunch"
$regValue = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

Set-ItemProperty -Path $regPath -Name $regName -Value $regValue
```

To remove the auto-start later:

```powershell
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "LBAutoLaunch"
```

## How It Works

1. **Monitoring:** The script continuously monitors system idle time (time since last user input)
2. **Idle Detection:** When idle time exceeds the threshold (default: 180 seconds):
   - Closes all configured processes (LaunchBox, BigBox, browsers, etc.)
   - Activates the screensaver
3. **Activity Detection:** When user activity is detected:
   - Closes the screensaver
   - Restarts BigBox
   - Optionally restarts other configured processes

## Logging

The script provides detailed logging with timestamps and color-coded messages:

- **INFO** (White): General information
- **SUCCESS** (Green): Successful operations
- **WARNING** (Yellow): Warnings (e.g., process already running)
- **ERROR** (Red): Errors that occurred
- **STATUS** (Cyan): Real-time idle status

## Troubleshooting

### Script won't start
- Check PowerShell execution policy: `Get-ExecutionPolicy`
- Run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Processes not closing
- Ensure you're running PowerShell as Administrator
- Verify process names are correct (without .exe extension)
- Check if processes have special permissions

### BigBox not restarting
- Verify the `$bigBoxPath` is correct
- Check if BigBox.exe exists at the specified path
- Review error messages in the console

### Syntax errors in arrays
- Remember: **NO comma after the last item** in PowerShell arrays
- Check for missing commas between items (except the last one)

## Example Configuration

```powershell
# Close these during idle
$procsToKill = @(
    "LaunchBox",
    "BigBox",
    "brave",
    "Discord",
    "Steam"
)

# Restart these when user returns
$procsToRestart = @(
    "Discord",
    "Steam"
)

# Paths for restarting
$procPathsToRestart = @{
    "Discord" = "C:\Users\$env:USERNAME\AppData\Local\Discord\Update.exe"
    "Steam" = "C:\Program Files (x86)\Steam\steam.exe"
}
```

## License

This script is provided as-is for personal use. Feel free to modify and adapt it to your needs.

## Contributing

Contributions, suggestions, and improvements are welcome!

## Notes

- The script runs in an infinite loop - close the PowerShell window to stop it
- For best results, run as Administrator to ensure all processes can be managed
- Test your configuration before setting up auto-start to avoid issues at boot

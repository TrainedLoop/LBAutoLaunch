# IdleLaunchBox.ps1 (clean logs + screensaver + reopen BigBox)
# ==============================================================

# ===== CONFIGURATION =====
# Idle time threshold to trigger actions (in seconds)
$idleThresholdSeconds = 180

# Processes to close during idle (without .exe)
# Add or remove processes as needed
$procsToKill = @(
    "LaunchBox",
    "BigBox"
    # Browsers (save a lot of RAM)
    # "chrome",           # Google Chrome
    # "msedge",           # Microsoft Edge
    # "firefox",          # Mozilla Firefox
    "brave",            # Brave Browser
    
    # Communication apps
    # "Discord",          # Discord
    # "Teams",            # Microsoft Teams
    # "skype",            # Skype
    
    # Gaming platforms
    # "Steam",            # Steam (if not in use)
    # "EpicGamesLauncher", # Epic Games Launcher
    
    # Streaming/capture apps
    # "obs64",            # OBS Studio (64-bit)
    # "obs32",            # OBS Studio (32-bit)
    # "xsplit",           # XSplit
    
    # Media apps
    # "vlc",              # VLC Media Player
    # "wmplayer",         # Windows Media Player
    
    # Other resource-consuming apps
    # "Spotify",          # Spotify
    # "notepad++",        # Notepad++
    # "code",             # Visual Studio Code
)

# Optional processes to restart when user returns
# Leave empty if you don't want to restart anything besides BigBox
$procsToRestart = @(
    # "Discord",          # Restart Discord when returning
    # "Steam",            # Restart Steam when returning
)

# Executable paths for restarting (hash table: process name = path)
$procPathsToRestart = @{
    # "Discord" = "C:\Users\$env:USERNAME\AppData\Local\Discord\Update.exe"
    # "Steam" = "C:\Program Files (x86)\Steam\steam.exe"
}

# BigBox.exe path
$bigBoxPath = "C:\emu\LaunchBox\BigBox.exe"

# Check interval (in seconds)
$checkIntervalSeconds = 5

# Wait time after starting processes (in seconds)
$bigBoxStartWaitSeconds = 2
$procRestartWaitSeconds = 3

# ===== LOG FUNCTIONS =====
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$NoNewline
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "INFO"  { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "STATUS" { "Cyan" }
        default { "White" }
    }
    
    $prefix = "[$timestamp] [$Level]"
    if ($NoNewline) {
        Write-Host "$prefix $Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

function Write-StatusLine {
    param(
        [int]$IdleSeconds,
        [string]$State
    )
    $status = "Idle: {0,4} s | State: {1}" -f $IdleSeconds, $State
    Write-Host "`r$status" -NoNewline -ForegroundColor Cyan
}

# ===== IDLE HELPER INITIALIZATION =====
if (-not ("IdleHelper" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class IdleHelper {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public static uint GetIdleTimeSeconds() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (!GetLastInputInfo(ref lii)) {
            return 0;
        }

        uint tickNow = (uint)Environment.TickCount;
        uint idleTicks = tickNow - lii.dwTime;
        return idleTicks / 1000;
    }
}
"@
}

# ===== SCREENSAVER FUNCTIONS =====
function Start-CustomScreenSaver {
    # Try to get the screensaver configured for current user
    $ss = (Get-ItemProperty "HKCU:\Control Panel\Desktop" -ErrorAction SilentlyContinue).SCRNSAVE.EXE

    if ([string]::IsNullOrWhiteSpace($ss)) {
        # If no screensaver is configured, use Mystify
        $ss = "$env:WINDIR\System32\Mystify.scr"
    }

    Write-Log "Starting screensaver: $ss" -Level "INFO"

    if (Test-Path $ss) {
        Start-Process -FilePath $ss -ArgumentList "/s" -ErrorAction SilentlyContinue
        Write-Log "Screensaver started successfully" -Level "SUCCESS"
    } else {
        Write-Log "Screensaver file not found: $ss" -Level "ERROR"
    }
}

function Stop-CustomScreenSaver {
    # Find which screensaver is configured or use Mystify
    $ss = (Get-ItemProperty "HKCU:\Control Panel\Desktop" -ErrorAction SilentlyContinue).SCRNSAVE.EXE
    if ([string]::IsNullOrWhiteSpace($ss)) {
        $ss = "$env:WINDIR\System32\Mystify.scr"
    }

    $procName = [System.IO.Path]::GetFileNameWithoutExtension($ss)

    Write-Log "Stopping screensaver: $procName" -Level "INFO"

    $stopped = Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue -PassThru
    
    if ($stopped) {
        Write-Log "Screensaver stopped successfully" -Level "SUCCESS"
    }
}

# ===== PROCESS FUNCTIONS =====
function Stop-Processes {
    param([string[]]$ProcessNames)
    
    foreach ($procName in $ProcessNames) {
        Write-Log "Closing process: $procName" -Level "INFO"
        $stopped = Get-Process -Name $procName -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue -PassThru
        
        if ($stopped) {
            Write-Log "Process '$procName' closed successfully" -Level "SUCCESS"
        } else {
            Write-Log "Process '$procName' was not running" -Level "WARNING"
        }
    }
}

function Start-BigBox {
    if (-not (Test-Path $bigBoxPath)) {
        Write-Log "BigBox path invalid or not found: $bigBoxPath" -Level "ERROR"
        return $false
    }

    # Check if BigBox process already exists
    $bbProc = Get-Process -Name "BigBox" -ErrorAction SilentlyContinue

    if ($bbProc) {
        Write-Log "BigBox is already running (PID: $($bbProc.Id))" -Level "WARNING"
        return $true
    }

    Write-Log "Starting BigBox..." -Level "INFO"
    
    try {
        Start-Process -FilePath $bigBoxPath -ErrorAction Stop
        Start-Sleep -Seconds $bigBoxStartWaitSeconds

        # Check if process was started
        $bbProc = Get-Process -Name "BigBox" -ErrorAction SilentlyContinue
        if ($bbProc) {
            Write-Log "BigBox started successfully (PID: $($bbProc.Id))" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "BigBox was not started (process not found after $bigBoxStartWaitSeconds seconds)" -Level "ERROR"
            return $false
        }
    } catch {
        Write-Log "Error starting BigBox: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Start-OptionalProcesses {
    if ($procsToRestart.Count -eq 0) {
        return
    }

    Write-Log "Checking optional processes to restart..." -Level "INFO"
    
    foreach ($procName in $procsToRestart) {
        # Check if process is already running
        $existingProc = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($existingProc) {
            Write-Log "Process '$procName' is already running (PID: $($existingProc.Id))" -Level "WARNING"
            continue
        }

        # Try to find the executable path
        $procPath = $null
        
        # First check if there's a configured path
        if ($procPathsToRestart.ContainsKey($procName)) {
            $procPath = $procPathsToRestart[$procName]
        } else {
            # Try to find automatically in PATH or common locations
            $procPath = Get-Command $procName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        }

        if ($procPath -and (Test-Path $procPath)) {
            Write-Log "Starting optional process: $procName" -Level "INFO"
            try {
                Start-Process -FilePath $procPath -ErrorAction Stop
                Start-Sleep -Seconds $procRestartWaitSeconds
                
                $startedProc = Get-Process -Name $procName -ErrorAction SilentlyContinue
                if ($startedProc) {
                    Write-Log "Process '$procName' started successfully (PID: $($startedProc.Id))" -Level "SUCCESS"
                } else {
                    Write-Log "Process '$procName' was not started (not found after $procRestartWaitSeconds seconds)" -Level "WARNING"
                }
            } catch {
                Write-Log "Error starting '$procName': $($_.Exception.Message)" -Level "ERROR"
            }
        } else {
            Write-Log "Process '$procName' path not found. Configure in `$procPathsToRestart or add to PATH" -Level "WARNING"
        }
    }
}

# ===== INITIALIZATION =====
$alreadyTriggered = $false
$state = "WAITING"

Clear-Host
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  IDLE Monitor - LaunchBox" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Log "Monitor started" -Level "INFO"
Write-Log "Idle threshold: $idleThresholdSeconds seconds" -Level "INFO"
Write-Log "Check interval: $checkIntervalSeconds seconds" -Level "INFO"
Write-Log "BigBox path: $bigBoxPath" -Level "INFO"
Write-Log "Processes to close during idle: $($procsToKill -join ', ')" -Level "INFO"
if ($procsToRestart.Count -gt 0) {
    Write-Log "Optional processes to restart: $($procsToRestart -join ', ')" -Level "INFO"
} else {
    Write-Log "No optional processes configured for restart" -Level "INFO"
}
Write-Host "`nWaiting for inactivity...`n" -ForegroundColor Gray

# ===== MAIN LOOP =====
while ($true) {
    $idle = [IdleHelper]::GetIdleTimeSeconds()
    
    # Display status on the same line
    Write-StatusLine -IdleSeconds $idle -State $state

    # Detect inactivity and trigger actions
    if (($idle -ge $idleThresholdSeconds) -and (-not $alreadyTriggered)) {
        $state = "IDLE/TRIGGERED"
        Write-Host "" # New line after status
        Write-Log "Inactivity detected! (idle >= $idleThresholdSeconds seconds)" -Level "INFO"
        Write-Host ""

        # 1) Close processes
        Stop-Processes -ProcessNames $procsToKill

        # 2) Activate screensaver
        Start-CustomScreenSaver

        $alreadyTriggered = $true
        Write-Log "State changed to: TRIGGERED" -Level "INFO"
        Write-Host ""
    }
    # Detect activity and restore
    elseif (($idle -lt $idleThresholdSeconds) -and $alreadyTriggered) {
        $state = "ACTIVE"
        Write-Host "" # New line after status
        Write-Log "Activity detected! User returned." -Level "INFO"
        Write-Host ""

        # 1) Close screensaver
        Stop-CustomScreenSaver

        # 2) Reopen BigBox if needed
        Start-BigBox | Out-Null

        # 3) Restart optional configured processes
        if ($procsToRestart.Count -gt 0) {
            Start-OptionalProcesses
        }

        Write-Log "State reset to: WAITING" -Level "INFO"
        Write-Host ""
        
        $alreadyTriggered = $false
        $state = "WAITING"
    }

    Start-Sleep -Seconds $checkIntervalSeconds
}

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
    "brave"            # Brave Browser
    
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

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, int dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const uint MOUSEEVENTF_MOVE = 0x0001;
    public const uint WM_KEYDOWN = 0x0100;
    public const uint WM_KEYUP = 0x0101;
    public const byte VK_ESCAPE = 0x1B;

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

    public static void ForceExitScreenSaver() {
        // Method 1: Simulate mouse movement
        mouse_event(MOUSEEVENTF_MOVE, 1, 1, 0, 0);
        System.Threading.Thread.Sleep(10);
        mouse_event(MOUSEEVENTF_MOVE, -1, -1, 0, 0);

        // Method 2: Send ESC key
        keybd_event(VK_ESCAPE, 0, 0, 0);
        System.Threading.Thread.Sleep(10);
        keybd_event(VK_ESCAPE, 0, KEYEVENTF_KEYUP, 0);

        // Method 3: Try to find screensaver window and send message
        IntPtr hWnd = FindWindow("WindowsScreenSaverClass", null);
        if (hWnd != IntPtr.Zero) {
            PostMessage(hWnd, WM_KEYDOWN, new IntPtr(VK_ESCAPE), IntPtr.Zero);
            PostMessage(hWnd, WM_KEYUP, new IntPtr(VK_ESCAPE), IntPtr.Zero);
        }
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
    Write-Log "Forcing screensaver exit..." -Level "INFO"

    # Method 1: Use Windows API to force exit (simulate mouse/keyboard)
    try {
        [IdleHelper]::ForceExitScreenSaver()
        Start-Sleep -Milliseconds 100
    } catch {
        Write-Log "Error using API method: $($_.Exception.Message)" -Level "WARNING"
    }

    # Method 2: Find and kill screensaver process
    $ss = (Get-ItemProperty "HKCU:\Control Panel\Desktop" -ErrorAction SilentlyContinue).SCRNSAVE.EXE
    if ([string]::IsNullOrWhiteSpace($ss)) {
        $ss = "$env:WINDIR\System32\Mystify.scr"
    }

    $procName = [System.IO.Path]::GetFileNameWithoutExtension($ss)

    # Try to stop the screensaver process
    $stopped = Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue -PassThru
    
    # Also try common screensaver process names
    $commonScreensavers = @("scrnsave", "Mystify", "Bubbles", "Ribbons", "FlowerBox")
    foreach ($commonName in $commonScreensavers) {
        $proc = Get-Process -Name $commonName -ErrorAction SilentlyContinue
        if ($proc) {
            Stop-Process -Name $commonName -Force -ErrorAction SilentlyContinue
            Write-Log "Stopped screensaver process: $commonName" -Level "INFO"
        }
    }

    # Method 3: Send ESC key using PowerShell
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
        Start-Sleep -Milliseconds 50
    } catch {
        # Ignore if SendKeys fails
    }

    Write-Log "Screensaver exit forced" -Level "SUCCESS"
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

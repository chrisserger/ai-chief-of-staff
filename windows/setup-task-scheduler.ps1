# setup-task-scheduler.ps1 — Creates a Windows Task Scheduler job for the morning routine
#
# Equivalent of the macOS launchd plist. Runs run-morning-routine.sh daily at 6 AM.
#
# Usage: Run from an elevated (admin) PowerShell:
#   powershell -ExecutionPolicy Bypass -File windows\setup-task-scheduler.ps1
#
# To remove:
#   Unregister-ScheduledTask -TaskName "AICOS Morning Routine" -Confirm:$false

param(
    [string]$Time = "06:00AM",
    [string]$TaskName = "AICOS Morning Routine"
)

$ErrorActionPreference = "Stop"

# Determine repo path from script location
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoPath = Split-Path -Parent $scriptDir

# Find bash.exe
$bashPaths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    (Get-Command bash -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
)

$bashExe = $null
foreach ($path in $bashPaths) {
    if ($path -and (Test-Path $path)) {
        $bashExe = $path
        break
    }
}

if (-not $bashExe) {
    Write-Error "Could not find bash.exe. Install Git for Windows first."
    exit 1
}

Write-Host "AI Chief of Staff — Task Scheduler Setup" -ForegroundColor Cyan
Write-Host "=========================================="
Write-Host ""
Write-Host "  Repo path: $repoPath"
Write-Host "  Bash:      $bashExe"
Write-Host "  Schedule:  Daily at $Time"
Write-Host ""

# Convert Windows path to Git Bash path for the cd command
$gitBashRepo = "/" + ($repoPath -replace "\\", "/" -replace "^([A-Za-z]):", { $_.Groups[1].Value.ToLower() })

$arguments = "-l -c `"cd '$gitBashRepo' && bash scripts/run-morning-routine.sh >> logs/morning-routine.log 2>&1`""

$action = New-ScheduledTaskAction -Execute $bashExe -Argument $arguments -WorkingDirectory $repoPath
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
$settings = New-ScheduledTaskSettingsSet `
    -WakeToRun `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

# Check if task already exists
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "  Task '$TaskName' already exists — updating..." -ForegroundColor Yellow
    Set-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings | Out-Null
} else {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Description "AI Chief of Staff morning brief generation — runs Granola sync, Slack scan, Gmail scan, and Claude CLI daily note writer." | Out-Null
}

Write-Host ""
Write-Host "  Task '$TaskName' registered." -ForegroundColor Green
Write-Host ""
Write-Host "  To test now:  schtasks /Run /TN `"$TaskName`""
Write-Host "  To remove:    Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
Write-Host "  To view logs: Get-Content $repoPath\logs\morning-routine.log -Tail 50"

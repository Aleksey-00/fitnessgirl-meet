# Register a Windows logon task that wakes WSL and starts the Telegram bridge.
# Run once from PowerShell (current user is enough):
#   powershell -ExecutionPolicy Bypass -File scripts\install-windows-tg-bridge-task.ps1

$ErrorActionPreference = 'Stop'
$taskName = 'FitnessgirlTelegramBridge'
$arg = '-u aazor -- bash -lc "systemctl --user start fg-telegram-bridge.service"'

$action = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument $arg
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask `
  -TaskName $taskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Description 'Wake WSL and start Fitnessgirl Telegram bridge on Windows logon' `
  -Force | Out-Null

Write-Host "OK: scheduled task '$taskName' (AtLogOn)"
Write-Host "Test now:  schtasks /Run /TN `"$taskName`""
Write-Host "Remove:     Unregister-ScheduledTask -TaskName `"$taskName`" -Confirm:`$false"

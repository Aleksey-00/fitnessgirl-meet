# Wake WSL and ensure the home daily indexer timer is active after Windows logon.
# Run once:
#   powershell -ExecutionPolicy Bypass -File scripts\install-windows-indexer-task.ps1

$ErrorActionPreference = 'Stop'
$taskName = 'FitnessgirlIndexerDaily'
$arg = '-u aazor -- bash -lc "systemctl --user start fg-indexer-daily.timer"'

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
  -Description 'Wake WSL and keep Fitnessgirl home daily VK indexer timer active' `
  -Force | Out-Null

Write-Host "OK: scheduled task '$taskName' (AtLogOn)"

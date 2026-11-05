# Keep the home → prod daily VK indexer alive on this Windows PC.
# - At logon: wake WSL and enable the systemd midnight timer
# - Daily 00:00: start one both-sexes run into the production DB
#
# Run once (Admin not required for current-user tasks):
#   powershell -ExecutionPolicy Bypass -File scripts\install-windows-indexer-task.ps1

$ErrorActionPreference = 'Stop'

function Register-FgTask {
  param(
    [string]$TaskName,
    [string]$Argument,
    [object[]]$Triggers,
    [string]$Description
  )
  $action = New-ScheduledTaskAction -Execute 'wsl.exe' -Argument $Argument
  $settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -WakeToRun `
    -ExecutionTimeLimit ([TimeSpan]::FromHours(3))
  Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $Triggers `
    -Settings $settings `
    -Description $Description `
    -Force | Out-Null
  Write-Host "OK: scheduled task '$TaskName'"
}

# Ensure timer is armed whenever the user logs in (WSL/systemd may have been cold).
Register-FgTask `
  -TaskName 'FitnessgirlIndexerDailyTimer' `
  -Argument '-u aazor -- bash -lc "systemctl --user daemon-reload; systemctl --user enable --now fg-indexer-daily.timer; systemctl --user list-timers fg-indexer-daily.timer --no-pager"' `
  -Triggers @(New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) `
  -Description 'Wake WSL and arm Fitnessgirl midnight daily VK indexer timer'

# Hard trigger at local midnight: one both-sexes batch → prod (flock prevents double with systemd).
$midnight = New-ScheduledTaskTrigger -Daily -At '12:00AM'
Register-FgTask `
  -TaskName 'FitnessgirlIndexerDailyRun' `
  -Argument '-u aazor -- bash -lc "systemctl --user start fg-indexer-daily.service"' `
  -Triggers @($midnight) `
  -Description 'Run Fitnessgirl both-sexes daily VK index into prod at 00:00'

# Drop legacy single-task name if present.
Unregister-ScheduledTask -TaskName 'FitnessgirlIndexerDaily' -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "Daily index: women+men → prod DB every night at 00:00 (home IP, SSH tunnel)."

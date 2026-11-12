# Keep the home → prod daily VK indexer alive on this Windows PC.
# - At logon: wake WSL and enable the systemd midnight timer
# - Daily 23:00: probe VK token; if dead, toast + open classic OAuth URL
# - Daily 00:00: start one both-sexes run into the production DB
#
# Run once (Admin not required for current-user tasks):
#   powershell -ExecutionPolicy Bypass -File scripts\install-windows-indexer-task.ps1

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RenewPs1 = Join-Path $ScriptDir 'vk-pre-midnight-renew-check.ps1'

function Register-FgTask {
  param(
    [string]$TaskName,
    [string]$Execute,
    [string]$Argument,
    [object[]]$Triggers,
    [string]$Description,
    [TimeSpan]$Limit = ([TimeSpan]::FromHours(3))
  )
  $action = New-ScheduledTaskAction -Execute $Execute -Argument $Argument
  $settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -WakeToRun `
    -ExecutionTimeLimit $Limit
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
  -Execute 'wsl.exe' `
  -Argument '-u aazor -- bash -lc "systemctl --user daemon-reload; systemctl --user enable --now fg-indexer-daily.timer; systemctl --user list-timers fg-indexer-daily.timer --no-pager"' `
  -Triggers @(New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) `
  -Description 'Wake WSL and arm Fitnessgirl midnight daily VK indexer timer'

# ~23:00 — renew reminder before midnight index (opens classic OAuth if token dead).
$at23 = New-ScheduledTaskTrigger -Daily -At '11:00PM'
Register-FgTask `
  -TaskName 'FitnessgirlVkTokenRenewCheck' `
  -Execute 'powershell.exe' `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$RenewPs1`"" `
  -Triggers @($at23) `
  -Description '23:00 probe VK token; toast + open classic blank.html OAuth if renew needed' `
  -Limit ([TimeSpan]::FromMinutes(15))

# Hard trigger at local midnight: one both-sexes batch → prod (flock prevents double with systemd).
$midnight = New-ScheduledTaskTrigger -Daily -At '12:00AM'
Register-FgTask `
  -TaskName 'FitnessgirlIndexerDailyRun' `
  -Execute 'wsl.exe' `
  -Argument '-u aazor -- bash -lc "systemctl --user start fg-indexer-daily.service"' `
  -Triggers @($midnight) `
  -Description 'Run Fitnessgirl both-sexes daily VK index into prod at 00:00'

# Drop legacy single-task name if present.
Unregister-ScheduledTask -TaskName 'FitnessgirlIndexerDaily' -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "Daily: 23:00 VK renew check → 00:00 both-sexes index (home IP → prod DB)."

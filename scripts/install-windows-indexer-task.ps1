# Keep the home -> prod daily VK indexer alive on this Windows PC.
# - At logon: wake WSL and enable the systemd midnight timer
# - Daily 23:00: probe VK token; if dead, renew via Google Chrome classic OAuth
# - Daily 00:00: token guard then both-sexes run into the production DB
#
# Run once (Admin not required for current-user tasks):
#   powershell -ExecutionPolicy Bypass -File scripts\install-windows-indexer-task.ps1

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RenewPs1 = Join-Path $ScriptDir 'vk-pre-midnight-renew-check.ps1'
$DailyGuardPs1 = Join-Path $ScriptDir 'run-daily-index-with-token-guard.ps1'

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

# ~23:00 - Chrome classic OAuth renew if token dead.
$at23 = New-ScheduledTaskTrigger -Daily -At '11:00PM'
Register-FgTask `
  -TaskName 'FitnessgirlVkTokenRenewCheck' `
  -Execute 'powershell.exe' `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$RenewPs1`"" `
  -Triggers @($at23) `
  -Description '23:00 probe VK token; renew via Google Chrome classic OAuth if needed' `
  -Limit ([TimeSpan]::FromMinutes(15))

# Hard trigger at local midnight: token guard (Chrome renew if needed) then both-sexes index.
$midnight = New-ScheduledTaskTrigger -Daily -At '12:00AM'
Register-FgTask `
  -TaskName 'FitnessgirlIndexerDailyRun' `
  -Execute 'powershell.exe' `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$DailyGuardPs1`"" `
  -Triggers @($midnight) `
  -Description '00:00 ensure classic VK token via Google Chrome if needed, then both-sexes daily index to prod'

# Drop legacy single-task name if present.
Unregister-ScheduledTask -TaskName 'FitnessgirlIndexerDaily' -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "Daily: 23:00 Chrome VK renew check -> 00:00 token-guard + both-sexes index (home IP -> prod DB)."

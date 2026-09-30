$ErrorActionPreference = 'Continue'
Write-Host '== FlClash processes =='
Get-Process | Where-Object { $_.ProcessName -like '*FlClash*' } | Format-Table ProcessName, Id -AutoSize

Write-Host '== FlClashX adapter =='
Get-NetAdapter -Name 'FlClashX' -ErrorAction SilentlyContinue | Format-Table Name, Status, MacAddress -AutoSize

$running = Get-Process -Name 'FlClashX' -ErrorAction SilentlyContinue
if (-not $running) {
  Write-Host 'Starting FlClashX...'
  Start-Process 'C:\Program Files\FlClashX\FlClashX.exe'
  Start-Sleep -Seconds 5
  Get-Process | Where-Object { $_.ProcessName -like '*FlClash*' } | Format-Table ProcessName, Id -AutoSize
} else {
  Write-Host 'FlClashX already running'
}

# Ensure adapter enabled if present
try {
  $ad = Get-NetAdapter -Name 'FlClashX' -ErrorAction Stop
  if ($ad.Status -ne 'Up') {
    Enable-NetAdapter -Name 'FlClashX' -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host 'Tried to enable FlClashX adapter'
  }
} catch {
  Write-Host 'Adapter check skipped'
}

Write-Host '== profile rules (should be original) =='
Select-String -Path "$env:APPDATA\com.follow\clashx\profiles\1790504026278.yaml" -Pattern '134.0.113.50|fitnessgirl-meet|IP-CIDR' -SimpleMatch
if (-not $?) { Write-Host 'No deploy-related rules found (good)' }
Get-Content "$env:APPDATA\com.follow\clashx\profiles\1790504026278.yaml" | Select-Object -Skip 131 -First 10
Write-Host DONE_RESTORE_CHECK

# Never-sleep power profile for Fitnessgirl Telegram bridge host.
# Run elevated if possible: right-click PowerShell -> Run as administrator
#   powershell -ExecutionPolicy Bypass -File scripts\never-sleep-for-bridge.ps1

$ErrorActionPreference = 'Continue'

function Set-Idx($subgroup, $setting, $ac, $dc) {
  powercfg /setacvalueindex SCHEME_CURRENT $subgroup $setting $ac | Out-Null
  powercfg /setdcvalueindex SCHEME_CURRENT $subgroup $setting $dc | Out-Null
}

Write-Host '==> timeouts: never sleep / hibernate / display-off (AC+DC)'
# 0 = never
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0

Write-Host '==> hybrid sleep off, wake timers off'
Set-Idx SUB_SLEEP HYBRIDSLEEP 0 0
Set-Idx SUB_SLEEP RTCWAKE 0 0

Write-Host '==> lid close / power button = Do nothing'
# LIDACTION / PBUTTONACTION: 0=Do nothing, 1=Sleep, 2=Hibernate, 3=Shut down
Set-Idx SUB_BUTTONS LIDACTION 0 0
Set-Idx SUB_BUTTONS PBUTTONACTION 0 0
Set-Idx SUB_BUTTONS SBUTTONACTION 0 0

Write-Host '==> USB selective suspend off (keeps dock/NIC awake)'
Set-Idx 2a737bb5-f0ac-4583-a138-9ae6481d74b1 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 0

Write-Host '==> PCI Express Link State Power Management = Off'
Set-Idx 501a4d13-42af-447a-b8da-f5d848fcad34 ee12f906-d277-404b-b6da-e5fa1a576df5 0 0

Write-Host '==> apply scheme'
powercfg /setactive SCHEME_CURRENT | Out-Null

Write-Host '==> hibernate off'
powercfg /hibernate off 2>$null

# Network connectivity in standby = Always connected / Enable (best-effort; ignored if not AoAc)
try {
  # SUB_NONE / ConnectivityInStandby GUID varies; use named aliases where available
  powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP 94ac6d29-73ce-41a6-809f-6363ba21b47e 0 | Out-Null
} catch {}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
  IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host '==> Modern Standby (S0) override'
if ($isAdmin) {
  # Forces classic S3 path on reboot for many OEMs — stops "fake awake" lid-close freeze.
  New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' `
    -Name 'PlatformAoAcOverride' -PropertyType DWord -Value 0 -Force | Out-Null
  Write-Host '    PlatformAoAcOverride=0 written (reboot required to fully disable Modern Standby)'
} else {
  Write-Host '    SKIP registry (need Admin). Re-run this script as Administrator once.'
}

Write-Host '==> scheduled task: start bridge on logon'
$taskScript = Join-Path $PSScriptRoot 'install-windows-tg-bridge-task.ps1'
if (Test-Path $taskScript) {
  & $taskScript
}

Write-Host ''
Write-Host 'DONE. Summary:'
powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String -Pattern 'Current|����騩|Current AC|Current DC|0x'
powercfg /a | Select-String -Pattern 'Standby|Hibernate|S0|S3|���'
Write-Host ''
Write-Host 'Important:'
Write-Host '  - Keep the PC powered (plug in). Lid close = Do nothing.'
Write-Host '  - If Modern Standby still freezes WSL after lid close: reboot after Admin run of this script.'
Write-Host '  - Bridge still dies if you fully Shut down / Restart Windows or kill Docker Desktop.'

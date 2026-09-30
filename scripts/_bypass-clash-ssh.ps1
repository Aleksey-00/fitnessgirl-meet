$ErrorActionPreference = 'Continue'
Write-Host '== clash-like processes =='
Get-Process | Where-Object { $_.ProcessName -match 'clash|FlClash|meta|verge|outline|sing-box' } |
  Select-Object ProcessName, Id | Format-Table -AutoSize

Write-Host '== disable FlClashX =='
try {
  Disable-NetAdapter -Name 'FlClashX' -Confirm:$false -ErrorAction Stop
  Write-Host 'FlClashX DISABLED'
} catch {
  Write-Host ("disable_failed: " + $_.Exception.Message)
}

Start-Sleep -Seconds 3
$key = Join-Path $env:USERPROFILE '.ssh\id_rsa'
Write-Host '== ssh probe =='
& ssh.exe -F nul -o StrictHostKeyChecking=no -o ConnectTimeout=25 -i $key root@134.0.113.50 'echo SSH_OK; hostname; curl -fsS http://127.0.0.1:3000/api/health; echo'
Write-Host ("ssh_exit=" + $LASTEXITCODE)

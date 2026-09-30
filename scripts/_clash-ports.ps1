$ErrorActionPreference = 'Continue'
Write-Host '== FlClash listening ports =='
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object {
    try {
      $p = Get-Process -Id $_.OwningProcess -ErrorAction Stop
      $p.ProcessName -match 'FlClash|clash'
    } catch { $false }
  } |
  Select-Object LocalAddress, LocalPort, OwningProcess |
  Sort-Object LocalPort -Unique |
  Format-Table -AutoSize

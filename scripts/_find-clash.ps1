$ErrorActionPreference = 'Continue'
Write-Host '== FlClash processes =='
Get-Process | Where-Object { $_.ProcessName -like '*FlClash*' -or $_.ProcessName -like '*clash*' } |
  Format-Table ProcessName, Id -AutoSize

Write-Host '== find FlClash exe =='
$roots = @(
  'C:\Program Files',
  'C:\Program Files (x86)',
  $env:LOCALAPPDATA,
  $env:APPDATA,
  "$env:USERPROFILE\Desktop",
  "$env:USERPROFILE\Downloads"
)
foreach ($root in $roots) {
  if (-not (Test-Path $root)) { continue }
  Get-ChildItem -Path $root -Filter 'FlClash*.exe' -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 5 -ExpandProperty FullName
}

Write-Host '== clash controller ports =='
foreach ($p in @(9090,9091,9097,33331,33332,7890,7891,6152,6153)) {
  try {
    $r = Invoke-WebRequest -Uri ("http://127.0.0.1:{0}/" -f $p) -TimeoutSec 1 -UseBasicParsing
    Write-Host ("port {0} -> {1}" -f $p, $r.StatusCode)
  } catch {
    # ignore
  }
  try {
    $r2 = Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/version" -f $p) -TimeoutSec 1
    Write-Host ("port {0} version: {1}" -f $p, ($r2 | ConvertTo-Json -Compress))
  } catch {}
  try {
    $r3 = Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/configs" -f $p) -TimeoutSec 1
    Write-Host ("port {0} configs ok mode={1}" -f $p, $r3.mode)
  } catch {}
}

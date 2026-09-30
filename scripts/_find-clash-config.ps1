$ErrorActionPreference = 'Continue'
$dirs = @(
  "$env:APPDATA\FlClashX",
  "$env:APPDATA\flclashx",
  "$env:APPDATA\FlClash",
  "$env:LOCALAPPDATA\FlClashX",
  "$env:LOCALAPPDATA\flclashx",
  "$env:LOCALAPPDATA\FlClash",
  "$env:USERPROFILE\.config\clash",
  "$env:USERPROFILE\.config\mihomo",
  "$env:USERPROFILE\.config\clash.meta",
  'C:\Program Files\FlClashX'
)
Write-Host '== candidate dirs =='
foreach ($d in $dirs) {
  if (Test-Path $d) {
    Write-Host "FOUND $d"
    Get-ChildItem $d -Force -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
  }
}

Write-Host '== search yaml/json with external-controller =='
$searchRoots = @($env:APPDATA, $env:LOCALAPPDATA, $env:USERPROFILE)
foreach ($root in $searchRoots) {
  Get-ChildItem -Path $root -Include '*.yaml','*.yml','*.json' -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'clash|flclash|mihomo|meta' } |
    Select-Object -First 40 FullName
}

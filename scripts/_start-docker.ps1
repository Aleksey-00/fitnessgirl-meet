$ErrorActionPreference = 'Continue'
$exe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
if (Test-Path $exe) {
  Start-Process $exe
}
$ok = $false
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 3
  docker info 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    $ok = $true
    break
  }
  Write-Host "wait $i"
}
if ($ok) { Write-Host 'DOCKER_READY' } else { Write-Host 'DOCKER_TIMEOUT'; exit 1 }

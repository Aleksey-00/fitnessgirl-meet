$ErrorActionPreference = 'Continue'
Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty OwningProcess -Unique |
  ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
Get-Process -Name node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Push-Location 'c:\projects\fitnessgirl-meet'
docker compose -f docker-compose.yml -f docker-compose.dev.yml down 2>$null
Pop-Location
Write-Host 'LOCAL_STOPPED'

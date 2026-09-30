# Requires UAC once. Does NOT touch Clash — only Windows host route for VPS IP.
$ErrorActionPreference = 'Continue'
$log = 'c:\projects\fitnessgirl-meet\scripts\_deploy-route-bypass.log'
function Log($m) { $line = ("[{0}] {1}" -f (Get-Date -Format o), $m); Add-Content -Path $log -Value $line; Write-Host $line }

Log 'START route-bypass deploy (Clash untouched)'

$vpsIp = '134.0.113.50'
$wifiIp = '192.168.0.34'
$key = Join-Path $env:USERPROFILE '.ssh\id_rsa'
$project = 'c:\projects\fitnessgirl-meet'

$wifi = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -eq $wifiIp }
if (-not $wifi) { Log "No WiFi IP $wifiIp"; exit 2 }
$ifIndex = $wifi.InterfaceIndex
$nextHop = (Get-NetRoute -InterfaceIndex $ifIndex -DestinationPrefix '0.0.0.0/0' | Select-Object -First 1).NextHop
Log "wifi ifIndex=$ifIndex nextHop=$nextHop"

$existing = Get-NetRoute -DestinationPrefix ($vpsIp + '/32') -ErrorAction SilentlyContinue
if ($existing) {
  Log 'removing old /32 route'
  $existing | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
}

try {
  New-NetRoute -DestinationPrefix ($vpsIp + '/32') -InterfaceIndex $ifIndex -NextHop $nextHop -PolicyStore ActiveStore -ErrorAction Stop | Out-Null
  Log 'ROUTE_ADDED'
} catch {
  Log ("ROUTE_FAIL " + $_.Exception.Message)
  exit 3
}

Log 'ssh probe'
$probe = & ssh.exe -F nul -o StrictHostKeyChecking=no -o ConnectTimeout=20 -o BatchMode=yes -i $key ("root@" + $vpsIp) 'echo SSH_OK; hostname; curl -fsS http://127.0.0.1:3000/api/health; echo' 2>&1
Log ($probe | Out-String)
Log ("ssh_exit=" + $LASTEXITCODE)

if ($LASTEXITCODE -ne 0) {
  Log 'SSH still failed — leaving route for manual debug'
  exit 4
}

Log 'deploy via git bash'
$bash = 'C:\Program Files\Git\bin\bash.exe'
if (Test-Path $bash) {
  & $bash -lc "sed -i 's/\r$//' /c/projects/fitnessgirl-meet/scripts/_deploy-prod.sh /c/projects/fitnessgirl-meet/docker/entrypoint.sh /c/projects/fitnessgirl-meet/docker/entrypoint-tools.sh; bash /c/projects/fitnessgirl-meet/scripts/_deploy-prod.sh" 2>&1 | Tee-Object -FilePath $log -Append
  Log ("deploy_exit=" + $LASTEXITCODE)
} else {
  Log 'Git bash missing'
  exit 5
}

Log 'DONE'

$ErrorActionPreference = 'Continue'
$key = Join-Path $env:USERPROFILE '.ssh\id_rsa'
$vps = 'root@134.0.113.50'

Write-Host '== 1) direct SSH (as-is) =='
& ssh.exe -F nul -o StrictHostKeyChecking=no -o ConnectTimeout=12 -i $key $vps 'echo DIRECT_OK' 2>&1
Write-Host ("exit=" + $LASTEXITCODE)

Write-Host '== 2) SSH via SOCKS5 127.0.0.1:7891 =='
& ssh.exe -F nul -o StrictHostKeyChecking=no -o ConnectTimeout=20 `
  -o 'ProxyCommand=ssh.exe -W %h:%p -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i UNUSED 2>nul' `
  -i $key $vps 'echo SHOULD_NOT' 2>&1 | Select-Object -First 2

# Use ncat/connect if available; else PowerShell-free ProxyCommand via curl? OpenSSH supports ProxyCommand with Windows connect.
# Prefer: ProxyCommand with built-in ProxyCommand using connect.exe OR ssh -o ProxyCommand="ncat --proxy 127.0.0.1:7891 --proxy-type socks5 %h %p"

function Test-Cmd($name) {
  $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

$pc = $null
if (Test-Cmd 'ncat') {
  $pc = 'ncat --proxy 127.0.0.1:7891 --proxy-type socks5 %h %p'
} elseif (Test-Cmd 'connect') {
  $pc = 'connect -S 127.0.0.1:7891 -R remote %h %p'
} elseif (Test-Path 'C:\Program Files\Git\mingw64\bin\connect.exe') {
  $pc = '"C:\Program Files\Git\mingw64\bin\connect.exe" -S 127.0.0.1:7891 -R remote %h %p'
} elseif (Test-Path 'C:\Windows\System32\OpenSSH\ssh.exe') {
  # Fallback: use cloudflared? none. Use PowerShell TCP via socks is hard.
  $pc = $null
}

Write-Host ("proxycommand candidate: " + $pc)

if ($pc) {
  Write-Host '== SSH via ProxyCommand SOCKS =='
  & ssh.exe -F nul -o StrictHostKeyChecking=no -o ConnectTimeout=25 `
    -o ("ProxyCommand=" + $pc) `
    -i $key $vps 'echo SOCKS_OK; hostname; curl -fsS http://127.0.0.1:3000/api/health; echo' 2>&1
  Write-Host ("socks_exit=" + $LASTEXITCODE)
} else {
  Write-Host 'No ncat/connect; trying curl --socks5 for health only'
}

Write-Host '== 3) HTTPS via SOCKS5 =='
& curl.exe -fsS --max-time 20 --socks5-hostname 127.0.0.1:7891 https://fitnessgirl-meet.ru/api/health 2>&1
Write-Host ("curl_socks_exit=" + $LASTEXITCODE)

Write-Host '== 4) HTTPS via HTTP proxy 7890 =='
& curl.exe -fsS --max-time 20 -x http://127.0.0.1:7890 https://fitnessgirl-meet.ru/api/health 2>&1
Write-Host ("curl_http_proxy_exit=" + $LASTEXITCODE)

Write-Host '== 5) HTTPS direct =='
& curl.exe -fsS --max-time 12 https://fitnessgirl-meet.ru/api/health 2>&1
Write-Host ("curl_direct_exit=" + $LASTEXITCODE)

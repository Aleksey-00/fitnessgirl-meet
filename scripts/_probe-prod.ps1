$ErrorActionPreference = 'Continue'
$env:NO_PROXY = '*'
$env:no_proxy = '*'
Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:http_proxy -ErrorAction SilentlyContinue
Remove-Item Env:https_proxy -ErrorAction SilentlyContinue

Write-Host '== health noproxy =='
& curl.exe --noproxy '*' -fsS --max-time 15 'https://fitnessgirl-meet.ru/api/health'
Write-Host ("curl_exit=" + $LASTEXITCODE)

Write-Host '== ssh =='
$key = Join-Path $env:USERPROFILE '.ssh\id_rsa'
& ssh.exe -F nul -o StrictHostKeyChecking=no -o ConnectTimeout=25 -i $key root@134.0.113.50 'echo SSH_OK; hostname; curl -fsS http://127.0.0.1:3000/api/health; echo'
Write-Host ("ssh_exit=" + $LASTEXITCODE)

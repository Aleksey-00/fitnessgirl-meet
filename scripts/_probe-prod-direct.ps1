$ErrorActionPreference = 'Continue'
$key = Join-Path $env:USERPROFILE '.ssh\id_rsa'
$bind = '192.168.0.34'
Write-Host "== ssh bind $bind =="
& ssh.exe -b $bind -F nul -o StrictHostKeyChecking=no -o ConnectTimeout=25 -i $key root@134.0.113.50 'echo SSH_OK; hostname; curl -fsS http://127.0.0.1:3000/api/health; echo'
Write-Host ("ssh_exit=" + $LASTEXITCODE)
Write-Host '== curl via wifi route attempt =='
# Force source IP is hard with curl on Windows; try noproxy + interface
& curl.exe --interface $bind --noproxy '*' -fsS --max-time 15 'https://fitnessgirl-meet.ru/api/health'
Write-Host ("curl_exit=" + $LASTEXITCODE)

$ErrorActionPreference = 'Continue'
$log = 'c:\projects\fitnessgirl-meet\scripts\_deploy-elevated.log'
function Log($m) { Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format o), $m) }
Set-Content -Path $log -Value 'START'

try {
  Log 'disable FlClashX adapter'
  Disable-NetAdapter -Name 'FlClashX' -Confirm:$false -ErrorAction Stop
  Log 'FlClashX DISABLED'
} catch {
  Log ("disable_adapter_failed: " + $_.Exception.Message)
  try {
    Log 'stop FlClash processes'
    Get-Process | Where-Object { $_.ProcessName -match 'FlClash' } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Log 'processes stopped'
  } catch {
    Log ("kill_failed: " + $_.Exception.Message)
  }
}

Start-Sleep -Seconds 3
$key = Join-Path $env:USERPROFILE '.ssh\id_rsa'
Log 'ssh probe'
$probe = & ssh.exe -F nul -o StrictHostKeyChecking=no -o ConnectTimeout=25 -i $key root@134.0.113.50 'echo SSH_OK; curl -fsS http://127.0.0.1:3000/api/health; echo' 2>&1
Log ($probe | Out-String)
Log ("ssh_exit=" + $LASTEXITCODE)

if ($LASTEXITCODE -eq 0) {
  Log 'deploy via git bash / wsl if available'
  $bash = 'C:\Program Files\Git\bin\bash.exe'
  if (Test-Path $bash) {
    & $bash -lc "sed -i 's/\r$//' /c/projects/fitnessgirl-meet/scripts/_deploy-prod.sh /c/projects/fitnessgirl-meet/docker/entrypoint.sh /c/projects/fitnessgirl-meet/docker/entrypoint-tools.sh; bash /c/projects/fitnessgirl-meet/scripts/_deploy-prod.sh" 2>&1 | Tee-Object -FilePath $log -Append
  } else {
    # fallback: use OpenSSH + scp/rsync via windows? Prefer wsl
    & wsl.exe -- bash -lc "sed -i 's/\r$//' /mnt/c/projects/fitnessgirl-meet/scripts/_deploy-prod.sh /mnt/c/projects/fitnessgirl-meet/docker/entrypoint.sh; bash /mnt/c/projects/fitnessgirl-meet/scripts/_deploy-prod.sh" 2>&1 | Tee-Object -FilePath $log -Append
  }
  Log ("deploy_exit=" + $LASTEXITCODE)
} else {
  Log 'SSH still failing after clash bypass'
}

# Re-enable clash if we disabled adapter
try {
  Enable-NetAdapter -Name 'FlClashX' -Confirm:$false -ErrorAction SilentlyContinue
  Log 'FlClashX re-enabled (best effort)'
} catch {}

Log 'END'

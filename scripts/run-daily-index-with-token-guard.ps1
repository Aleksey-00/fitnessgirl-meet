# 00:00 entrypoint: ensure classic VK token (Chrome renew if dead), then start daily index.
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RenewPs1 = Join-Path $ScriptDir 'vk-chrome-oauth-renew.ps1'
$LogDir = Join-Path $env:USERPROFILE 'fg-logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$WinLog = Join-Path $LogDir 'daily-index-guard.win.log'

function Log([string]$msg) {
  $stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
  Add-Content -Path $WinLog -Value "[$stamp] $msg"
  Write-Host $msg
}

Log 'probe VK token before daily index'
$probe = & wsl.exe -u aazor -- bash -lc 'bash /mnt/c/projects/fitnessgirl-meet/scripts/vk-ensure-fresh-token.sh' 2>&1
$rc = $LASTEXITCODE
Add-Content -Path $WinLog -Value ($probe | Out-String)

if ($rc -eq 42) {
  Log 'token dead → Google Chrome classic OAuth renew'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RenewPs1
  if ($LASTEXITCODE -ne 0) {
    Log "renew failed rc=$LASTEXITCODE — skip daily index"
    exit $LASTEXITCODE
  }
} elseif ($rc -ne 0) {
  Log "probe failed rc=$rc — skip daily index"
  exit $rc
} else {
  Log 'token ok'
}

Log 'start fg-indexer-daily.service'
& wsl.exe -u aazor -- bash -lc 'systemctl --user start fg-indexer-daily.service'
Log "index start rc=$LASTEXITCODE"
exit $LASTEXITCODE

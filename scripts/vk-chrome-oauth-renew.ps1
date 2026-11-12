# Open canonical classic VK OAuth in Google Chrome (user profile session),
# wait for blank.html#access_token=vk1.a..., save to VPS via WSL.
# Does NOT use Cursor IDE browser.
param(
  [int]$TimeoutSec = 180,
  [int]$DebugPort = 9222
)

$ErrorActionPreference = 'Stop'
$Root = 'C:\projects\fitnessgirl-meet'
if ($PSScriptRoot) {
  $candidate = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  if (Test-Path (Join-Path $candidate 'scripts\vk-oauth-classic.url')) {
    $Root = $candidate
  }
}

$OAuthFile = Join-Path $Root 'scripts\vk-oauth-classic.url'
$OAuthUrl = 'https://oauth.vk.com/authorize?client_id=54762499&display=page&redirect_uri=https://oauth.vk.com/blank.html&response_type=token&v=5.199'
if (Test-Path $OAuthFile) {
  $OAuthUrl = (Get-Content -Raw $OAuthFile).Trim()
}

$LogDir = Join-Path $env:USERPROFILE 'fg-logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$WinLog = Join-Path $LogDir 'vk-chrome-oauth-renew.win.log'
function Log([string]$msg) {
  $stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
  Add-Content -Path $WinLog -Value "[$stamp] $msg"
  Write-Host $msg
}

function Find-Chrome {
  $candidates = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { return $c }
  }
  return $null
}

function Get-TokenUrlFromCdp([int]$port) {
  try {
    $tabs = Invoke-RestMethod -Uri "http://127.0.0.1:$port/json/list" -TimeoutSec 3
  } catch {
    return $null
  }
  foreach ($t in @($tabs)) {
    $u = [string]$t.url
    if ($u -match 'access_token=vk1\.a\.' -and $u -match 'blank\.html') {
      return $u
    }
  }
  return $null
}

$chrome = Find-Chrome
if (-not $chrome) {
  Log 'ERROR: Google Chrome not found'
  exit 3
}

$userData = Join-Path $env:LOCALAPPDATA 'FitnessgirlVkChrome'
New-Item -ItemType Directory -Force -Path $userData | Out-Null

Log "Opening Chrome OAuth (port=$DebugPort): $OAuthUrl"
$args = @(
  "--remote-debugging-port=$DebugPort",
  "--user-data-dir=$userData",
  '--no-first-run',
  '--no-default-browser-check',
  $OAuthUrl
)
Start-Process -FilePath $chrome -ArgumentList $args | Out-Null

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$tokenUrl = $null
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 2
  $tokenUrl = Get-TokenUrlFromCdp -port $DebugPort
  if ($tokenUrl) { break }
}

if (-not $tokenUrl) {
  Log "TIMEOUT: no access_token in Chrome within ${TimeoutSec}s (login/allow in the Chrome window if asked)"
  exit 42
}

Log 'Token URL captured from Chrome CDP'
$tmpWin = Join-Path $env:TEMP 'fg-vk-classic-url.txt'
[System.IO.File]::WriteAllText($tmpWin, $tokenUrl)

$wslTmp = '/tmp/fg-vk-classic-url.txt'
& wsl.exe -u aazor -- bash -lc "cp /mnt/c/Users/aazor/AppData/Local/Temp/fg-vk-classic-url.txt $wslTmp && bash /mnt/c/projects/fitnessgirl-meet/scripts/_vk-save-classic.sh"
$rc = $LASTEXITCODE
if ($rc -ne 0) {
  Log "SAVE_FAILED rc=$rc"
  exit $rc
}

Remove-Item -Force -ErrorAction SilentlyContinue $tmpWin
$flag = Join-Path $LogDir 'vk-needs-renew.flag'
Remove-Item -Force -ErrorAction SilentlyContinue $flag
& wsl.exe -u aazor -- bash -lc 'rm -f /home/aazor/fg-logs/vk-needs-renew.flag /tmp/fg-vk-classic-url.txt /tmp/fg-vk-access-token.txt'

Log 'OK: classic token saved to VPS from Google Chrome'
exit 0

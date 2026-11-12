# Pre-midnight VK token check (~23:00).
# If the classic vk1.a token is dead: write a marker, open the OAuth URL, toast the user.
# Run via Task Scheduler (registered by install-windows-indexer-task.ps1).

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
if (-not (Test-Path $LogDir)) {
  # WSL home may differ; also try via wslpath later. Windows-side mirror:
  New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}
$WinLog = Join-Path $LogDir 'vk-pre-midnight-check.win.log'
$stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
Add-Content -Path $WinLog -Value "[$stamp] starting pre-midnight VK check"

$wslCmd = 'bash /mnt/c/projects/fitnessgirl-meet/scripts/vk-pre-midnight-renew-check.sh'
$out = & wsl.exe -u aazor -- bash -lc $wslCmd 2>&1
$rc = $LASTEXITCODE
Add-Content -Path $WinLog -Value ($out | Out-String)
Add-Content -Path $WinLog -Value "[$stamp] wsl_rc=$rc"

function Show-FgToast([string]$Title, [string]$Body) {
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $ni = New-Object System.Windows.Forms.NotifyIcon
    $ni.Icon = [System.Drawing.SystemIcons]::Warning
    $ni.Visible = $true
    $ni.BalloonTipTitle = $Title
    $ni.BalloonTipText = $Body
    $ni.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
    $ni.ShowBalloonTip(12000)
    Start-Sleep -Seconds 8
    $ni.Dispose()
  } catch {
    Add-Content -Path $WinLog -Value "toast_failed: $($_.Exception.Message)"
  }
}

if ($rc -eq 0) {
  Add-Content -Path $WinLog -Value 'token ok'
  exit 0
}

if ($rc -eq 42) {
  Add-Content -Path $WinLog -Value "needs renew → open $OAuthUrl"
  try { Start-Process $OAuthUrl } catch { Add-Content -Path $WinLog -Value "open_url_failed: $($_.Exception.Message)" }
  Show-FgToast 'Fitnessgirl VK token' "Токен протух. Открой Cursor → renew с blank.html (ссылка уже открыта). До 00:00 нужен свежий vk1.a."
  # Agent marker on Windows side too
  $flag = Join-Path $LogDir 'vk-needs-renew.flag'
  @"
needs_renew=1
at=$stamp
oauth_url=$OAuthUrl
hint=Cursor browser → classic OAuth → scripts/vk-renew-classic.sh
"@ | Set-Content -Path $flag -Encoding UTF8
  exit 42
}

Show-FgToast 'Fitnessgirl VK check' "Проверка токена завершилась с ошибкой rc=$rc. Смотри fg-logs."
exit $rc

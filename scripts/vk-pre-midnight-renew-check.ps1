# Pre-midnight VK token check (~23:00).
# If classic vk1.a token is dead: open canonical OAuth in Google Chrome, capture token, save to VPS.
# Never uses Cursor IDE browser.

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
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
  Add-Content -Path $WinLog -Value "needs renew → Google Chrome $OAuthUrl"
  Show-FgToast 'Fitnessgirl VK token' 'Токен протух. Открываю Google Chrome — разреши доступ ВК, если спросит. До 00:00 нужен свежий vk1.a.'
  $chromeRenew = Join-Path $ScriptDir 'vk-chrome-oauth-renew.ps1'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $chromeRenew
  $renewRc = $LASTEXITCODE
  Add-Content -Path $WinLog -Value "chrome_renew_rc=$renewRc"
  if ($renewRc -eq 0) {
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $LogDir 'vk-needs-renew.flag')
    exit 0
  }
  $flag = Join-Path $LogDir 'vk-needs-renew.flag'
  @"
needs_renew=1
at=$stamp
oauth_url=$OAuthUrl
hint=Google Chrome classic OAuth blank.html#access_token=vk1.a → scripts/vk-chrome-oauth-renew.ps1
"@ | Set-Content -Path $flag -Encoding UTF8
  Show-FgToast 'Fitnessgirl VK token' 'Не удалось снять токен из Chrome. Разреши доступ ВК в окне Chrome или обнови сессию.'
  exit 42
}

Show-FgToast 'Fitnessgirl VK check' "Проверка токена завершилась с ошибкой rc=$rc. Смотри fg-logs."
exit $rc

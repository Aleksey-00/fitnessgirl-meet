Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class TgWin {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
'@
$p = Get-Process Telegram -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) {
  $exe = Join-Path $env:APPDATA 'Telegram Desktop\Telegram.exe'
  if (Test-Path $exe) { Start-Process $exe; Start-Sleep -Seconds 3 }
  $p = Get-Process Telegram -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $p) { Write-Output 'NO_TELEGRAM_PROCESS'; exit 1 }
[void][TgWin]::ShowWindowAsync($p.MainWindowHandle, 9)
[void][TgWin]::SetForegroundWindow($p.MainWindowHandle)
Write-Output ("FOREGROUND pid=" + $p.Id + " title=" + $p.MainWindowTitle)

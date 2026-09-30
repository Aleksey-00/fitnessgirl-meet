$ErrorActionPreference = 'Continue'
foreach ($p in @(7890,47890,52206)) {
  Write-Host ("== probe {0} ==" -f $p)
  foreach ($path in @('/', '/version', '/configs', '/proxies', '/rules', '/connections', '/api/version', '/api/configs')) {
    try {
      $r = Invoke-WebRequest -Uri ("http://127.0.0.1:{0}{1}" -f $p, $path) -TimeoutSec 2 -UseBasicParsing
      Write-Host ("GET {0} -> {1} len={2}" -f $path, $r.StatusCode, $r.RawContentLength)
      if ($r.Content.Length -lt 300) { Write-Host $r.Content }
    } catch {
      # silent
    }
  }
}

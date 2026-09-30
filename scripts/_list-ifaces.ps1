Get-NetIPConfiguration |
  Where-Object { $_.IPv4Address } |
  ForEach-Object {
    [PSCustomObject]@{
      Alias = $_.InterfaceAlias
      IP = ($_.IPv4Address | ForEach-Object { $_.IPAddress }) -join ','
      Gw = if ($_.IPv4DefaultGateway) { $_.IPv4DefaultGateway.NextHop } else { '' }
    }
  } | Format-Table -AutoSize

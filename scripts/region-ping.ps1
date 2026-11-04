# COIL Project A, task 2: 100 pings to the AWS test address in our fixed Region ap-southeast-2 (Sydney).
# It pings every row of region-targets.csv; that file has one row (ap-southeast-2,SYDNEY-IP).
# Works in Windows PowerShell 5.1 and PowerShell 7, in any Windows language.
# Writes to delay-tests\region-measurement.csv (the file name the team already uses).
# Usage, in the repository folder:
#   powershell -ExecutionPolicy Bypass -File scripts\region-ping.ps1 -Country Poland -City Szczecin -Connection home-wifi
param(
  [Parameter(Mandatory = $true)][string]$Country,
  [Parameter(Mandatory = $true)][string]$City,
  [Parameter(Mandatory = $true)][string]$Connection,
  [int]$Count = 100
)
$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$targets = 'delay-tests\region-targets.csv'
$out = 'delay-tests\region-measurement.csv'
$raw = 'delay-tests\raw'
if (-not (Test-Path $targets)) { throw "Missing $targets (run this from the repository folder)" }
New-Item -ItemType Directory -Force -Path $raw | Out-Null
if (-not (Test-Path $out)) {
  'date,time,country,city,connection,region,median_ms,loss_pct,method' | Out-File -FilePath $out -Encoding ascii
}
$now = Get-Date
$day = $now.ToString('yyyy-MM-dd', $inv); $hm = $now.ToString('HH:mm', $inv); $stamp = $now.ToString('yyyy-MM-dd_HHmm', $inv)
foreach ($t in (Import-Csv $targets)) {
  Write-Host "Pinging $($t.region) ($($t.ip)) $Count times, about $Count seconds..."
  $replies = @(Test-Connection -ComputerName $t.ip -Count $Count -ErrorAction SilentlyContinue)
  $times = @()
  foreach ($r in $replies) {
    if ($r.PSObject.Properties['Latency']) {
      if ([string]$r.Status -eq 'Success') { $times += [double]$r.Latency }
    } elseif ($null -ne $r.ResponseTime -and $r.StatusCode -eq 0) {
      $times += [double]$r.ResponseTime
    }
  }
  $file = Join-Path $raw ("ping_{0}_{1}_{2}.txt" -f $t.region, $City, $stamp)
  @("region=$($t.region) ip=$($t.ip) date=$day time=$hm sent=$Count replies=$($times.Count)") + ($times | ForEach-Object { $_.ToString('0.0', $inv) }) | Out-File -FilePath $file -Encoding ascii
  $sorted = @($times | Sort-Object)
  $n = $sorted.Count
  if ($n -eq 0) { $median = 'NA' }
  elseif ($n % 2 -eq 1) { $median = ([double]$sorted[[int](($n - 1) / 2)]).ToString('0.0', $inv) }
  else { $median = (([double]$sorted[[int]($n / 2) - 1] + [double]$sorted[[int]($n / 2)]) / 2).ToString('0.0', $inv) }
  $loss = [int][math]::Round(($Count - $n) * 100 / $Count)
  "$day,$hm,$Country,$City,$Connection,$($t.region),$median,$loss,icmp-$Count" | Add-Content -Path $out -Encoding ascii
  Write-Host "  $($t.region): median $median ms, loss $loss %"
}
Write-Host "Saved: $out and raw files in $raw\"

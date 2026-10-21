# Package everything collected since the last run into C:\Lab\ship\out\<Run>.zip:
# Fluent Bit's JSON-lines files (moved, so the next run starts empty) plus any new FREB traces.
param([Parameter(Mandatory)][string]$Run)
$ErrorActionPreference = 'Stop'
$out = "C:\Lab\ship\out\$Run"
New-Item -ItemType Directory $out -Force | Out-Null

# IIS writes its log lazily: even after a flush request a line took ~24s to land. So send a marker
# request and wait until Fluent Bit has shipped it; every earlier line is then shipped too.
$marker = "LAB-COLLECT-$Run"
Invoke-WebRequest "http://localhost/?collect=$Run" -UseBasicParsing -UserAgent $marker -ErrorAction SilentlyContinue | Out-Null
netsh http flush logbuffer | Out-Null
$waited = 0
while (-not ((Test-Path C:\Lab\ship\iis.jsonl) -and (Select-String -Path C:\Lab\ship\iis.jsonl -Pattern $marker -SimpleMatch -Quiet))) {
    if ($waited -ge 90) { Write-Warning "IIS marker not shipped after 90s; IIS lines may be missing"; break }
    Start-Sleep 2; $waited += 2
}
"IIS caught up after ${waited}s"
Start-Sleep 3   # let winevtlog/tail write anything from the same moment

# Stop Fluent Bit so no file is mid-write; its tail/winevtlog bookmarks resume from where they were.
Stop-Service fluent-bit
Get-ChildItem C:\Lab\ship -Filter *.jsonl | Move-Item -Destination $out
Start-Service fluent-bit

$freb = Get-ChildItem C:\inetpub\logs\FailedReqLogFiles -Recurse -Filter 'fr*.xml' -ErrorAction SilentlyContinue
if ($freb) {
    Compress-Archive $freb.FullName "$out\freb.zip" -Force
    $freb | Remove-Item
}
"computer=$env:COMPUTERNAME" | Set-Content "$out\run.txt"
Compress-Archive "$out\*" "C:\Lab\ship\out\$Run.zip" -Force
Get-ChildItem $out | ForEach-Object { '{0,-14} {1,10}' -f $_.Name, $_.Length }

$ProgressPreference = "SilentlyContinue"; $appcmd = "$env:windir\System32\inetsrv\appcmd.exe"
wevtutil sl Microsoft-Windows-Sysmon/Operational /ms:1073741824

'--- FREB verify'
& $appcmd list site "Default Web Site" /text:traceFailedRequestsLogging.enabled
& $appcmd list config "Default Web Site" /section:system.webServer/tracing/traceFailedRequests | Select-String 'path=|statusCodes'

'--- smoke test: hit page, then look for events'
Invoke-WebRequest http://localhost/labtest.php -UseBasicParsing -UserAgent 'LAB-SMOKE-P3' | Out-Null
Start-Sleep 5
"sysmon events: $((Get-WinEvent -LogName Microsoft-Windows-Sysmon/Operational -MaxEvents 2000).Count)"
"4688 events:   $((Get-WinEvent -FilterHashtable @{LogName='Security';Id=4688} -MaxEvents 2000 -ErrorAction SilentlyContinue).Count)"
"FREB files:    $((Get-ChildItem C:\inetpub\logs\FailedReqLogFiles -Recurse -Filter *.xml -ErrorAction SilentlyContinue).Count)"
netsh http flush logbuffer | Out-Null
$iis = Get-ChildItem C:\inetpub\logs\LogFiles\W3SVC1\u_ex*.log | Sort-Object LastWriteTime | Select-Object -Last 1
'--- IIS log header + smoke line'
Get-Content $iis.FullName | Select-String '^#Fields'  | Select-Object -Last 1
Get-Content $iis.FullName | Select-String 'LAB-SMOKE-P3' | Select-Object -Last 1

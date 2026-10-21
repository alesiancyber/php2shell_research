$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$appcmd = "$env:windir\System32\inetsrv\appcmd.exe"

'--- built-in Sysmon feature?'
Get-WindowsOptionalFeature -Online | Where-Object FeatureName -like '*Sysmon*' | Format-Table FeatureName, State -Auto

New-Item -ItemType Directory C:\Tools\Sysmon -Force | Out-Null
Invoke-WebRequest https://download.sysinternals.com/files/Sysmon.zip -OutFile C:\Tools\Sysmon.zip
Expand-Archive C:\Tools\Sysmon.zip C:\Tools\Sysmon -Force
Invoke-WebRequest https://github.com/olafhartong/sysmon-modular/releases/download/configs-a45dedb13a43/sysmonconfig-excludes-only.xml -OutFile C:\Tools\Sysmon\sysmon.xml
$h = (Get-FileHash C:\Tools\Sysmon\sysmon.xml -Algorithm SHA256).Hash.ToLower()
if ($h -ne '4c7d27bc2847f7de816ddde90e7de37d5b9473461b27424882e9b93f00cd28a4') { throw "config hash mismatch: $h" }
'config hash ok'
(Get-Item C:\Tools\Sysmon\Sysmon64a.exe).VersionInfo.FileVersion

& C:\Tools\Sysmon\Sysmon64a.exe -accepteula -i C:\Tools\Sysmon\sysmon.xml 2>&1 | Select-Object -Last 5
Get-Service Sysmon* | Format-Table Name, Status -Auto
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

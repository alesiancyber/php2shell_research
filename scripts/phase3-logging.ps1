# Phase 3: audit policy, webroot SACL, PowerShell logging, IIS log fields, FREB, event channels.
# Sysmon is installed separately by phase3-sysmon.ps1.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$appcmd = "$env:windir\System32\inetsrv\appcmd.exe"
function Step($name, [scriptblock]$body) {
    try { & $body; "[ok]   $name" } catch { "[FAIL] $name :: $($_.Exception.Message)" }
}

Step 'auditpol: process creation/termination, file system' {
    auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null
    auditpol /set /subcategory:"Process Termination" /success:enable | Out-Null
    auditpol /set /subcategory:"File System" /success:enable /failure:enable | Out-Null
    reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f | Out-Null
}

Step 'SACL on C:\inetpub\wwwroot (4663 on write/delete)' {
    $acl = Get-Acl C:\inetpub\wwwroot -Audit
    $rule = New-Object System.Security.AccessControl.FileSystemAuditRule('Everyone','CreateFiles,WriteData,AppendData,Delete','ContainerInherit,ObjectInherit','None','Success')
    $acl.AddAuditRule($rule); Set-Acl C:\inetpub\wwwroot $acl
}

Step 'PowerShell script block, module logging, transcription' {
    $ps = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell'
    New-Item "$ps\ScriptBlockLogging", "$ps\ModuleLogging\ModuleNames", "$ps\Transcription" -Force | Out-Null
    Set-ItemProperty "$ps\ScriptBlockLogging" EnableScriptBlockLogging 1
    Set-ItemProperty "$ps\ModuleLogging" EnableModuleLogging 1
    Set-ItemProperty "$ps\ModuleLogging\ModuleNames" '*' '*'
    Set-ItemProperty "$ps\Transcription" EnableTranscripting 1
    Set-ItemProperty "$ps\Transcription" EnableInvocationHeader 1
    Set-ItemProperty "$ps\Transcription" OutputDirectory 'C:\PSTranscripts'
}

Step 'IIS W3C all fields + Content-Type / X-Forwarded-For custom fields' {
    & $appcmd set config /section:system.applicationHost/sites /siteDefaults.logFile.logExtFileFlags:"Date,Time,ClientIP,UserName,SiteName,ComputerName,ServerIP,Method,UriStem,UriQuery,HttpStatus,Win32Status,HttpSubStatus,BytesSent,BytesRecv,TimeTaken,ServerPort,UserAgent,Cookie,Referer,ProtocolVersion,Host" | Out-Null
    & $appcmd set config /section:system.applicationHost/sites /+"siteDefaults.logFile.customFields.[logFieldName='ContentType',sourceName='Content-Type',sourceType='RequestHeader']" | Out-Null
    & $appcmd set config /section:system.applicationHost/sites /+"siteDefaults.logFile.customFields.[logFieldName='XFF',sourceName='X-Forwarded-For',sourceType='RequestHeader']" | Out-Null
    if ($LASTEXITCODE) { throw "appcmd exit $LASTEXITCODE" }
}

Step 'FREB on *.php, status 200-599' {
    $a = & $appcmd configure trace "Default Web Site" /enablesite 2>&1
    $b = & $appcmd configure trace "Default Web Site/" /enable /path:*.php /statuscodes:200-599 2>&1
    if ($LASTEXITCODE) { throw (($a + $b) | Out-String) }
}

Step 'Event channels: IIS-Configuration on, Security 1 GB' {
    wevtutil sl Microsoft-IIS-Configuration/Operational /e:true
    wevtutil sl Security /ms:1073741824
}

'--- verify'
auditpol /get /subcategory:"Process Creation","File System" | Select-String 'Process Creation|File System'
& $appcmd list config "Default Web Site" /section:system.webServer/tracing/traceFailedRequests | Select-String 'path|statusCodes'
& $appcmd list site "Default Web Site" /config | Select-String 'traceFailedRequestsLogging'

---
title: 3. Logging
parent: Build steps
nav_order: 3
---

# 3. Logging

Turn on far more logging than a real server has, so nothing is missed. The [log source matrix]({{ '/#log-source-matrix-windows' | relative_url }}) then records which sources a default server would have.

| Script | Does |
| --- | --- |
| [`phase3-sysmon.ps1`]({{ '/scripts/phase3-sysmon.ps1' | relative_url }}) | Sysmon (ARM64 build) with the sysmon-modular "excludes only" config, hash-checked |
| [`phase3-logging.ps1`]({{ '/scripts/phase3-logging.ps1' | relative_url }}) | Audit policy, webroot audit rule, PowerShell logging, IIS log fields, FREB, event channels |
| [`phase3-verify.ps1`]({{ '/scripts/phase3-verify.ps1' | relative_url }}) | Smoke test: one request, then counts per source |

Then snapshot: `prlctl snapshot WinLab -n logging-on`.

<details markdown="block">
<summary>Sysmon</summary>

The ARM64 binary `Sysmon64a.exe` ships inside `Sysmon.zip`. The sysmon-modular configs are release assets.

```powershell
Invoke-WebRequest https://download.sysinternals.com/files/Sysmon.zip -OutFile C:\Tools\Sysmon.zip
Expand-Archive C:\Tools\Sysmon.zip C:\Tools\Sysmon -Force
Invoke-WebRequest https://github.com/olafhartong/sysmon-modular/releases/latest/download/sysmonconfig-excludes-only.xml -OutFile C:\Tools\Sysmon\sysmon.xml
cmd /c "C:\Tools\Sysmon\Sysmon64a.exe -accepteula -i C:\Tools\Sysmon\sysmon.xml 2>&1"
```

Recent Windows 11 builds also offer Sysmon as an optional feature (`Sysmon`, `Sysmon-Service`). Leave it disabled; it conflicts with the standalone install.
</details>

<details markdown="block">
<summary>Process and file auditing</summary>

```powershell
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable
auditpol /set /subcategory:"Process Termination" /success:enable
auditpol /set /subcategory:"File System" /success:enable /failure:enable
reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f

# 4663 on writes and deletes under the webroot
$acl = Get-Acl C:\inetpub\wwwroot -Audit
$rule = New-Object System.Security.AccessControl.FileSystemAuditRule('Everyone','CreateFiles,WriteData,AppendData,Delete','ContainerInherit,ObjectInherit','None','Success')
$acl.AddAuditRule($rule); Set-Acl C:\inetpub\wwwroot $acl
```
</details>

<details markdown="block">
<summary>PowerShell logging</summary>

Script block logging (4104), module logging (4103) and transcripts, set through the policy keys under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell`. See the script for the exact values.
</details>

<details markdown="block">
<summary>IIS log fields and Failed Request Tracing</summary>

```powershell
$appcmd = "$env:windir\System32\inetsrv\appcmd.exe"
& $appcmd set config /section:system.applicationHost/sites /siteDefaults.logFile.logExtFileFlags:"Date,Time,ClientIP,UserName,SiteName,ComputerName,ServerIP,Method,UriStem,UriQuery,HttpStatus,Win32Status,HttpSubStatus,BytesSent,BytesRecv,TimeTaken,ServerPort,UserAgent,Cookie,Referer,ProtocolVersion,Host"
& $appcmd set config /section:system.applicationHost/sites /+"siteDefaults.logFile.customFields.[logFieldName='ContentType',sourceName='Content-Type',sourceType='RequestHeader']"
& $appcmd set config /section:system.applicationHost/sites /+"siteDefaults.logFile.customFields.[logFieldName='XFF',sourceName='X-Forwarded-For',sourceType='RequestHeader']"

# FREB for every .php request, including status 200: PHP warnings usually still return 200
& $appcmd configure trace "Default Web Site" /enablesite
& $appcmd configure trace "Default Web Site/" /enable /path:*.php /statuscodes:200-599
```

With custom fields, IIS names its log files `u_ex<date>_x.log`.
</details>

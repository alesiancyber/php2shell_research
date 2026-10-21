# Phase 4: install Fluent Bit (ARM64) as a service that collects Event Log channels and IIS/PHP/HTTPERR
# files into JSON-lines files under C:\Lab\ship. The Mac pulls them per test run (collect-run.sh) and
# uploads to Azurite / loads into Kusto.
# Why not ship straight to Azurite: out_azure_blob crashes the process on its first upload on Windows
# (5.1.3 and 5.0.11, ARM64 and x64, any TLS setting), and --dry-run crashes on any azure_blob config
# (fluent/fluent-bit PR #12616). The VM therefore holds no storage credentials.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Version = '5.1.3'
$Sha256  = '0c0ea7aa79093491baf2d599826922e39b0b9f8abafad47ac18027a872d7fceb'
$Root    = 'C:\Program Files\fluent-bit'
$State   = 'C:\fluent-bit-state'
$Ship    = 'C:\Lab\ship'

# 1. Download, verify, install (skipped if this version is already in place).
$have = if (Test-Path "$Root\bin\fluent-bit.exe") { (& "$Root\bin\fluent-bit.exe" --version | Select-Object -First 1) } else { '' }
if ($have -ne "Fluent Bit v$Version") {
    $zip = "C:\Lab\dl\fluent-bit-$Version-winarm64.zip"
    New-Item -ItemType Directory C:\Lab\dl -Force | Out-Null
    Invoke-WebRequest "https://packages.fluentbit.io/windows/fluent-bit-$Version-winarm64.zip" -OutFile $zip
    $h = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    if ($h -ne $Sha256) { throw "fluent-bit zip hash mismatch: $h" }
    Expand-Archive $zip C:\Lab\dl\fb -Force
    $bin = Get-ChildItem C:\Lab\dl\fb -Recurse -Filter fluent-bit.exe | Select-Object -First 1
    if (Get-Service fluent-bit -ErrorAction SilentlyContinue) { Stop-Service fluent-bit }
    if (Test-Path $Root) { Remove-Item $Root -Recurse -Force }
    Copy-Item (Split-Path $bin.FullName -Parent | Split-Path -Parent) $Root -Recurse
}
& "$Root\bin\fluent-bit.exe" --version | Select-Object -First 1

# 2. No storage credentials in the VM any more.
Remove-Item C:\Lab\winlab-write.sas -ErrorAction SilentlyContinue

# 3. Config: one JSON-lines file per source in C:\Lab\ship.
New-Item -ItemType Directory $State, $Ship -Force | Out-Null
$channels = 'Application,System,Security,Microsoft-Windows-Sysmon/Operational,Microsoft-Windows-PowerShell/Operational,Microsoft-IIS-Configuration/Operational,Microsoft-Windows-Windows Defender/Operational'
$conf = @"
[SERVICE]
    flush        2
    log_level    info
    log_file     $State\fluent-bit.log

[INPUT]
    name         winevtlog
    tag          winevt
    channels     $channels
    interval_sec 1
    db           $State\winevt.db

[INPUT]
    name             tail
    tag              iis
    path             C:\inetpub\logs\LogFiles\W3SVC1\u_ex*.log
    db               $State\iis.db
    path_key         SourceFile
    refresh_interval 2

[INPUT]
    name             tail
    tag              php
    path             C:\PHP\logs\php_errors.log
    db               $State\php.db
    path_key         SourceFile
    refresh_interval 2

[INPUT]
    name             tail
    tag              httperr
    path             C:\Windows\System32\LogFiles\HTTPERR\httperr*.log
    db               $State\httperr.db
    path_key         SourceFile
    refresh_interval 2

[OUTPUT]
    name    file
    match   winevt
    path    $Ship
    file    winevt.jsonl
    format  plain

[OUTPUT]
    name    file
    match   iis
    path    $Ship
    file    iis.jsonl
    format  plain

[OUTPUT]
    name    file
    match   php
    path    $Ship
    file    php.jsonl
    format  plain

[OUTPUT]
    name    file
    match   httperr
    path    $Ship
    file    httperr.jsonl
    format  plain
"@
$confPath = "$Root\conf\lab.conf"
Set-Content $confPath $conf -Encoding ascii

# 4. Service (LocalSystem, needed for the Security channel).
if (Get-Service fluent-bit -ErrorAction SilentlyContinue) { Stop-Service fluent-bit; sc.exe delete fluent-bit | Out-Null; Start-Sleep 2 }
# New-Service, not sc.exe: Windows PowerShell mangles the nested quotes in sc.exe's binPath= argument.
New-Service -Name fluent-bit -BinaryPathName "`"$Root\bin\fluent-bit.exe`" -c `"$confPath`"" -StartupType Automatic -DisplayName 'Fluent Bit (lab)' | Out-Null
Start-Service fluent-bit

# 5. Smoke test.
Invoke-WebRequest http://localhost/labtest.php -UseBasicParsing -UserAgent 'LAB-SMOKE-P4' | Out-Null
netsh http flush logbuffer | Out-Null
Start-Sleep 15
Get-Service fluent-bit | Format-Table Name, Status -Auto
Get-ChildItem $Ship | Format-Table Name, Length -Auto
'--- fluent-bit.log errors/warnings'
Get-Content "$State\fluent-bit.log" | Select-String '\[(error|warn)' | Select-Object -Last 5
'--- first winevt record'
Get-Content "$Ship\winevt.jsonl" -TotalCount 1
'--- iis smoke line'
Select-String -Path "$Ship\iis.jsonl" -Pattern 'LAB-SMOKE-P4' | Select-Object -Last 1 | % Line

$ErrorActionPreference = 'Stop'
$appcmd = "$env:windir\System32\inetsrv\appcmd.exe"

# FastCGI app + *.php handler
& $appcmd set config /section:system.webServer/fastCgi /+"[fullPath='C:\PHP\php-cgi.exe']"
& $appcmd set config /section:system.webServer/handlers /+"[name='PHP_via_FastCGI',path='*.php',verb='*',modules='FastCgiModule',scriptProcessor='C:\PHP\php-cgi.exe',resourceType='Either']"

# php.ini from production template, Run A (log to file)
$ini = Get-Content C:\PHP\php.ini-production -Raw
$ini = $ini -replace '(?m)^error_reporting\s*=.*$', 'error_reporting = E_ALL'
$ini = $ini -replace '(?m)^;?error_log\s*=\s*php_errors\.log.*$', 'error_log = "C:\PHP\logs\php_errors.log"'
$ini = $ini -replace '(?m)^log_errors\s*=.*$', 'log_errors = On'
$ini = $ini -replace '(?m)^display_errors\s*=.*$', 'display_errors = Off'
Set-Content C:\PHP\php.ini $ini -Encoding ascii

New-Item -ItemType Directory C:\PHP\logs -Force | Out-Null
icacls C:\PHP\logs /grant "IIS_IUSRS:(OI)(CI)M" | Out-Null

# Benign marker page
Set-Content C:\inetpub\wwwroot\labtest.php "<?php`ntrigger_error('LAB-MARKER-001 test warning', E_USER_WARNING);`necho 'ok';`n" -Encoding ascii

& $appcmd recycle apppool /apppool.name:DefaultAppPool | Out-Null
$r = Invoke-WebRequest http://localhost/labtest.php -UseBasicParsing
"HTTP $($r.StatusCode) body=$($r.Content)"
Start-Sleep 2
'--- php_errors.log'
Get-Content C:\PHP\logs\php_errors.log -ErrorAction SilentlyContinue
'--- php.ini effective'
Select-String -Path C:\PHP\php.ini -Pattern '^(error_reporting|error_log|log_errors|display_errors)\s*=' | % Line
'--- php-cgi processes'
Get-CimInstance Win32_Process -Filter "Name='php-cgi.exe'" | % { "$($_.ProcessId) parent=$($_.ParentProcessId) $($_.ExecutablePath)" }

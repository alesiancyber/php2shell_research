---
title: 2. IIS and PHP
parent: Build steps
nav_order: 2
---

# 2. IIS and PHP

IIS serves PHP 8.4 through FastCGI. Swap the `C:\PHP` folder for the version the target vulnerability needs; use XAMPP instead of IIS if the vulnerable software ships with Apache.

## 1. IIS with CGI, logging and tracing

```powershell
Enable-WindowsOptionalFeature -Online -All -NoRestart -FeatureName `
  IIS-WebServerRole, IIS-WebServer, IIS-CGI, IIS-HttpLogging, IIS-CustomLogging, `
  IIS-LoggingLibraries, IIS-HttpTracing, IIS-RequestMonitor, IIS-ManagementConsole
```

## 2. PHP

PHP's Windows builds are x64 only; they run under Windows' x64 emulation on ARM. Install the Visual C++ x64 runtime, then the Non-Thread-Safe zip, and check its SHA-256 against `releases.json` on windows.php.net.

```powershell
Invoke-WebRequest https://aka.ms/vs/17/release/vc_redist.x64.exe -OutFile vc_redist.x64.exe
.\vc_redist.x64.exe /install /quiet /norestart
Invoke-WebRequest https://windows.php.net/downloads/releases/php-8.4.27-nts-Win32-vs17-x64.zip -OutFile php.zip
Expand-Archive php.zip C:\PHP
```

## 3. Handler, logging and test page

[`phase2-php-iis.ps1`]({{ '/scripts/phase2-php-iis.ps1' | relative_url }}) registers PHP as a FastCGI handler, writes `php.ini` from the production template, grants IIS write access to `C:\PHP\logs`, and adds a test page.

Each test runs once per PHP logging mode, because `error_log` holds one destination:

| Mode | `error_log` | Shows |
| --- | --- | --- |
| file | `C:\PHP\logs\php_errors.log` | The most common setup; needs a file shipper |
| syslog | `syslog` | Errors in the Windows Application event log |
| unset | unset (default) | What a default IIS install keeps |

```ini
log_errors = On
error_reporting = E_ALL
display_errors = Off
error_log = "C:\PHP\logs\php_errors.log"
```

The test page `C:\inetpub\wwwroot\labtest.php` writes one known, harmless warning:

```php
<?php
trigger_error('LAB-MARKER-001 test warning', E_USER_WARNING);
echo 'ok';
```

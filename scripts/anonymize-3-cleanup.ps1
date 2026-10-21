# Remove the original account and every log written under the old names, then restart collection
# from an empty state so the next baseline snapshot holds nothing identifying.
#   anonymize-3-cleanup.ps1 -OldUser <old account> [-AlsoMatch '<old computer name>','<full name>']
param([Parameter(Mandatory)][string]$OldUser, [string[]]$AlsoMatch = @())
$ErrorActionPreference = 'Stop'

# 1. Old account and its profile (must not be loaded: sign in as labadmin first).
$p = Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -eq "C:\Users\$OldUser" }
if ($p) { if ($p.Loaded) { throw "profile of $OldUser is loaded; sign it out / reboot first" }; $p | Remove-CimInstance }
if (Get-LocalUser $OldUser -ErrorAction SilentlyContinue) { Remove-LocalUser $OldUser }
"account and profile removed: $(-not (Get-LocalUser $OldUser -ErrorAction SilentlyContinue)) / $(-not (Test-Path "C:\Users\$OldUser"))"

# 2. Stop collection and wipe what it has gathered.
Stop-Service fluent-bit
Remove-Item C:\Lab\ship\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item C:\fluent-bit-state\*.db*, C:\fluent-bit-state\fluent-bit.log -Force -ErrorAction SilentlyContinue

# 3. Old log files (they carry the old computer name / user).
Stop-Service W3SVC
Remove-Item C:\inetpub\logs\LogFiles\W3SVC1\*.log -Force -ErrorAction SilentlyContinue
Get-ChildItem C:\inetpub\logs\FailedReqLogFiles -Recurse -Filter 'fr*.xml' -ErrorAction SilentlyContinue | Remove-Item -Force
Remove-Item C:\Windows\System32\LogFiles\HTTPERR\httperr*.log -Force -ErrorAction SilentlyContinue
Remove-Item C:\PHP\logs\php_errors.log -Force -ErrorAction SilentlyContinue
Remove-Item C:\PSTranscripts\* -Recurse -Force -ErrorAction SilentlyContinue
Start-Service W3SVC

# 4. Every event log channel (some system channels refuse; that is fine).
$cleared = 0
$ErrorActionPreference = 'Continue'   # wevtutil writes to stderr for channels it may not clear
foreach ($ch in (wevtutil el)) { wevtutil cl "$ch" 2>$null; if ($LASTEXITCODE -eq 0) { $cleared++ } }
$ErrorActionPreference = 'Stop'
"event log channels cleared: $cleared"

Start-Service fluent-bit
"fluent-bit: $((Get-Service fluent-bit).Status)"

# 5. Anything left that still names the old identity?
$hits = Get-ChildItem C:\Lab, C:\inetpub\logs, C:\PHP\logs, C:\fluent-bit-state -Recurse -File -ErrorAction SilentlyContinue |
    Select-String -Pattern (@($OldUser) + $AlsoMatch) -SimpleMatch -List -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -notlike 'C:\Lab\anonymize-*' }
"files still naming the old identity: $(@($hits).Count)"; $hits | ForEach-Object { "  $($_.Path)" }

$u = Get-LocalUser labadmin
"labadmin password last set: $($u.PasswordLastSet)  (created this session; a recent time means you set it)"

# Stop Windows signing in to the original account automatically (Parallels express install turns it on).
$wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty $wl AutoAdminLogon '0'
Remove-ItemProperty $wl DefaultPassword -ErrorAction SilentlyContinue
Set-ItemProperty $wl DefaultUserName ''
$v = Get-ItemProperty $wl
"AutoAdminLogon=$($v.AutoAdminLogon) DefaultUserName='$($v.DefaultUserName)' DefaultPassword present=$([bool]$v.DefaultPassword)"

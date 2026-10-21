# Make the VM's identity neutral before sharing logs: computer name, registered owner, and a new
# admin account (labadmin) to replace the personal one. No password is set here on purpose: anything
# in this script lands in PowerShell script block logs. The user sets it at first sign-in.
param([string]$NewName = 'WINLAB-01', [string]$NewUser = 'labadmin')
$ErrorActionPreference = 'Stop'

$nt = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Set-ItemProperty $nt RegisteredOwner 'Lab'
Set-ItemProperty $nt RegisteredOrganization ''

if (-not (Get-LocalUser $NewUser -ErrorAction SilentlyContinue)) {
    New-LocalUser $NewUser -NoPassword -FullName '' -Description 'Lab admin' | Out-Null
    Add-LocalGroupMember Administrators $NewUser
}
Set-LocalUser $NewUser -PasswordNeverExpires $true

# Parallels' express install may auto-sign-in the original account; report it, the next step removes it.
$wl = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
"autologon: AutoAdminLogon=$($wl.AutoAdminLogon) DefaultUserName=$($wl.DefaultUserName)"

if ($env:COMPUTERNAME -ne $NewName) { Rename-Computer -NewName $NewName -Force; "computer will be $NewName after reboot" }
Get-LocalUser $NewUser | Format-Table Name, Enabled, PasswordRequired -Auto

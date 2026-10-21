# Set one or more php.ini directives and recycle the app pool so FastCGI picks them up.
# Pairs are one string, semicolon-separated (robust through prlctl/-File):
#   set-ini.ps1 -Pairs 'memory_limit=32M;post_max_size=128M'
param([Parameter(Mandatory)][string]$Pairs, [string]$Ini = 'C:\PHP\php.ini')
$ErrorActionPreference = 'Stop'
$text = Get-Content $Ini -Raw
foreach ($p in ($Pairs -split ';' | Where-Object { $_ -match '=' })) {
    $name, $val = $p.Split('=', 2)
    $name = $name.Trim(); $val = $val.Trim()
    $ek = [regex]::Escape($name)
    if ($text -match "(?m)^\s*;?\s*$ek\s*=") { $text = $text -replace "(?m)^\s*;?\s*$ek\s*=.*$", "$name = $val" }
    else { $text += "`r`n$name = $val" }
}
Set-Content $Ini $text -Encoding ascii
& $env:windir\System32\inetsrv\appcmd.exe recycle apppool /apppool.name:DefaultAppPool | Out-Null
Start-Sleep 2
foreach ($p in ($Pairs -split ';' | Where-Object { $_ -match '=' })) { $k = $p.Split('=',2)[0].Trim(); "$k = $(& C:\PHP\php.exe -r "echo ini_get('$k');")" }

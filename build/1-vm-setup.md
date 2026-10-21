---
title: 1. VM setup
parent: Build steps
nav_order: 1
---

# 1. VM setup

Create a Windows 11 ARM VM in Parallels (the express install is fine), name it `WinLab`, and let Parallels Tools install. Then give it a neutral identity and cut it off from the Mac.

## Neutral identity

Every event carries the computer name, and user processes carry the account name and profile path. If the logs may be shared, change both before collecting anything.

1. Rename the computer, set a neutral registered owner and create a `labadmin` account with [`anonymize-1-rename.ps1`]({{ '/scripts/anonymize-1-rename.ps1' | relative_url }}). It sets no password on purpose: script contents land in PowerShell's logs.
2. Turn off automatic sign-in to the original account with [`anonymize-2-autologon-off.ps1`]({{ '/scripts/anonymize-2-autologon-off.ps1' | relative_url }}), then restart.
3. Sign in as `labadmin` and set its password (Ctrl+Alt+Del, Change a password).
4. Remove the original account and every log written under the old names with [`anonymize-3-cleanup.ps1`]({{ '/scripts/anonymize-3-cleanup.ps1' | relative_url }}) `-OldUser <name>`.
5. Delete the anonymize scripts from `C:\Lab` and clear the PowerShell log once more: those scripts mention the old name, and module logging records their parameters.

## Separate Windows from the Mac

Parallels shares Mac folders, apps, iCloud and location with Windows by default. Turn those off, but keep Parallels Tools (needed for `prlctl exec`) and time sync (log timestamps depend on it). Don't use *Isolate VM*: it also blocks `prlctl exec`.

<details markdown="block">
<summary>prlctl commands</summary>

```bash
V=WinLab
prlctl set "$V" --shared-profile off
prlctl set "$V" --sh-app-host-to-guest off --sh-app-guest-to-host off
prlctl set "$V" --shf-guest off --shf-host-defined off
prlctl set "$V" --smart-mount off --shared-cloud off --share-host-location off --sync-ssh-ids off
prlctl set "$V" --auto-share-camera off --auto-share-gamepad off
prlctl set "$V" --shared-clipboard host-to-guest
```

Restart Windows afterwards.
</details>

## Check and snapshot

```bash
prlctl exec WinLab cmd /c "hostname & echo %PROCESSOR_ARCHITECTURE% & whoami"
# WINLAB-01 / ARM64 / nt authority\system
prlctl snapshot WinLab -n clean-install
```

## Running scripts in the VM

`prlctl exec` runs as SYSTEM and rejects long arguments, so the helper scripts send files over stdin:

```bash
scripts/vm-run.sh scripts/phase2-php-iis.ps1     # copies to C:\Lab\ and runs it
scripts/vm-push.sh somefile 'C:\Lab\somefile'     # copies any file
```

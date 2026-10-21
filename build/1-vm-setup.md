---
title: 1. VM setup
parent: Build steps
nav_order: 1
---

# 1. VM setup

Create a Windows 11 ARM VM in Parallels (the express install is fine), name it `WinLab`, and let Parallels Tools install. Then cut it off from the Mac.

{: .note }
Every event carries the computer and account name. If you plan to share your logs, rename both before collecting anything.

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
# <computer name> / ARM64 / nt authority\system
prlctl snapshot WinLab -n clean-install
```

## Running scripts in the VM

`prlctl exec` runs as SYSTEM and rejects long arguments, so the helper scripts send files over stdin:

```bash
scripts/vm-run.sh scripts/phase2-php-iis.ps1     # copies to C:\Lab\ and runs it
scripts/vm-push.sh somefile 'C:\Lab\somefile'     # copies any file
```

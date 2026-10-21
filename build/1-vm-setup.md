---
title: 1. VM setup
parent: Build steps
nav_order: 1
---

# 1. VM setup

Create a Windows 10/11 or Windows Server VM in your hypervisor and install its guest tools. Then cut it off from the host.

{: .note }
Every event carries the computer and account name. If you plan to share your logs, rename both before collecting anything.

## Isolate the VM from the host

Most desktop hypervisors share host folders, apps, the clipboard and location with the guest by default. Turn those off, so nothing from the host ends up in the VM's logs. Keep two things:

- the guest tools, or whatever lets the host run commands in the VM (the test loop needs it)
- time sync, because log timestamps depend on it

The VM needs a network path from the host for the HTTP trigger requests (a host-only or NAT network is enough).

<details markdown="block">
<summary>Our setup: Parallels</summary>

Parallels shares Mac folders, apps, iCloud and location by default. These commands turn that off; restart Windows afterwards. Don't use *Isolate VM*: it also blocks `prlctl exec`.

```bash
V=WinLab
prlctl set "$V" --shared-profile off
prlctl set "$V" --sh-app-host-to-guest off --sh-app-guest-to-host off
prlctl set "$V" --shf-guest off --shf-host-defined off
prlctl set "$V" --smart-mount off --shared-cloud off --share-host-location off --sync-ssh-ids off
prlctl set "$V" --auto-share-camera off --auto-share-gamepad off
prlctl set "$V" --shared-clipboard host-to-guest
```
</details>

## Check and snapshot

From the host, run a command in the VM and confirm it comes back as SYSTEM, then take a snapshot named `clean-install`.

<details markdown="block">
<summary>Our setup: Parallels</summary>

```bash
prlctl exec WinLab cmd /c "hostname & echo %PROCESSOR_ARCHITECTURE% & whoami"
# <computer name> / ARM64 / nt authority\system
prlctl snapshot WinLab -n clean-install
```
</details>

## Running scripts in the VM

The later steps run PowerShell scripts from `scripts/` inside the VM as SYSTEM. The helper scripts copy each file to `C:\Lab\` and run it there:

```bash
scripts/vm-run.sh scripts/phase2-php-iis.ps1     # copies to C:\Lab\ and runs it
scripts/vm-push.sh somefile 'C:\Lab\somefile'     # copies any file
```

They are written for `prlctl exec`. That command rejects long arguments, so the files travel over stdin. On another hypervisor, see [Host-side scripts](index.html#host-side-scripts-and-our-setup), or copy the scripts in and run them from an elevated PowerShell.

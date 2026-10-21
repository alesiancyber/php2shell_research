---
title: Build steps
nav_order: 5
has_children: true
---

# Build steps

How to rebuild the lab and check the findings yourself: a Windows VM running IIS and PHP, driven from a host machine that collects each test run's logs and loads them into Kusto. The findings do not depend on the hypervisor, the host OS or the CPU architecture; any Windows/IIS/PHP server with the same logging shows the same signals.

{: .note }
**Our setup:** an Apple Silicon Mac running Parallels Desktop Pro, with a Windows 11 ARM VM named `WinLab`. The host-side helper scripts are written for that (they call Parallels' `prlctl`), and each step notes what to change for a different setup.

![Lab architecture: the Windows VM's logs are collected by Fluent Bit, pulled to the host per test run, archived in Azurite and loaded into Kusto tables with Sentinel schemas]({{ '/assets/architecture.svg' | relative_url }})

<details markdown="block">
<summary>Design choices and why</summary>

| Choice | Why |
| --- | --- |
| A Windows VM, not a container | Windows containers need a Windows host, and IIS, the Event Log and Sysmon behave as they do on a real server only in a full VM. |
| A hypervisor with snapshots and a command line | Snapshots plus a way to run commands in the guest make the revert, trigger, collect loop scriptable. Ours is Parallels (`prlctl`); Hyper-V, VMware and VirtualBox all have equivalents. |
| Any Windows architecture | ARM64 and x64 Windows have the same event channels, event IDs and IIS logs. Ours is ARM64, where x64 PHP runs under Windows' built-in emulation. |
| Sysmon with a verbose config as the EDR stand-in | Records the same core events as Defender for Endpoint (process, network, file, registry, DNS) and keeps them locally. |
| Everything logged, then judged by default state | Every source is turned on so nothing is missed; the log source matrix then records which ones a default server has. |
| Fluent Bit in the VM, pulled per run | Each test run is collected as one unit. The VM holds no storage credentials. |
| Kusto emulator with real Sentinel table schemas | Queries written here run unchanged against `SecurityEvent`, `Event` and `W3CIISLog` in Microsoft Sentinel. |

</details>

All scripts are in [`scripts/`]({{ site.github.repository_url }}/tree/main/scripts). The PowerShell scripts run inside the VM and work on any Windows VM. The shell scripts run on the host.

| Stage | Result | Snapshot after |
| --- | --- | --- |
| [1. VM setup](1-vm-setup.html) | Windows VM, isolated from the host, scriptable from the host | `clean-install` |
| [2. IIS and PHP](2-iis-php.html) | IIS + PHP 8.4 through FastCGI, PHP errors logged to a file | |
| [3. Logging](3-logging.html) | Sysmon, process and file auditing, PowerShell logging, all IIS fields, FREB | `logging-on` |
| [4. Collection](4-collection.html) | Fluent Bit, per-run pull, Azurite archive, Kusto Sentinel tables | `logging-baseline` |
| [5. Test runs](5-test-runs.html) | Revert, trigger, collect, query | |

**You need:**
- a host machine with a hypervisor that supports snapshots and running commands in the guest from the command line
- a Windows 10/11 or Windows Server VM
- Docker, for Azurite and the Kusto emulator
- the Azure CLI (`az`), Python 3 and bash on the host

## Host-side scripts and our setup

Four host scripts talk to the VM through `prlctl`. On another hypervisor, replace those calls with its equivalent; the logic around them stays the same.

| Script | What it does through the hypervisor | Equivalents |
| --- | --- | --- |
| `vm-run.sh` | Copies a script into `C:\Lab\` over stdin and runs it as SYSTEM | Hyper-V: `Invoke-Command -VMName` (PowerShell Direct); VMware: `vmrun runProgramInGuest`; VirtualBox: `VBoxManage guestcontrol run`; or WinRM/SSH into the VM |
| `vm-push.sh` | Copies any file into the VM | `Copy-Item -ToSession`, `vmrun CopyFileFromHostToGuest`, `VBoxManage guestcontrol copyto` |
| `revert.sh` | Reverts to a snapshot by name | `Restore-VMSnapshot`, `vmrun revertToSnapshot`, `VBoxManage snapshot restore` |
| `collect-run.sh` | Runs `collect-vm.ps1`, then pulls the run's zip back to the host | Any of the above for the run and the copy back. It also uses macOS `base64 -D`; on Linux that is `base64 -d` |

The scripts read the VM name from `VM` (default `WinLab`).

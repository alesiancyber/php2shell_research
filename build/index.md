---
title: Build steps
nav_order: 4
has_children: true
---

# Build steps

How to rebuild the Windows lab and check the findings yourself. The findings do not depend on this exact setup; any Windows/IIS/PHP host with the same logging will show the same signals.

![Lab architecture: the Windows VM's logs are collected by Fluent Bit, pulled to the Mac per test run, archived in Azurite and loaded into Kusto tables with Sentinel schemas]({{ '/assets/architecture.svg' | relative_url }})

<details markdown="block">
<summary>Design choices and why</summary>

| Choice | Why |
| --- | --- |
| A Windows VM, not a container | Containers share the host kernel, and on a Mac Docker runs only Linux. |
| Parallels Desktop | Snapshots and the `prlctl` command line make the revert, trigger, collect loop scriptable. |
| Windows 11 ARM on Apple Silicon | Same event channels, event IDs and IIS logs as x64. Emulating x86 is too slow. x64 PHP runs under Windows' built-in emulation. |
| Sysmon with a verbose config as the EDR stand-in | Records the same core events as Defender for Endpoint (process, network, file, registry, DNS) and keeps them locally. |
| Everything logged, then judged by default state | Every source is turned on so nothing is missed; the log source matrix then records which ones a default server has. |
| Fluent Bit in the VM, pulled per run | Each test run is collected as one unit. The VM holds no storage credentials. |
| Kusto emulator with real Sentinel table schemas | Queries written here run unchanged against `SecurityEvent`, `Event` and `W3CIISLog` in Microsoft Sentinel. |

</details>

All scripts are in [`scripts/`]({{ site.github.repository_url }}/tree/main/scripts); PowerShell scripts run inside the VM through `scripts/vm-run.sh <script.ps1>`.

| Stage | Result | Snapshot after |
| --- | --- | --- |
| [1. VM setup](1-vm-setup.html) | Windows 11 ARM VM, separated from the Mac, scriptable with `prlctl` | `clean-install` |
| [2. IIS and PHP](2-iis-php.html) | IIS + PHP 8.4 through FastCGI, PHP errors logged to a file | |
| [3. Logging](3-logging.html) | Sysmon, process and file auditing, PowerShell logging, all IIS fields, FREB | `logging-on` |
| [4. Collection](4-collection.html) | Fluent Bit, per-run pull, Azurite archive, Kusto Sentinel tables | `logging-baseline` |
| [5. Test runs](5-test-runs.html) | Revert, trigger, collect, query | |

**You need:** an Apple Silicon Mac, Parallels Desktop (Pro recommended, for `prlctl`), Docker Desktop, the Azure CLI (`az`) and Python 3.

---
title: Build steps
nav_order: 3
has_children: true
---

# Build steps

How to rebuild the Windows lab. All scripts are in [`scripts/`]({{ site.github.repository_url }}/tree/main/scripts); PowerShell scripts run inside the VM through `scripts/vm-run.sh <script.ps1>`.

| Stage | Result | Snapshot after |
| --- | --- | --- |
| [1. VM setup](1-vm-setup.html) | Windows 11 ARM VM, neutral identity, separated from the Mac, scriptable with `prlctl` | `clean-install` |
| [2. IIS and PHP](2-iis-php.html) | IIS + PHP 8.4 through FastCGI, PHP errors logged to a file | |
| [3. Logging](3-logging.html) | Sysmon, process and file auditing, PowerShell logging, all IIS fields, FREB | `logging-on` |
| [4. Collection](4-collection.html) | Fluent Bit, per-run pull, Azurite archive, Kusto Sentinel tables | `logging-baseline` |
| [5. Test runs](5-test-runs.html) | Revert, trigger, collect, query | |

**You need:** an Apple Silicon Mac, Parallels Desktop (Pro recommended, for `prlctl`), Docker Desktop, the Azure CLI (`az`) and Python 3.

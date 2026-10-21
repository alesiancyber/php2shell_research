---
title: 5. Test runs
parent: Build steps
nav_order: 5
---

# 5. Test runs

Every run starts from the `logging-baseline` snapshot, sends one harmless request, and is collected as a unit. Runs stay comparable and leave nothing behind.

```bash
scripts/revert.sh logging-baseline
curl -A "LAB-RUN-<id>" "http://<vm-ip>/<path>"                   # the trigger, tagged with the run id
scripts/collect-run.sh LAB-RUN-<id>
```

Repeat per PHP logging mode (Runs A, B and C, see [IIS and PHP](2-iis-php.html)).

## Looking at a run

```kusto
union SecurityEvent, Event, W3CIISLog, PhpErrorLog_CL, HttpErrLog_CL
| where _ResourceId == "winlab/LAB-RUN-<id>"
| where not(ParentProcessName endswith "prl_tools_service.exe")   // the lab's own remote commands
| where not(csUserAgent startswith "LAB-COLLECT-")                 // the collector's marker request
| summarize count() by Type
```

The trigger itself shows up in `W3CIISLog` with `csUserAgent == "LAB-RUN-<id>"`.

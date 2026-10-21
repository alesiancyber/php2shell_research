---
title: 5. Test runs
parent: Build steps
nav_order: 5
---

# 5. Test runs

Revert to the `logging-baseline` snapshot before each set of runs, set the PHP logging mode, then send each harmless trigger and collect it as its own run. Runs in the same logging mode were done back to back without reverting in between, so one FastCGI worker can span several runs: in file mode, the worker started by case A survives A and B1 and exits on B2 (see the [worker lifecycle evidence]({{ '/case-studies/cve-2026-109618.html#fastcgi-worker-lifecycle-securityevent-46884689-sysmon-15-in-event' | relative_url }})). The run id still separates each run's rows.

```bash
scripts/revert.sh logging-baseline                                # once per set of runs
curl -A "LAB-RUN-<id>" "http://<vm-ip>/<path>"                   # the trigger, tagged with the run id
scripts/collect-run.sh LAB-RUN-<id>
```

Repeat per PHP logging mode (file, syslog and unset; see [IIS and PHP](2-iis-php.html)).

## Looking at a run

```kusto
union SecurityEvent, Event, W3CIISLog, PhpErrorLog_CL, HttpErrLog_CL
| where _ResourceId == "winlab/LAB-RUN-<id>"
| where not(ParentProcessName endswith "prl_tools_service.exe")   // the lab's own remote commands
| where not(csUserAgent startswith "LAB-COLLECT-")                 // the collector's marker request
| summarize count() by Type
```

The trigger itself shows up in `W3CIISLog` with `csUserAgent == "LAB-RUN-<id>"`.

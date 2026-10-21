---
title: Detection coverage
nav_order: 4
---

# Detection coverage
{: .no_toc }

For each signal these CVEs produce, what monitoring you actually need to see it, and whether we expect a stock EDR to catch it on its own.
{: .fs-5 .fw-300 }

{: .warning }
**Initial research, not tested against a commercial EDR.** This was done within about two hours of the advisories being published. Sysmon stood in for the endpoint sensor, so the log and Sysmon results are measured, but every statement about what an EDR does or does not alert on is our expectation, based on how EDRs generally work. Vendors differ, and some may ship rules we have not accounted for. Without real sensors on the lab host, we cannot confirm these claims.

<details open markdown="block"><summary>Contents</summary>{: .text-delta }
1. TOC
{:toc}
</details>

## The short version

**We do not expect a stock EDR to catch the precondition of either CVE out of the box.** An OOM, a timeout, a worker that dies or gets reused — these look like ordinary web-server behaviour, and we know of no default EDR rule aimed at them. The EDR's more likely role is the **other end**: if the use-after-free is driven to code execution, an EDR should catch the *outcome* — `php-cgi.exe` spawning `cmd.exe` / `powershell.exe`, an unexpected child process, or outbound C2. That is behavioural endpoint detection, where stock EDR rules are generally strongest. Neither half was tested against a real EDR.

The **precondition tripwires** in this research — the signals that tell you someone is *probing* the memory-safety path before any shell exists — are almost all **SIEM / log-analytics** detections, not EDR detections. They need logs shipped and queried, not an endpoint sensor.

## Monitoring tiers

| Tier | What it is | On a default server? |
| --- | --- | --- |
| **T0 — IIS log** | IIS W3C request log. `sc-status`, `sc-win32-status`, `time-taken`, method, URI are all **default fields** | Yes, but only useful once **shipped** to a SIEM |
| **T1 — EDR** | Endpoint sensor: process / file / network / registry telemetry + behavioural rules (e.g. Defender for Endpoint) | Common, but it reads **endpoint events, not app logs** |
| **T2 — Process audit** | Sysmon (events 1/5) or Windows Security 4688/4689 | No — Sysmon must be installed; 4688/4689 are off by default |
| **T3 — PHP error logging** | `error_log` on (file or `syslog`) **and** shipped to the SIEM | No — `error_log` is unset by default |
| **T3+ — Deep app** | FREB, custom IIS fields, file-write SACL auditing | No — each enabled deliberately |

Key point about tiers: **T1 (EDR) and the app logs (T0, T3) generally do not overlap.** EDRs are not typically configured to ingest IIS or PHP file logs; a SIEM shipping IIS/PHP logs does not see process internals. The worker-lifecycle signals sit in T1/T2; everything else is T0/T3.

## CVE-2026-109618 (OOM) — coverage

| Signal | Minimum tier to *have* it | Stock EDR alert (expected) | Why |
| --- | --- | --- | --- |
| Parse-path OOM text (`Unknown on line 0`) | **T3** PHP log + ship | Not expected | EDRs generally do not read PHP logs; the text only exists there (or in the event log in `syslog` mode) |
| FastCGI worker **crash** (`php-cgi.exe` exits) | **T1 EDR** has the data (also T2 Sysmon 5 / Security 4689) | **Unlikely without a custom rule** | An EDR likely *records* the exit, but a web worker dying is benign-looking — expect to need a **custom rule** ("`php-cgi.exe` abnormal/short-lived exit"). Sysmon 5 and 4689 are the more reliable sources for the termination |
| IIS **500 + non-zero `win32status`** | **T0** IIS log + ship | Not expected | App log, not endpoint telemetry; a SIEM query, not an EDR rule |
| Oversized **413** (request filtering) | **T0** IIS log + ship | Not expected | App log |
| Script-level OOM with PHP logging off | — (effectively **invisible**) | Not expected | Only a bare IIS 500; nothing identifies it as an OOM |

**Reading it:** the loud case (parse-path OOM) is the most catchable — it shows in three independent places (PHP log, worker crash, non-zero win32 on the IIS 500), so even T0-only shops see *something*. The quiet case (script OOM) needs T3 or it is lost.

## CVE-2026-109619 (dangling state / timeout) — coverage

| Signal | Minimum tier to *have* it | Stock EDR alert (expected) | Why |
| --- | --- | --- | --- |
| Timeout fatal text (`Maximum execution time … exceeded`) | **T3** PHP log + ship | Not expected | PHP log only |
| IIS **500 with `time-taken` ≈ `max_execution_time`** | **T0** IIS log + ship | Not expected | App log; a SIEM query on the duration |
| Worker **reuse** after a fatal (no restart) | **T3 + T1/T2 correlated** | Not expected | Needs a PHP fatal (app log) **and** the absence of a worker restart (process telemetry), correlated by host + time. No single tier sees it, and IIS does not log which worker served a request, so the correlation is time-based and fuzzy |

**Reading it:** this CVE is the harder of the two to tripwire, because its signature is a *non-event* (a fatal that did **not** restart the worker). That is a cross-layer correlation — app log plus process telemetry — which most shops are not set up to do. The timeout fatal itself (T3) and the long-`time-taken` 500 (T0) are the practical early warnings.

## What to deploy, by return on effort

1. **Ship IIS W3C logs to the SIEM — do this first.** Free (default fields), and it alone covers the 413, the non-zero-`win32status` 500, and the long-`time-taken` timeout 500. Highest value for zero host change.
2. **Enable and ship PHP error logging** (`error_log = syslog` → Application channel → ship, or a file + a tail shipper). Adds the exact fatal text, including the `Unknown on line 0` parse-path signature. In `syslog` mode, parse `EventData`, not the rendered description (the PHP event source is unregistered).
3. **Process telemetry for the worker signals.** If you already run an EDR, check whether it alerts on `php-cgi.exe` abnormal termination, and add a **custom rule** if not; we expect most will not by default. No EDR → Sysmon (events 1/5) or enable Security 4688/4689.
4. **EDR behavioural rules on `php-cgi.exe` descendants and network** — the backstop for *successful* exploitation (shell spawn, C2), which is where we expect stock EDR behavioural detection to fire on its own (untested here).

## Bottom line

| | Precondition tripwire (this research) | Exploitation outcome |
| --- | --- | --- |
| Primary tool | **SIEM** over IIS + PHP logs (± process telemetry) | **EDR** behavioural rules |
| Stock EDR catches it? (expected, untested) | Unlikely | Likely (its purpose) |
| Effort | Log shipping + custom queries | Mostly built in |

Detections referenced here: [`kql/detections-109618.kql`]({{ site.github.repository_url }}/blob/main/kql/detections-109618.kql), [`kql/detections-109619.kql`]({{ site.github.repository_url }}/blob/main/kql/detections-109619.kql).

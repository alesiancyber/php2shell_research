# php2shell research

What a PHP vulnerability leaves in the logs on Windows, Linux and macOS, and which of those signals a detection pipeline actually receives. Logging and detection research only: tests use harmless requests that reach the same code path, never a working exploit.

> **Initial research.** Done within about two hours of the advisories being published, on one lab VM. The log results are measured. Statements about EDR behaviour are expectations: Sysmon stood in for the sensor, and without real EDR sensors we cannot confirm them.

**Full write-up:** https://alesiancyber.github.io/php2shell_research/

## What this is and what it is not

| This is | This is not |
| --- | --- |
| A record of where the **observable precondition** of specific PHP CVEs lands in Windows/IIS logs, both on a default server and with logging turned on | An exploit or proof of concept. The triggers never touch the bug; they only reach the same error class (an OOM, a timeout) |
| KQL detections, written against Sentinel table schemas, for those preconditions | A vulnerability scanner or patch check. The signals look the same on patched and unpatched PHP, so a hit means the precondition was reached, not that the host is vulnerable or compromised |
| A map of which monitoring tier (IIS log, PHP log, process telemetry, EDR) sees each signal | A detection of successful exploitation. Shell spawns and C2 are the EDR's job |
| A lab you can rebuild to check the findings yourself | Production-tuned rules. Thresholds and field formats come from one lab VM; tune them for your environment before deploying |
| | A hardening guide. The lab turns on far more logging than a real server has, on purpose |

## Findings (Windows / IIS / PHP 8.4 FastCGI)

| CVE | Class | Headline signal | Detections |
| --- | --- | --- | --- |
| [CVE-2026-109618](case-studies/cve-2026-109618.md) | Use-after-free via OOM handling | An OOM during multipart parsing logs `in Unknown on line 0` and crashes the FastCGI worker; a script OOM does not | [`detections-109618.kql`](kql/detections-109618.kql) |
| [CVE-2026-109619](case-studies/cve-2026-109619.md) | Use-after-free via dangling request state | A timeout or script OOM fatal leaves the worker running, so the next request reuses it | [`detections-109619.kql`](kql/detections-109619.kql) |

- **We do not expect a stock EDR to catch either precondition** (untested against a commercial EDR). An OOM, a timeout, or a worker that dies or gets reused looks like normal web-server behaviour. An EDR's more likely role is the exploitation outcome (`php-cgi.exe` spawning a shell, outbound C2). See [Detection coverage](detection-coverage.md).
- **The useful signals are SIEM detections over app logs:** the IIS log and the PHP error log, sometimes correlated with process telemetry.
- **Shipping the IIS log alone covers a lot.** Its default fields separate the cases: a 500 with a non-zero `win32status` (aborted worker), a 413 (oversized body), and a 500 whose `time-taken` ≈ `max_execution_time` (timeout).
- **PHP error logging is off by default.** With `error_log` unset, the fatal text is lost and a script OOM leaves only a bare IIS 500.
- **With `error_log = syslog`**, PHP writes to the Application log under an unregistered source. The real message is in `EventData`, not the rendered description.
- **Worker restart vs reuse decides the risk.** The parse-path OOM is loud (the worker crashes, which clears its state). The timeout and the script OOM are quiet (the worker is reused and carries its state forward). That quiet case is the one CVE-2026-109619 needs.

Linux and macOS are next, using the same method.

## Repo layout

| Path | What |
| --- | --- |
| `index.md` | Overview, scope, and the Windows log source matrix |
| `case-studies/` | One page per CVE: findings and detections |
| `detection-coverage.md` | Which monitoring tier sees each signal, and what we expect a stock EDR to catch |
| `kql/detections-*.kql` | Detection queries per CVE |
| `triggers/` | Benign request generators for each precondition |
| `build/` | Steps to rebuild the lab and check the findings |
| `scripts/` | Every script the lab uses. `.ps1` files run inside the Windows VM through `vm-run.sh` |
| `kql/tables.kql` | Kusto tables the lab writes to (Sentinel schemas plus two custom tables) |
| `kql/transform.kql` | Maps raw Fluent Bit records into those tables |
| `lab-data/` | Local state: runs, certs, SAS, databases. Git-ignored |

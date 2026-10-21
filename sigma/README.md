# Sigma rules

The detections from `kql/detections-*.kql` as [Sigma](https://sigmahq.io) rules, the vendor-neutral format that SIEM backends (Sentinel/KQL, Splunk, Elastic and others) compile into their own query language. Like the KQL versions, these fire on the observable precondition and do not depend on PHP being unpatched.

| Rule | KQL equivalent | Log source | Compiles to KQL | Matched in lab data |
| --- | --- | --- | --- | --- |
| [`php-parse-path-oom.yml`](cve-2026-109618/php-parse-path-oom.yml) | 109618 query 1 | PHP error log | Yes | B2 (file) |
| [`php-parse-path-oom-eventlog.yml`](cve-2026-109618/php-parse-path-oom-eventlog.yml) | 109618 query 1b | Windows Application log | Yes | B2 (syslog) |
| [`php-cgi-exit-after-post-500.yml`](cve-2026-109618/php-cgi-exit-after-post-500.yml) | 109618 query 2 | IIS log + process termination (correlation) | No, see below | not run |
| [`iis-aborted-fastcgi-worker.yml`](cve-2026-109618/iis-aborted-fastcgi-worker.yml) | 109618 query 3 | IIS log | Yes | B2 (file, syslog, unset) |
| [`iis-413-burst.yml`](cve-2026-109618/iis-413-burst.yml) | 109618 query 4 | IIS log (correlation) | No, see below | not run |
| [`php-timeout-fatal.yml`](cve-2026-109619/php-timeout-fatal.yml) | 109619 Detection A | PHP error log | Yes | 109619 timeout |
| [`iis-500-long-time-taken.yml`](cve-2026-109619/iis-500-long-time-taken.yml) | 109619 Detection A2 | IIS log | Yes | 109619 timeout |

All rules pass `sigma check` with no errors or issues. The "Matched in lab data" column comes from compiling each rule with the pipeline below and running it against the lab's Kusto tables: each one matched exactly the expected runs.

**Not converted:**
- **109619 Detection B** (a PHP fatal with *no* worker restart nearby). Its signal is the absence of an event, and Sigma has no way to express "no matching event within N seconds". It stays KQL only.
- **109618 query 0** is a lab triage summary, not a detection.

## Converting

```bash
pip install sigma-cli pySigma-backend-kusto
sigma check sigma/
sigma convert -t kusto -p sigma/pipelines/sentinel-winlab.yml sigma/cve-2026-109618/iis-aborted-fastcgi-worker.yml
# W3CIISLog
# | where (csMethod =~ "POST" and scStatus == 500) and (not(scWin32Status == 0))
```

[`pipelines/sentinel-winlab.yml`](pipelines/sentinel-winlab.yml) maps the rules' generic log sources to Sentinel tables: `W3CIISLog`, `Event`, `SecurityEvent` (4689), and `PhpErrorLog_CL` for the PHP error log. The stock Kusto pipelines do not cover IIS or PHP logs. If your workspace uses different table names, edit them there.

**Correlation rules** (the 413 burst and the worker exit after a POST 500) are valid Sigma, but the Kusto backend does not support correlations yet. Backends that do, such as Splunk (`sigma convert -t splunk`), compile them. For Sentinel, use the KQL versions in `kql/detections-109618.kql`.

The PHP error log has no standard Sigma log source, so these rules use `category: application, product: php` (the convention Sigma uses for other application logs) and keyword matching on the raw log line.

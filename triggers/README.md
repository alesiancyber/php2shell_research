# Triggers

Benign generators for each CVE's observable precondition. None of them touch the bug.

## CVE-2026-109618 (PHP OOM during request parsing)

Benign generators of the vulnerability's **precondition** (a request driving PHP to its memory limit).
No exploit, no payload: PHP simply reaches its memory ceiling and logs a fatal error. Three cases:

| Case | How | Result |
| --- | --- | --- |
| A — script OOM | GET `oom-alloc.php` (sets `memory_limit` to 32M, then allocates past it) | PHP fatal names the script + line; `php-cgi.exe` survives; IIS 500 / win32 0 |
| B1 — oversized body | POST a multipart body larger than IIS `maxAllowedContentLength` (~30 MB) | IIS 413 before PHP runs |
| B2 — parse-path OOM | lower `memory_limit` (`scripts/set-ini.ps1 -Pairs 'memory_limit=24M;post_max_size=128M'`), POST a ~27 MB multipart body (under the IIS limit, over `memory_limit`) | PHP fatal `in Unknown on line 0`; `php-cgi.exe` terminates; IIS 500 / non-zero win32 |

Build a multipart body on the Mac:

```bash
python3 - <<'PY'
b="----labboundary"; parts=[]
for i in range(13):  # 13 x 2 MB ~= 27 MB, under the 30 MB IIS limit
    parts.append(f"--{b}\r\nContent-Disposition: form-data; name=\"f{i}\"\r\n\r\n"+("A"*(2*1024*1024))+"\r\n")
open("body.bin","wb").write(("".join(parts)+f"--{b}--\r\n").encode())
PY
curl -A "LAB-RUN-<id>" -X POST --data-binary @body.bin \
  -H "Content-Type: multipart/form-data; boundary=----labboundary" "http://<vm-ip>/oom-multipart.php"
```

Detections that fire on these: [`kql/detections-109618.kql`](../kql/detections-109618.kql).

## CVE-2026-109619 (dangling request state)

Benign generators of a fatal that leaves the FastCGI worker reusable.

| File | How | Result |
| --- | --- | --- |
| `timeout.php` | GET; sets a 2 s time limit, then busy-loops past it | PHP fatal `Maximum execution time of 2 seconds exceeded`; IIS 500 with `time-taken` ≈ 2000 ms; `php-cgi.exe` survives |
| `pid.php` | GET before and after `timeout.php` | Prints `LAB-PID=<pid>`; the same pid both times shows the worker was reused |

```bash
curl -A "LAB-RUN-<id>" "http://<vm-ip>/pid.php"
curl -A "LAB-RUN-<id>" "http://<vm-ip>/timeout.php"
curl -A "LAB-RUN-<id>" "http://<vm-ip>/pid.php"
```

Detections that fire on these: [`kql/detections-109619.kql`](../kql/detections-109619.kql).

---
title: Case studies
nav_order: 2
has_children: true
---

# Case studies

One page per CVE: the vulnerability's observable precondition, generated benignly (no exploit), and what it leaves in the logs on Windows/IIS. Each lists ready-to-run detections.

| CVE | Class | Precondition we generate | Headline signal |
| --- | --- | --- | --- |
| [CVE-2026-109618](cve-2026-109618.html) | Use-after-free via OOM handling | A request that drives PHP to its memory limit | Parse-path OOM (`Unknown on line 0`) crashes the FastCGI worker |
| [CVE-2026-109619](cve-2026-109619.html) | Use-after-free via dangling request state | A fatal (timeout or OOM) that leaves a worker reusable | A fatal with **no** worker restart = state carried into the next request |

Both are memory-safety flaws fixed in PHP 8.2.35 / 8.3.36 / 8.4.27 / 8.5.12. The detections fire on the precondition, so they work regardless of patch level.

# php2shell research

What a PHP vulnerability leaves in the logs on Windows, Linux and macOS, and which of those signals a detection pipeline actually receives. Logging and detection research only: tests use harmless requests that reach the same code path, never a working exploit.

**Read it as a site:** the GitHub Pages site built from this repo (Settings → Pages).

| Path | What |
| --- | --- |
| `index.md` | Overview, scope, and the Windows log source matrix |
| `case-studies/` | One page per CVE: findings and detections |
| `detection-coverage.md` | Which monitoring tier sees each signal, and what a stock EDR catches |
| `kql/detections-*.kql` | Detection queries per CVE |
| `triggers/` | Benign request generators for each precondition |
| `build/` | Steps to rebuild the lab and check the findings |
| `scripts/` | Every script the lab uses. `.ps1` files run inside the Windows VM through `vm-run.sh` |
| `kql/tables.kql` | Kusto tables the lab writes to (Sentinel schemas plus two custom tables) |
| `kql/transform.kql` | Maps raw Fluent Bit records into those tables |
| `docker-compose.yml` | Azurite and the Kusto emulator for the Mac side |
| `lab-data/` | Local state: runs, certs, SAS, databases. Git-ignored |

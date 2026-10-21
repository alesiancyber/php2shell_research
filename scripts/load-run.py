#!/usr/bin/env python3
"""Load one collected run into the Kusto emulator (database WinLab).
   load-run.py <run-id>
Reads the run's files from Azurite (winlab/runs/<run-id>/), so collect-run.sh must have uploaded them.
Needs WINLAB_READ_SAS in the environment (collect-run.sh sources $WINLAB_DATA/.env).
WINLAB_DATA (default <repo>/lab-data) holds runs/; kql/transform.kql comes from the repo."""
import os
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from kx import kusto  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parent.parent
DATA = pathlib.Path(os.environ.get("WINLAB_DATA", REPO / "lab-data"))
# Azurite as the Kusto container sees it
BLOB = os.environ.get("WINLAB_BLOB", "https://host.docker.internal:10000/devstoreaccount1/winlab/runs")
STAGE = {"winevt.jsonl": "_Stage_WinEvt", "iis.jsonl": "_Stage_Iis", "php.jsonl": "_Stage_Php", "httperr.jsonl": "_Stage_HttpErr"}
MAPPING = '[{"column":"Record","Properties":{"Path":"$"}}]'
TARGETS = ["SecurityEvent", "Event", "W3CIISLog", "PhpErrorLog_CL", "HttpErrLog_CL"]


def must(csl, what):
    ok, _, res = kusto(csl)
    if not ok:
        sys.exit(f"{what} failed: {res}")


def main(run):
    sas = os.environ["WINLAB_READ_SAS"]
    local = DATA / "runs" / run
    computer = dict(l.split("=", 1) for l in (local / "run.txt").read_text().split() if "=" in l).get("computer", "")
    blocks = re.split(r"(?m)^// ---.*$", (REPO / "kql" / "transform.kql").read_text())
    # Strip comment-only lines; skip the header block.
    cmds = ["\n".join(l for l in b.splitlines() if not l.lstrip().startswith("//")).strip() for b in blocks]
    cmds = [c.replace("{RUN}", run).replace("{COMPUTER}", computer) for c in cmds if c]
    setup = [c for c in cmds if c.startswith(".create")]
    rest = [c for c in cmds if not c.startswith(".create")]

    for c in setup:
        must(c, c.splitlines()[0][:60])
    for c in (c for c in rest if c.startswith(".clear")):  # empty staging from any earlier failed load
        must(c, c)
    for t in TARGETS:  # reloading a run replaces its rows instead of duplicating them
        must(f'.delete table {t} records <| {t} | where _ResourceId == "winlab/{run}"', f"delete old {t} rows")
    for name, table in STAGE.items():
        if not (local / name).exists() or (local / name).stat().st_size == 0:
            print(f"  {name:14} (none)")
            continue
        must(f'.ingest into table {table} (h@"{BLOB}/{run}/{name}?{sas}") '
             f"with (format='multijson', ingestionMapping='{MAPPING}')", f"ingest {name}")
        _, _, rows = kusto(f"{table} | count")
        print(f"  {name:14} {rows[0][0]:>7} records staged")
    for c in rest:
        must(c, c.splitlines()[0][:60])
    _, _, rows = kusto(f'union withsource=T {", ".join(TARGETS)} '
                       f'| where _ResourceId == "winlab/{run}" | summarize Rows = count() by T | order by T asc')
    for t, n in rows:
        print(f"  -> {t:16} {n:>7}")


if __name__ == "__main__":
    main(sys.argv[1])

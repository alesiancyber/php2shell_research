#!/usr/bin/env python3
"""Export the case-study evidence from the Kusto emulator to CSV.
   export-evidence.py
Runs every block in kql/evidence.kql (each starts with "// --- out: <cve>/<name>") against database WinLab
and writes evidence/<cve>/<name>.csv. Re-running overwrites the files."""
import csv
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from kx import kusto  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parent.parent


def main():
    text = (REPO / "kql" / "evidence.kql").read_text()
    for name, block in re.findall(r"(?m)^// --- out: (\S+)\n(.*?)(?=^// --- out:|\Z)", text, re.S):
        csl = "\n".join(l for l in block.splitlines() if not l.lstrip().startswith("//")).strip()
        ok, cols, rows = kusto(csl)
        if not ok:
            sys.exit(f"{name} failed: {rows}")
        out = REPO / "evidence" / f"{name}.csv"
        out.parent.mkdir(parents=True, exist_ok=True)
        with out.open("w", newline="") as f:
            w = csv.writer(f)
            w.writerow(cols)
            w.writerows(["" if v is None else v for v in r] for r in rows)
        print(f"{len(rows):4} rows  {out.relative_to(REPO)}")


if __name__ == "__main__":
    main()

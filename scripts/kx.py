#!/usr/bin/env python3
"""Run a KQL query or management command against the local Kusto emulator and print a compact result.
   kx.py '<csl>'                  database WinLab (KDB env overrides), endpoint picked from the leading '.'
   kx.py -d NetDefaultDB '<csl>'
   kx.py -f kql/tables.kql       run every command in a file (separated by lines of "// ---")
Importable: from kx import kusto  ->  kusto(csl, db='WinLab') returns (ok, columns, rows | error text)."""
import json
import os
import re
import sys
import urllib.error
import urllib.request

URL = os.environ.get("KUSTO_URL", "http://localhost:8085")


def kusto(csl, db=None, timeout=300):
    db = db or os.environ.get("KDB", "WinLab")
    ep = "mgmt" if csl.lstrip().startswith(".") else "query"
    req = urllib.request.Request(f"{URL}/v1/rest/{ep}", data=json.dumps({"db": db, "csl": csl}).encode(),
                                 headers={"Content-Type": "application/json", "Accept": "application/json"})
    try:
        raw = urllib.request.urlopen(req, timeout=timeout).read().decode()
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            err = json.loads(raw)["error"]
            return False, None, err.get("@message") or err.get("message") or raw[:1000]
        except (ValueError, KeyError):
            return False, None, raw[:1000]
    body = json.loads(raw)
    tables = body["Tables"] if isinstance(body, dict) else [t for t in body if t.get("TableKind") == "PrimaryResult"]
    t = tables[0]
    return True, [c["ColumnName"] for c in t["Columns"]], t["Rows"]


if __name__ == "__main__":
    args = sys.argv[1:]
    db = None
    if args[:1] == ["-d"]:
        db, args = args[1], args[2:]
    if args[:1] == ["-f"]:
        text = open(args[1]).read()
        for block in re.split(r"(?m)^// ---.*$", text):
            csl = "\n".join(l for l in block.splitlines() if not l.lstrip().startswith("//")).strip()
            if not csl:
                continue
            ok, _, res = kusto(csl, db)
            print(("ok   " if ok else "FAIL ") + csl.splitlines()[0][:90] + ("" if ok else f"\n     {res}"))
        sys.exit(0)
    ok, cols, rows = kusto(args[0], db)
    if not ok:
        print("ERROR:", rows)
        sys.exit(1)
    print("  ".join(cols))
    for r in rows[:50]:
        print("  ".join("" if v is None else str(v)[:120] for v in r))
    print(f"({len(rows)} rows)")

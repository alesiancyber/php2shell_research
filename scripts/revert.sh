#!/usr/bin/env bash
# Revert the lab VM to a snapshot by name (prlctl only takes ids). An exact name match wins; otherwise the
# newest snapshot whose name starts with it (prlctl cannot rename, so baselines get -v2, -v3...).
#   revert.sh [snapshot-name]        default: logging-baseline
set -euo pipefail
VM="${VM:-WinLab}"
NAME="${1:-logging-baseline}"
ID="$(prlctl snapshot-list "$VM" -j | python3 -I -c 'import json,sys; n=sys.argv[1]; s=json.load(sys.stdin); m=[k for k,v in s.items() if v["name"]==n] or sorted((k for k,v in s.items() if v["name"].startswith(n)), key=lambda k: s[k]["date"]); print(m[-1] if m else "")' "$NAME")"
[ -n "$ID" ] || { echo "no snapshot named '$NAME' on $VM"; exit 1; }
prlctl snapshot-switch "$VM" -i "$ID"

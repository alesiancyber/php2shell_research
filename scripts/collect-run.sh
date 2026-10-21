#!/usr/bin/env bash
# Collect one test run: package it in the VM, pull it to $WINLAB_DATA/runs/<run-id>/,
# archive it in Azurite (container winlab, runs/<run-id>/) and load it into Kusto (database WinLab).
#   collect-run.sh <run-id>         e.g. collect-run.sh LAB-RUN-20261021-1530-A
#
# Settings (environment):
#   VM             Parallels VM name                          default "WinLab"
#   WINLAB_DATA    where runs are kept + the .env file         default <repo>/lab-data
#   AZURITE_CONN   Azurite connection string (HTTPS blob endpoint)  required
#   AZURITE_CA     Azurite's self-signed cert, for az CLI      default $WINLAB_DATA/certs/cert.pem
#   $WINLAB_DATA/.env must define WINLAB_READ_SAS (read/list SAS on the winlab container).
# Needs: the VM running, Azurite up, the Kusto emulator up with database WinLab.
set -euo pipefail
RUN="${1:?usage: collect-run.sh <run-id>}"
[[ "$RUN" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "run id: letters, digits, - and _ only"; exit 1; }
VM="${VM:-WinLab}"
HERE="$(cd "$(dirname "$0")" && pwd)"
export WINLAB_DATA="${WINLAB_DATA:-$(dirname "$HERE")/lab-data}"
: "${AZURITE_CONN:?set AZURITE_CONN to the Azurite connection string}"
AZURITE_CA="${AZURITE_CA:-$WINLAB_DATA/certs/cert.pem}"
OUT="$WINLAB_DATA/runs/$RUN"
mkdir -p "$OUT"

echo "== package in VM"
"$HERE/vm-run.sh" "$HERE/collect-vm.ps1" -Run "$RUN"

echo "== pull to $OUT"
prlctl exec "$VM" powershell -NoProfile -Command \
  "[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\\Lab\\ship\\out\\$RUN.zip'))" | tr -d '\r\n' | base64 -D > "$OUT/$RUN.zip"
(cd "$OUT" && unzip -oq "$RUN.zip" && rm "$RUN.zip")
ls -l "$OUT" | tail -n +2

echo "== upload to Azurite winlab/runs/$RUN"
REQUESTS_CA_BUNDLE="$AZURITE_CA" az storage blob upload-batch -d winlab --destination-path "runs/$RUN" \
  -s "$OUT" --overwrite --connection-string "$AZURITE_CONN" -o none 2>/dev/null

echo "== load into Kusto (WinLab)"
set -a; source "$WINLAB_DATA/.env"; set +a
python3 -I "$HERE/load-run.py" "$RUN"

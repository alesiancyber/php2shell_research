#!/usr/bin/env bash
# Copy a local file into the lab VM over stdin (keeps contents out of process command lines).
#   vm-push.sh <local file> 'C:\Lab\name.ext'
set -euo pipefail
VM="${VM:-WinLab}"
prlctl exec "$VM" powershell -NoProfile -Command "\$d = Split-Path '$2'; New-Item -ItemType Directory \$d -Force | Out-Null; [Console]::In.ReadToEnd() | Set-Content '$2' -Encoding ascii -NoNewline" < "$1"

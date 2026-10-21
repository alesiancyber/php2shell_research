#!/usr/bin/env bash
# Copy a local PowerShell script into the lab VM (C:\Lab\<name>) and run it as SYSTEM.
# prlctl exec chokes on long arguments, so the script travels over stdin.
# prlctl sometimes fails with "PrlJob_...: Invalid argument" before anything runs; those attempts are retried.
#   vm-run.sh phase4-fluentbit.ps1 [args...]
set -uo pipefail
VM="${VM:-WinLab}"
src="$1"; shift
name="$(basename "$src")"
try() {  # run a prlctl command up to 3 times while it fails with a PrlJob_ error and no other output
  local out rc
  for _ in 1 2 3; do
    out="$("$@" 2>&1)"; rc=$?
    if [ $rc -ne 0 ] && [ "$(printf '%s' "$out" | grep -vc '^PrlJob_')" -eq 0 ]; then sleep 2; continue; fi
    printf '%s\n' "$out"; return $rc
  done
  printf '%s\n' "$out"; return $rc
}
try prlctl exec "$VM" powershell -NoProfile -Command "New-Item -ItemType Directory C:\\Lab -Force | Out-Null; [Console]::In.ReadToEnd() | Set-Content C:\\Lab\\$name -Encoding utf8" < "$src" >/dev/null || exit $?
try prlctl exec "$VM" powershell -NoProfile -ExecutionPolicy Bypass -File "C:\\Lab\\$name" "$@"

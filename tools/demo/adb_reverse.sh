#!/usr/bin/env bash
# Forwards the Firebase emulator ports over USB to every connected phone, so the
# app can use EMULATOR_HOST=127.0.0.1 (docs/DEMO.md, DEV_RELAXATIONS.md R-4).
set -euo pipefail

PORTS=(9099 8080 5001 9199 4000)

devices=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
if [ -z "$devices" ]; then
  echo "No connected devices (check USB debugging and 'adb devices')." >&2
  exit 1
fi

for serial in $devices; do
  for port in "${PORTS[@]}"; do
    adb -s "$serial" reverse "tcp:$port" "tcp:$port" >/dev/null
  done
  echo "Forwarded ${PORTS[*]} on $serial"
done

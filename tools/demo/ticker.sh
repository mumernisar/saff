#!/usr/bin/env bash
# Dev stand-in for Cloud Scheduler (docs/DEV_RELAXATIONS.md R-11): calls the
# sweeper endpoint of the Functions emulator every 10 seconds.
HOST="${EMULATOR_HOST:-127.0.0.1}"
while true; do
  curl -s "http://$HOST:5001/saff-dev-d9605/us-central1/tick" >/dev/null
  sleep 10
done

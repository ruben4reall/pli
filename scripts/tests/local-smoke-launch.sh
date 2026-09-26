#!/bin/bash
# scripts/tests/local-smoke-launch.sh: builds an ad hoc Release app and checks that it launches and keeps running.
# Local only: it shows Pli's menu bar icon for a few seconds. It catches a framework the app cannot load, such as
# Sparkle refused by library validation.
set -euo pipefail
cd "$(dirname "$0")/../.."
APP=$(scripts/build.sh Release)
pkill -x Pli 2>/dev/null || true
# -SUEnableAutomaticChecks NO keeps Sparkle's second-launch question away during tests.
open -n --env PLI_LID_SIMULATOR=1 "$APP" --args -SUEnableAutomaticChecks NO
sleep 4
if ! pgrep -x Pli >/dev/null; then
  echo "FAIL: Pli is not running 4 s after launch" >&2
  /usr/bin/log show --last 30s --style compact --predicate 'process == "Pli"' | tail -n 20 >&2
  exit 1
fi
# Read whole, then matched: with pipefail, "log show | grep -q" fails when grep stops reading early (SIGPIPE).
recent=$(/usr/bin/log show --last 10s --info --style compact --predicate 'subsystem == "ch.rubencatalao.pli"' || true)
if [[ "$recent" != *"Pli started"* ]]; then
  pkill -x Pli
  echo "FAIL: no 'Pli started' line in the log" >&2
  exit 1
fi
pkill -x Pli
echo "PASS: $APP launches and runs"

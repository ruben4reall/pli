#!/bin/bash
# scripts/tests/run.sh: runs every scripts/tests/test-*.sh (fast: no network, no signing, no app build). CI runs it.
# The slow local checks are scripts/tests/local-*.sh.
set -uo pipefail
cd "$(dirname "$0")/../.."
failed=0
for test in scripts/tests/test-*.sh; do
  echo "$test"
  if bash "$test" </dev/null; then :; else failed=$((failed + 1)); fi
done
[ "$failed" -eq 0 ] || { echo "$failed test file(s) failed" >&2; exit 1; }
echo "All script tests passed."

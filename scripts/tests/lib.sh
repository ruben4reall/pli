# scripts/tests/lib.sh: helpers for the script tests, sourced by each scripts/tests/test-*.sh.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

check() {   # check <what> <command…>: the command must succeed
  local what="$1"; shift
  if "$@" </dev/null >"$TMP/out" 2>&1; then
    echo "  ok: $what"
  else
    echo "  FAILED: $what" >&2; cat "$TMP/out" >&2; exit 1
  fi
}

refuses() {   # refuses <what> <expected text> <command…>: the command must fail and say <expected text>
  local what="$1" expected="$2"; shift 2
  if "$@" </dev/null >"$TMP/out" 2>&1; then
    echo "  FAILED: $what (it succeeded)" >&2; cat "$TMP/out" >&2; exit 1
  fi
  grep -qF -- "$expected" "$TMP/out" || { echo "  FAILED: $what (no '$expected')" >&2; cat "$TMP/out" >&2; exit 1; }
  echo "  ok: $what"
}

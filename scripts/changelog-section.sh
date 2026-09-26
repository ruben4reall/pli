#!/bin/bash
# scripts/changelog-section.sh <version> [CHANGELOG.md]: prints the body of that version's section (the lines after
# its "## <version> (<date>)" heading, up to the next "## " heading), without leading and trailing blank lines.
# Exits 1 when the version has no section, or an empty one.
set -euo pipefail
VERSION="${1:?usage: scripts/changelog-section.sh <version> [CHANGELOG.md]}"
FILE="${2:-$(dirname "$0")/../CHANGELOG.md}"
awk -v v="$VERSION" '
  index($0, "## ") == 1 {
    if (inside) exit
    if (index($0, "## " v " ") == 1 || $0 == "## " v) { inside = 1; next }
  }
  inside { lines[++n] = $0 }
  END {
    first = 1; while (first <= n && lines[first] ~ /^[[:space:]]*$/) first++
    last = n; while (last >= first && lines[last] ~ /^[[:space:]]*$/) last--
    if (last < first) { print "changelog-section: no section for " v > "/dev/stderr"; exit 1 }
    for (i = first; i <= last; i++) print lines[i]
  }' "$FILE"

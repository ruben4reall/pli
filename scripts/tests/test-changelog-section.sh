#!/bin/bash
# Release notes come from exactly one CHANGELOG section.
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
cat > "$TMP/CHANGELOG.md" <<'EOF'
# Changelog

## 1.0.10 (2026-12-01)

- Ten.

## 1.0.1 (2026-10-20)

Fixes.

- One.

## 1.0.0 (2026-10-15)

- First.
EOF
section() { scripts/changelog-section.sh "$1" "$TMP/CHANGELOG.md"; }
same() { [ "$1" = "$2" ]; }
check "a middle section, trimmed" same "$(section 1.0.1)" "$(printf 'Fixes.\n\n- One.')"
check "the last section" same "$(section 1.0.0)" "- First."
check "1.0.10 is its own section" same "$(section 1.0.10)" "- Ten."
refuses "a version without a section" "no section for 2.0.0" section 2.0.0

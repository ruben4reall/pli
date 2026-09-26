#!/bin/bash
# scripts/verify-update.swift accepts exactly the disk image the appcast signs, and nothing else.
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
swift scripts/tests/make-update-fixture.swift "$TMP/release" >/dev/null
swift scripts/tests/make-update-fixture.swift "$TMP/other" >/dev/null      # another key pair
R="$TMP/release"
verify() { swift scripts/verify-update.swift "$1" "$R/appcast.xml" "$2" "$3"; }
check "the signed image passes" verify "$R/Info.plist" 1.0.0 "$R/Pli-1.0.0.dmg"
cp "$R/Pli-1.0.0.dmg" "$TMP/changed.dmg" && printf 'B' | dd of="$TMP/changed.dmg" bs=1 seek=100 conv=notrunc 2>/dev/null
refuses "a changed byte fails" "signature does not match" verify "$R/Info.plist" 1.0.0 "$TMP/changed.dmg"
cp "$R/Pli-1.0.0.dmg" "$TMP/longer.dmg" && printf 'A' >> "$TMP/longer.dmg"
refuses "another length fails" "the appcast says" verify "$R/Info.plist" 1.0.0 "$TMP/longer.dmg"
refuses "a version the appcast does not offer fails" "offers no 1.0.1" verify "$R/Info.plist" 1.0.1 "$R/Pli-1.0.0.dmg"
refuses "another key fails" "signature does not match" verify "$TMP/other/Info.plist" 1.0.0 "$R/Pli-1.0.0.dmg"

#!/bin/bash
# The installer background: drawn from the brand, sized for Finder, light where Finder writes the labels.
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
for hex in FFFFFF F5F5F7 1D1D1F 6E6E73 D2D2D7 A6F0FF C8B8FF FFD3B0; do
  check "brand token #$hex is in brand/tokens/tokens.json" grep -qi "$hex" brand/tokens/tokens.json
done
check "the script draws a background" swift scripts/make-dmg-background.swift "$TMP/background.png"
check "a fresh background passes the layout checks" swift scripts/tests/check-dmg-background.swift "$TMP/background.png"
check "the committed background passes the layout checks" swift scripts/tests/check-dmg-background.swift docs/brand/dmg-background.png
dpi_144() { [[ "$(sips -g dpiWidth "$1")" == *"dpiWidth: 144"* ]]; }
check "the committed background is marked 144 dpi, so Finder shows it at 660 x 400 points" dpi_144 docs/brand/dmg-background.png

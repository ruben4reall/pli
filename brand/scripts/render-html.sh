#!/bin/bash
# brand/scripts/render-html.sh <input.html> <output.png> <width> <height> [background]
# background: optional page background as RRGGBBAA hex (00000000 keeps the
# page transparent); without it, Chrome's default white.
set -euo pipefail
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 ${5:+--default-background-color="$5"} \
  --window-size="$3,$4" --screenshot="$2" "file://$(cd "$(dirname "$1")" && pwd)/$(basename "$1")" >/dev/null 2>&1
test -s "$2"

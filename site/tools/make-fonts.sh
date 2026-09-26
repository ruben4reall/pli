#!/bin/bash
# Makes assets/fonts/inter-400.woff2 and inter-600.woff2: Inter 4.1 (SIL OFL 1.1), cut down to the characters
# the page uses. Needs the network once: the Inter release on GitHub and fonttools from PyPI, both kept in a
# temporary folder that is deleted at the end. Usage: tools/make-fonts.sh   (from site/)
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

release="https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip"
curl -fsSL -o "$work/inter.zip" "$release"
python3 -m venv "$work/venv"
"$work/venv/bin/pip" install --quiet fonttools brotli

# Keep in step with the unicode-range of the @font-face rules in css/site.css.
unicodes="U+0000-00FF,U+0131,U+0152-0153,U+02C6,U+02DA,U+02DC,U+2000-206F,U+2190-2199,U+2212,U+2303,U+2318,U+2325"
mkdir -p assets/fonts
for pair in 400:Regular 600:SemiBold; do
  weight="${pair%%:*}"
  style="${pair##*:}"
  member=""
  for ext in ttf otf woff2; do
    member="$(unzip -Z1 "$work/inter.zip" | grep -E "(^|/)Inter-${style}\.${ext}\$" | head -n 1 || true)"
    [ -n "$member" ] && break
  done
  [ -n "$member" ] || { echo "Inter-${style} is not in $release" >&2; exit 1; }
  unzip -p "$work/inter.zip" "$member" > "$work/source-${weight}.${member##*.}"
  "$work/venv/bin/pyftsubset" "$work/source-${weight}.${member##*.}" --unicodes="$unicodes" \
    --flavor=woff2 --layout-features='kern,liga,calt,case,tnum' --output-file="assets/fonts/inter-${weight}.woff2"
done
license="$(unzip -Z1 "$work/inter.zip" | grep -E '(^|/)LICENSE\.txt$' | head -n 1 || true)"
[ -n "$license" ] || { echo "LICENSE.txt is not in $release" >&2; exit 1; }
unzip -p "$work/inter.zip" "$license" > assets/fonts/LICENSE-Inter.txt
printf 'Inter 4.1 from %s\nsha256 %s\nSubset: %s\n' "$release" "$(shasum -a 256 "$work/inter.zip" | cut -d' ' -f1)" "$unicodes" > assets/fonts/SOURCE.txt
ls -l assets/fonts

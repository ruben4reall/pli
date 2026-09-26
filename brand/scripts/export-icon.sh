#!/bin/bash
# brand/scripts/export-icon.sh: renders brand/Pli.icon to brand/icon-previews/
#   default-1024.png ... default-16.png   the Default rendition, with the macOS mask and edge
#   Dark-1024.png, ClearLight-1024.png, TintedDark-1024.png   the other renditions
#   opaque-1024.png   the square artwork: the icon's background out to the
#                     edges, no mask and no edge (for an apple-touch icon), sRGB
# Run node brand/scripts/icon/layers.mjs first when the icon changed. Needs Xcode 26
# (ictool), ImageMagick, Node and Google Chrome (through render-html.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
ictool="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
srgb="/System/Library/ColorSync/Profiles/sRGB Profile.icc"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p icon-previews
previews=()
for size in 1024 128 64 32 16; do
  "$ictool" Pli.icon --export-image --output-file "icon-previews/default-$size.png" --platform macOS --rendition Default --width "$size" --height "$size" --scale 1
  previews+=("icon-previews/default-$size.png")
done
for rendition in Dark ClearLight TintedDark; do
  "$ictool" Pli.icon --export-image --output-file "icon-previews/$rendition-1024.png" --platform macOS --rendition "$rendition" --width 1024 --height 1024 --scale 1
  previews+=("icon-previews/$rendition-1024.png")
done

# opaque-1024.png: ictool always applies the macOS mask and edge, so the
# Default rendition is kept inside the body and the icon's own background,
# drawn from the same tokens, takes over toward the edges: a 28 px ramp that
# starts 36 px inside the body's outline, where the system edge has faded out
# and nothing of the laptop or its shadow remains.
node scripts/icon/layers.mjs --square-background "$tmp/background.svg"
scripts/render-html.sh "$tmp/background.svg" "$tmp/background.png" 1024 1024
magick icon-previews/default-1024.png -profile "$srgb" -alpha off "$tmp/body.png"
magick icon-previews/default-1024.png -alpha extract +profile '*' -threshold 50% -bordercolor black -border 2 \
  -morphology Distance Euclidean:4,1 -shave 2x2 -level 36,64 "$tmp/ramp.png"
magick "$tmp/background.png" -alpha off "$tmp/body.png" "$tmp/ramp.png" -composite -strip -depth 8 \
  -define png:exclude-chunks=date,tIME PNG24:icon-previews/opaque-1024.png

# ictool writes some previews as 16-bit PNG: convert them to 8-bit RGBA.
# The color profile is kept (ictool tags wide-color previews Display P3); the
# timestamp chunks are left out so that an unchanged icon exports identical files.
for f in "${previews[@]}"; do
  magick "$f" -depth 8 -define png:exclude-chunks=bKGD,cHRM,date,tIME PNG32:"$f"
done

#!/bin/bash
# brand/scripts/export-marketing.sh: renders the marketing images to docs/brand/
#   social-preview.png       1280 x 640, opaque (GitHub social preview, og:image)
#   readme-header.png        1600 x 480, light, transparent corners
#   readme-header-dark.png   1600 x 480, dark, transparent corners
set -euo pipefail
cd "$(dirname "$0")/../.."
out=docs/brand
mkdir -p "$out"
brand/scripts/render-html.sh brand/marketing/social.html "$out/social-preview.png" 1280 640
brand/scripts/render-html.sh brand/marketing/readme-header.html "$out/readme-header.png" 1600 480 00000000
brand/scripts/render-html.sh "brand/marketing/readme-header.html?dark" "$out/readme-header-dark.png" 1600 480 00000000
# 8-bit PNGs without timestamps, so an unchanged page exports an identical file.
magick "$out/social-preview.png" -alpha off -depth 8 -define png:exclude-chunks=date,tIME PNG24:"$out/social-preview.png"
for f in readme-header readme-header-dark; do
  magick "$out/$f.png" -depth 8 -define png:exclude-chunks=date,tIME PNG32:"$out/$f.png"
done

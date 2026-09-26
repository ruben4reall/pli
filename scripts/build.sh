#!/bin/bash
# scripts/build.sh: generates the Xcode project with XcodeGen and builds Pli.app into .build/xcode.
#
#   scripts/build.sh [Debug|Release]
#
# Signing: ad hoc by default. macOS ties an ad hoc app's Screen Recording permission to that exact build, so it asks
# again after every rebuild. Ad hoc code has no team, and the hardened runtime's library validation only loads
# frameworks signed by the app's own team, so ad hoc builds leave the hardened runtime off (Sparkle would not load).
# Set PLI_TEAM_ID to your Apple team ID to sign with your Apple Development certificate instead: the permission then
# survives rebuilds, and Release builds keep the hardened runtime, like the published app.
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIGURATION="${1:-Debug}"
case "$CONFIGURATION" in
  Debug|Release) ;;
  *) echo "usage: scripts/build.sh [Debug|Release]" >&2; exit 64 ;;
esac
command -v xcodegen >/dev/null || { echo "XcodeGen is missing: brew install xcodegen" >&2; exit 1; }
xcodegen generate --quiet
SIGNING=(ENABLE_HARDENED_RUNTIME=NO)
if [ -n "${PLI_TEAM_ID:-}" ]; then
  SIGNING=(-allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$PLI_TEAM_ID" CODE_SIGN_IDENTITY="Apple Development")
fi
mkdir -p .build/xcode
LOG=.build/xcode/build.log
# Packages resolve once into .build/spm, shared with scripts/release.sh (Sparkle's tools live there too).
xcodebuild -project Pli.xcodeproj -scheme Pli -configuration "$CONFIGURATION" -destination 'generic/platform=macOS' \
  -derivedDataPath .build/xcode -clonedSourcePackagesDirPath .build/spm ${SIGNING[@]+"${SIGNING[@]}"} build > "$LOG" 2>&1 \
  || { grep -E "error:" "$LOG" | head -20 >&2; tail -n 20 "$LOG" >&2; exit 1; }
APP=".build/xcode/Build/Products/$CONFIGURATION/Pli.app"
codesign --verify --strict "$APP"
echo "$APP"

#!/bin/bash
# scripts/release.sh [--check]: builds Pli for distribution and packs it in a branded disk image (the brand's light
# background, Pli on the left, Applications on the right, the volume icon), then hands over to
# scripts/finish-release.sh. Adapted from Brainmerge's release script.
#
# Two ways to sign:
# - Developer ID, notarized (what people download): set PLI_TEAM_ID to your Apple team, be signed in to Xcode with the
#   team's Account Holder (Xcode signs with a cloud-managed Developer ID certificate), and give notarytool an App Store
#   Connect API key through NOTARY_KEY_ID, NOTARY_ISSUER_ID and NOTARY_KEY_PATH (the .p8 file). The app, then the disk
#   image, are notarized and stapled. None of these values belongs in this repository.
# - Ad hoc (anyone, no Apple account): leave PLI_TEAM_ID unset. For local testing only: macOS asks to confirm the first
#   opening, the hardened runtime is off (library validation cannot load Sparkle into ad hoc code), and nothing is
#   prepared for publication.
#
# --check        runs the checks below (with a team, also asks Apple whether the key works), then stops.
# NOTARIZE_LATER=1 (Developer ID) submits the disk image without waiting; once Apple accepts it, run
#                scripts/finish-release.sh <version>.
# PLI_APPCAST    the appcast to check against (default site/appcast.xml); the update rehearsal points it elsewhere.
#
# Output: dist/Pli-<version>.dmg and, with a team, dist/build-commit.txt (the commit it was built from).
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-build}"
VERSION=$(grep -m1 'MARKETING_VERSION:' project.yml | awk '{print $2}' | tr -d '"')
TEAM="${PLI_TEAM_ID:-}"
APPCAST="${PLI_APPCAST:-site/appcast.xml}"
WORK=.build/release-work
SPM=.build/spm
fail() { echo "release: $*" >&2; exit 1; }
notary() { xcrun notarytool "$@" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID"; }

# 0. Checks. A published build comes from committed sources, under a version never released before.
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "MARKETING_VERSION in project.yml is not x.y.z: '$VERSION'"
if [ -n "$TEAM" ]; then
  [ -z "$(git status --porcelain)" ] || fail "the working tree has uncommitted changes"
  if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then fail "tag v$VERSION exists: raise MARKETING_VERSION"; fi
  if [ -f "$APPCAST" ] && grep -q -e "<sparkle:version>$VERSION</sparkle:version>" -e "sparkle:version=\"$VERSION\"" "$APPCAST"; then
    fail "$APPCAST already offers $VERSION: raise MARKETING_VERSION"
  fi
  grep -q "^## $VERSION (" CHANGELOG.md 2>/dev/null || fail "CHANGELOG.md has no '## $VERSION (<date>)' section"
  : "${NOTARY_KEY_ID:?set NOTARY_KEY_ID}" "${NOTARY_ISSUER_ID:?set NOTARY_ISSUER_ID}" "${NOTARY_KEY_PATH:?set NOTARY_KEY_PATH}"
  [ -f "$NOTARY_KEY_PATH" ] || fail "NOTARY_KEY_PATH does not name a file"
fi
command -v xcodegen >/dev/null || fail "XcodeGen is missing: brew install xcodegen"
case "$MODE" in
  --check)
    if [ -n "$TEAM" ]; then
      notary history >/dev/null 2>&1 || fail "Apple refused the App Store Connect key (notarytool history)"
      echo "Checks passed: Pli $VERSION, Developer ID team $TEAM, notarization key accepted."
    else
      echo "Checks passed: Pli $VERSION, ad hoc."
    fi
    exit 0 ;;
  build) ;;
  *) fail "usage: scripts/release.sh [--check]" ;;
esac

notarize() {   # notarize <file>: submits, waits, fails loudly on anything but Accepted
  local log; log="$WORK/notary-$(basename "$1").log"
  notary submit "$1" --wait --timeout 60m > "$log" 2>&1 || true
  if ! grep -q "status: Accepted" "$log"; then
    echo "Notarization of $(basename "$1") did not succeed:" >&2; cat "$log" >&2
    local id; id=$(grep -m1 -E '^ *id:' "$log" | awk '{print $2}')
    if [ -n "$id" ]; then notary log "$id" >&2 || true; fi
    exit 1
  fi
  echo "Notarized: $(basename "$1")"
}

submit_later() {   # submit_later <file>: submits without waiting and records the id in dist/notary-pending.txt
  local log; log="$WORK/notary-$(basename "$1").log"
  notary submit "$1" --no-wait > "$log" 2>&1 || { cat "$log" >&2; exit 1; }
  local id; id=$(grep -m1 -E '^ *id:' "$log" | awk '{print $2}')
  [ -n "$id" ] || { cat "$log" >&2; exit 1; }
  echo "$(basename "$1") $id" >> dist/notary-pending.txt
  echo "Submitted for notarization: $(basename "$1") ($id)"
}

check_signed() {   # check_signed <app>: every executable inside is signed by the team, with the hardened runtime
  local count=0 file desc sig
  while IFS= read -r -d '' file; do
    desc=$(file -b "$file")
    [[ "$desc" == *"Mach-O"*"executable"* ]] || continue
    # Read whole, then matched: with pipefail, "codesign | grep -q" fails when grep stops reading early (SIGPIPE).
    sig=$(codesign -dv "$file" 2>&1 || true)
    [[ "$sig" == *"flags=0x10000(runtime)"* ]] || fail "$file is not signed with the hardened runtime"
    [[ "$sig" == *"TeamIdentifier=$TEAM"* ]] || fail "$file is not signed by team $TEAM"
    echo "  signed: ${file#"$1"/}"
    count=$((count + 1))
  done < <(find "$1" -type f -perm -u+x -print0)
  [ "$count" -ge 2 ] || fail "expected Pli and Sparkle's helpers among the executables, found $count"
  codesign --verify --deep --strict "$1"
}

rm -rf dist "$WORK" && mkdir -p dist "$WORK"
xcodegen generate --quiet

# 1. The app.
if [ -n "$TEAM" ]; then
  echo "Developer ID build of Pli $VERSION for team $TEAM"
  git rev-parse HEAD > dist/build-commit.txt
  xcodebuild -project Pli.xcodeproj -scheme Pli -configuration Release -destination 'generic/platform=macOS' \
    -archivePath "$WORK/Pli.xcarchive" -derivedDataPath "$WORK/dd" -clonedSourcePackagesDirPath "$SPM" \
    -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_IDENTITY="Apple Development" \
    archive > "$WORK/archive.log" 2>&1 || { tail -n 30 "$WORK/archive.log" >&2; exit 1; }
  cat > "$WORK/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
</dict></plist>
PLIST
  # The Developer ID certificate is cloud-managed: the export signs with the account signed in to Xcode.
  xcodebuild -exportArchive -archivePath "$WORK/Pli.xcarchive" -exportPath "$WORK/export" \
    -exportOptionsPlist "$WORK/export.plist" -allowProvisioningUpdates > "$WORK/export.log" 2>&1 \
    || { tail -n 30 "$WORK/export.log" >&2; exit 1; }
  APP="$WORK/export/Pli.app"
  check_signed "$APP"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$APP/Contents/Info.plist" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist" >/dev/null 2>&1 \
    || fail "the app has no icon: brand/Pli.icon is not in the Pli target"
  if [ -z "${NOTARIZE_LATER:-}" ]; then
    ditto -c -k --keepParent "$APP" "$WORK/Pli.zip"
    notarize "$WORK/Pli.zip"
    xcrun stapler staple "$APP" >/dev/null
    spctl -a -t exec "$APP" || fail "Gatekeeper still rejects the app"
  fi
else
  echo "No PLI_TEAM_ID: ad hoc build of Pli $VERSION, for local testing only."
  # Ad hoc code has no team, and library validation (part of the hardened runtime) only loads frameworks signed by the
  # app's own team: with it on, Sparkle would not load. Published builds keep it (Developer ID, above).
  xcodebuild -project Pli.xcodeproj -scheme Pli -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$WORK/dd" -clonedSourcePackagesDirPath "$SPM" ENABLE_HARDENED_RUNTIME=NO build \
    > "$WORK/build.log" 2>&1 || { tail -n 30 "$WORK/build.log" >&2; exit 1; }
  APP="$WORK/dd/Build/Products/Release/Pli.app"
  codesign --verify --deep --strict "$APP"
fi

# 2. A read-write disk image with the background and the volume icon.
STAGE=$(mktemp -d)
ditto "$APP" "$STAGE/Pli.app"   # ditto keeps the signature and the stapled ticket intact
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
[ -f docs/brand/dmg-background.png ] || swift scripts/make-dmg-background.swift >/dev/null
cp docs/brand/dmg-background.png "$STAGE/.background/background.png"
ICON=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist" 2>/dev/null || true)
if [ -n "$ICON" ] && [ -f "$APP/Contents/Resources/${ICON%.icns}.icns" ]; then
  cp "$APP/Contents/Resources/${ICON%.icns}.icns" "$STAGE/.VolumeIcon.icns"
else
  echo "No .icns in the app: the disk image keeps the default volume icon."
fi
RW="dist/Pli-rw.dmg"
hdiutil create -volname "Pli" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RW" >/dev/null
rm -rf "$STAGE"

# 3. The layout, by Finder: icon view, positions matching the background, no toolbar. If Finder automation is denied
#    or slow, the image is still valid, just without the layout.
MOUNT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | grep "/Volumes/" | sed -E 's/.*(\/Volumes\/.*)/\1/')
if [ -f "$MOUNT/.VolumeIcon.icns" ]; then SetFile -a C "$MOUNT" 2>/dev/null || true; fi
osascript - "$(basename "$MOUNT")" <<'AS' > /dev/null 2>&1 &
on run argv
  set volumeName to item 1 of argv
  tell application "Finder"
    tell disk volumeName
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set the bounds of container window to {200, 140, 860, 568}
      set theViewOptions to the icon view options of container window
      set arrangement of theViewOptions to not arranged
      set icon size of theViewOptions to 112
      set text size of theViewOptions to 13
      set background picture of theViewOptions to file ".background:background.png"
      set position of item "Pli.app" of container window to {165, 215}
      set position of item "Applications" of container window to {495, 215}
      close
      open
      update without registering applications
      delay 1
      close
    end tell
  end tell
end run
AS
FINDER=$!
for _ in $(seq 1 40); do kill -0 "$FINDER" 2>/dev/null || break; sleep 0.5; done
if kill -0 "$FINDER" 2>/dev/null; then kill "$FINDER" 2>/dev/null || true; echo "Finder layout not applied (automation denied or too slow)."; fi
sync
hdiutil detach "$MOUNT" -quiet || (sleep 2 && hdiutil detach "$MOUNT" -force -quiet)

# 4. A compressed, read-only image.
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "dist/Pli-$VERSION.dmg" >/dev/null
rm -f "$RW"
if [ -z "$TEAM" ]; then
  echo "dist/Pli-$VERSION.dmg (ad hoc, for local testing only)"
  exit 0
fi

# 5. Developer ID: the image is notarized (it holds the app, so with NOTARIZE_LATER one submission covers both).
if [ -n "${NOTARIZE_LATER:-}" ]; then
  submit_later "dist/Pli-$VERSION.dmg"
  echo "Once Apple accepts it (xcrun notarytool info <id> ... says Accepted), run: scripts/finish-release.sh $VERSION"
  exit 0
fi
notarize "dist/Pli-$VERSION.dmg"
exec scripts/finish-release.sh "$VERSION"

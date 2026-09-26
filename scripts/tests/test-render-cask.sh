#!/bin/bash
# The Homebrew cask renders for a release and stays valid Ruby.
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
SHA=$(printf 'pli' | shasum -a 256 | awk '{print $1}')
render() { scripts/render-cask.sh 1.2.3 "$SHA" > "$TMP/pli.rb"; }
check "the cask renders" render
check "it names the version" grep -qF 'version "1.2.3"' "$TMP/pli.rb"
check "it names the SHA-256" grep -qF "sha256 \"$SHA\"" "$TMP/pli.rb"
check "it downloads the versioned disk image" grep -qF 'url "https://github.com/ruben4reall/pli/releases/download/v#{version}/Pli-#{version}.dmg"' "$TMP/pli.rb"
check "it needs macOS 26" grep -qF 'depends_on macos: :tahoe' "$TMP/pli.rb"
check "it leaves updates to Sparkle" grep -qF 'auto_updates true' "$TMP/pli.rb"
no_marker() { ! grep -q '@[A-Z0-9]*@' "$1"; }
check "no template marker is left" no_marker "$TMP/pli.rb"
check "it is valid Ruby" /usr/bin/ruby -c "$TMP/pli.rb"
refuses "a malformed version" "not a version" scripts/render-cask.sh 1.2 "$SHA"
refuses "a malformed SHA-256" "not a SHA-256" scripts/render-cask.sh 1.2.3 abc

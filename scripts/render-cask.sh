#!/bin/bash
# scripts/render-cask.sh <version> <sha256>: prints the Homebrew cask of that release (Casks/pli.rb in
# ruben4reall/homebrew-tap), from packaging/homebrew/pli.rb.in.
set -euo pipefail
VERSION="${1:?usage: scripts/render-cask.sh <version> <sha256>}"
SHA="${2:?usage: scripts/render-cask.sh <version> <sha256>}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "render-cask: not a version: $VERSION" >&2; exit 1; }
[[ "$SHA" =~ ^[0-9a-f]{64}$ ]] || { echo "render-cask: not a SHA-256: $SHA" >&2; exit 1; }
sed -e "s/@VERSION@/$VERSION/" -e "s/@SHA256@/$SHA/" "$(dirname "$0")/../packaging/homebrew/pli.rb.in"

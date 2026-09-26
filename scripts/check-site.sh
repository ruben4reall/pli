#!/bin/bash
# scripts/check-site.sh [--offline] <version>: checks site/ before it goes to production with a release. The page links
# the latest disk image and gives the Homebrew command, loads no inline script (the CSP forbids them), counts visits
# with the cookie-less beacon as site "pli", and serves an appcast whose newest item is <version>, downloadable from
# GitHub (--offline skips that last request).
set -euo pipefail
cd "$(dirname "$0")/.."
OFFLINE=0
if [ "${1:-}" = "--offline" ]; then OFFLINE=1; shift; fi
VERSION="${1:?usage: scripts/check-site.sh [--offline] <version>}"
SITE="${PLI_SITE_DIR:-site}"
REPO_URL=https://github.com/ruben4reall/pli
fail() { echo "check-site: $*" >&2; exit 1; }

[ -f "$SITE/index.html" ] || fail "$SITE/index.html is missing"
grep -qF "$REPO_URL/releases/latest/download/Pli.dmg" "$SITE/index.html" || fail "index.html does not link the latest download"
grep -qF "brew install --cask ruben4reall/tap/pli" "$SITE/index.html" || fail "index.html does not give the Homebrew command"
inline=$(grep -ho '<script[^>]*>' "$SITE"/*.html | grep -v 'src=' | grep -v 'application/ld+json' || true)
[ -z "$inline" ] || fail "an inline <script> would be blocked by the CSP"
grep -rqE 'ruben-analytics\.vercel\.app/api/hit' "$SITE" --include='*.js' || fail "no page-view beacon in the site's scripts"
grep -rqE "site['\"]?[[:space:]]*:[[:space:]]*['\"]pli['\"]" "$SITE" --include='*.js' || fail "the beacon does not count visits as site 'pli'"
python3 - "$SITE/vercel.json" <<'PY' || fail "vercel.json: no CSP allowing the beacon, or no /appcast.xml rule"
import json, sys
headers = json.load(open(sys.argv[1])).get("headers", [])
csp = [h["value"] for rule in headers for h in rule.get("headers", []) if h.get("key") == "Content-Security-Policy"]
assert csp and all("https://ruben-analytics.vercel.app" in value for value in csp)
assert any(rule.get("source") == "/appcast.xml" for rule in headers)
PY
[ -f "$SITE/appcast.xml" ] || fail "$SITE/appcast.xml is missing: run scripts/finish-release.sh $VERSION"
xmllint --noout "$SITE/appcast.xml" || fail "appcast.xml is not well-formed XML"
NEWEST=$(xmllint --xpath 'string(/rss/channel/item[1]/*[local-name()="version"])' "$SITE/appcast.xml")
[ -n "$NEWEST" ] || NEWEST=$(xmllint --xpath 'string(/rss/channel/item[1]/enclosure/@*[local-name()="version"])' "$SITE/appcast.xml")
[ "$NEWEST" = "$VERSION" ] || fail "the appcast's newest item is '$NEWEST', not $VERSION"
URL=$(xmllint --xpath 'string(/rss/channel/item[1]/enclosure/@url)' "$SITE/appcast.xml")
[ "$URL" = "$REPO_URL/releases/download/v$VERSION/Pli-$VERSION.dmg" ] || fail "the newest item downloads $URL"
if [ "$OFFLINE" = 0 ]; then
  code=$(curl -s -o /dev/null -L -w '%{http_code}' "$URL")
  [ "$code" = 200 ] || fail "$URL answers $code: publish the release first (scripts/publish.sh release $VERSION)"
fi
echo "Site ready for $VERSION."

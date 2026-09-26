#!/bin/bash
# scripts/check-site.sh lets a site go live only with the download links, the beacon, a CSP-safe page, and an appcast
# whose newest item is the version being released.
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
site() {   # a minimal site that passes, in $TMP/site
  rm -rf "$TMP/site" && mkdir -p "$TMP/site/js"
  cat > "$TMP/site/index.html" <<'EOF'
<!doctype html><html lang="en"><head><script type="module" src="js/main.js"></script></head><body>
<a href="https://github.com/ruben4reall/pli/releases/latest/download/Pli.dmg">Download Pli</a>
<p class="fine">Or install it with Homebrew: <code>brew install --cask ruben4reall/tap/pli</code></p>
</body></html>
EOF
  printf "export const ENDPOINT = 'https://ruben-analytics.vercel.app/api/hit';\nJSON.stringify({ site: 'pli' });\n" > "$TMP/site/js/beacon.js"
  cat > "$TMP/site/vercel.json" <<'EOF'
{ "headers": [
  { "source": "/(.*)", "headers": [{ "key": "Content-Security-Policy", "value": "default-src 'none'; connect-src 'self' https://ruben-analytics.vercel.app" }] },
  { "source": "/appcast.xml", "headers": [{ "key": "Cache-Control", "value": "public, max-age=0, must-revalidate" }] }
] }
EOF
  cat > "$TMP/site/appcast.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>Pli</title>
<item><title>1.0.1</title><sparkle:version>1.0.1</sparkle:version>
<enclosure url="https://github.com/ruben4reall/pli/releases/download/v1.0.1/Pli-1.0.1.dmg" length="4" type="application/octet-stream" sparkle:edSignature="AA=="/></item>
<item><title>1.0.0</title><sparkle:version>1.0.0</sparkle:version>
<enclosure url="https://github.com/ruben4reall/pli/releases/download/v1.0.0/Pli-1.0.0.dmg" length="4" type="application/octet-stream" sparkle:edSignature="AA=="/></item>
</channel></rss>
EOF
}
checked() { PLI_SITE_DIR="$TMP/site" scripts/check-site.sh --offline "$@"; }

site; check "a complete site passes" checked 1.0.1
site; refuses "an older newest item" "newest item is '1.0.1', not 1.0.2" checked 1.0.2
site; sed -i '' 's#releases/latest/download/Pli.dmg#releases#' "$TMP/site/index.html"
refuses "no latest download link" "latest download" checked 1.0.1
site; sed -i '' 's#brew install --cask ruben4reall/tap/pli#brew#' "$TMP/site/index.html"
refuses "no Homebrew command" "Homebrew" checked 1.0.1
site; printf '<script>alert(1)</script>\n' >> "$TMP/site/index.html"
refuses "an inline script" "inline <script>" checked 1.0.1
site; rm "$TMP/site/js/beacon.js"
refuses "no beacon" "beacon" checked 1.0.1
site; sed -i '' 's# https://ruben-analytics.vercel.app##' "$TMP/site/vercel.json"
refuses "a CSP that blocks the beacon" "vercel.json" checked 1.0.1
site; rm "$TMP/site/appcast.xml"
refuses "no appcast" "appcast.xml is missing" checked 1.0.1

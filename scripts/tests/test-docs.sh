#!/bin/bash
# The public documents: present, linked, readable, free of em dashes.
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
for doc in README.md CHANGELOG.md CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md THIRD-PARTY-NOTICES.md LICENSE; do
  check "$doc exists" test -s "$doc"
done
no_em_dash() { ! LC_ALL=C grep -l $'\xe2\x80\x94' "$@"; }
check "no em dash in the public documents" no_em_dash README.md CHANGELOG.md CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md \
  THIRD-PARTY-NOTICES.md .github/PULL_REQUEST_TEMPLATE.md .github/ISSUE_TEMPLATE/*.yml
for heading in "## What it does" "## Install" "## Permissions" "## Privacy" "## Compatible Macs" "## Private macOS APIs" \
               "## Build from source" "## Credits" "## License"; do
  check "README has '$heading'" grep -qxF "$heading" README.md
done
check "README links the latest disk image" grep -qF "https://github.com/ruben4reall/pli/releases/latest/download/Pli.dmg" README.md
check "README gives the Homebrew command" grep -qF "brew install --cask ruben4reall/tap/pli" README.md
check "README says Pli is not affiliated with Apple" grep -qF "Pli is not affiliated with Apple." README.md
local_links_exist() {
  local missing=0 target
  while IFS= read -r target; do
    [ -e "$target" ] || { echo "missing: $target"; missing=1; }
  done < <(grep -oE '(\]\(|src="|srcset=")[^)"#]+' "$1" | sed -E 's/^(\]\(|src="|srcset=")//' | grep -vE '^(https?:|mailto:)')
  return "$missing"
}
check "every local link and picture in README exists" local_links_exist README.md
headings_ok() { ! grep -E '^## ' CHANGELOG.md | grep -vE '^## [0-9]+\.[0-9]+\.[0-9]+ \([0-9]{4}-[0-9]{2}-[0-9]{2}\)$'; }
check "every CHANGELOG heading reads '## x.y.z (YYYY-MM-DD)'" headings_ok
check "THIRD-PARTY-NOTICES carries Sparkle's license" grep -qF "Copyright (c) 2006-2013 Andy Matuschak." THIRD-PARTY-NOTICES.md
check "THIRD-PARTY-NOTICES credits SkyLightWindow" grep -qF "Copyright (c) 2025 Lakr Aream" THIRD-PARTY-NOTICES.md
check "THIRD-PARTY-NOTICES credits duo-open" grep -qF "Copyright (c) 2026 marcoazeem" THIRD-PARTY-NOTICES.md
check "THIRD-PARTY-NOTICES credits LidAngleSensor" grep -qF "samhenrigold/LidAngleSensor" THIRD-PARTY-NOTICES.md
for form in .github/ISSUE_TEMPLATE/*.yml .github/dependabot.yml; do
  check "$form is valid YAML" /usr/bin/ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$form"
done

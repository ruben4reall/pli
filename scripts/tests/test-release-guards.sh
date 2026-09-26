#!/bin/bash
# scripts/release.sh refuses what must never be published: uncommitted sources, a version already tagged or already in
# the appcast, a version without release notes, a malformed version, a missing notarization key.
source "$(dirname "$0")/lib.sh"

fresh() {   # a throwaway copy of the working tree, committed, with a release-notes section for its version
  rm -rf "$TMP/repo" && mkdir "$TMP/repo"
  rsync -a --exclude .git --exclude .build --exclude dist --exclude node_modules "$ROOT/" "$TMP/repo/"
  cd "$TMP/repo"
  git init -q && git config user.name Test && git config user.email "tests@localhost"
  VERSION=$(grep -m1 'MARKETING_VERSION:' project.yml | awk '{print $2}' | tr -d '"')
  printf '# Changelog\n\n## %s (2026-10-15)\n\n- Test.\n' "$VERSION" > CHANGELOG.md
  git add -A && git commit -q -m "Snapshot"
  touch "$TMP/AuthKey_TEST.p8"
}
team() { PLI_TEAM_ID=TEAMTEST NOTARY_KEY_ID="TEST" NOTARY_ISSUER_ID="TEST" NOTARY_KEY_PATH="$TMP/AuthKey_TEST.p8" scripts/release.sh "$@"; }

fresh; sed -i '' 's/MARKETING_VERSION: .*/MARKETING_VERSION: "1.0"/' project.yml && git commit -qam "Bad version"
refuses "a malformed version" "is not x.y.z" scripts/release.sh --check
fresh; echo "change" >> README.md
refuses "uncommitted changes" "uncommitted changes" team --check
fresh; git tag "v$VERSION"
refuses "a version already tagged" "tag v$VERSION exists" team --check
fresh; mkdir -p site && printf '<rss><channel><item><sparkle:version>%s</sparkle:version></item></channel></rss>\n' "$VERSION" > site/appcast.xml && git add -A && git commit -qm "Appcast"
refuses "a version already in the appcast" "already offers $VERSION" team --check
fresh; printf '# Changelog\n' > CHANGELOG.md && git commit -qam "No notes"
refuses "a version without release notes" "has no '## $VERSION" team --check
fresh
refuses "a missing notarization key" "does not name a file" env PLI_TEAM_ID=TEAMTEST NOTARY_KEY_ID="TEST" NOTARY_ISSUER_ID="TEST" NOTARY_KEY_PATH="$TMP/none.p8" scripts/release.sh --check
refuses "an unknown option" "usage" scripts/release.sh --publish
check "an ad hoc check passes" scripts/release.sh --check

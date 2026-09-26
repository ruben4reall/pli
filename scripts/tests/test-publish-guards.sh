#!/bin/bash
# scripts/publish.sh never publishes without a go-ahead, and never from an incomplete dist/.
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
refuses "no step" "usage" scripts/publish.sh
refuses "an unknown step" "usage" scripts/publish.sh deploy 1.0.0
refuses "a malformed version" "usage" scripts/publish.sh release 1.0
refuses "no confirmation outside a terminal" "not confirmed" scripts/publish.sh release 1.0.0
refuses "a confirmation for another version" "not confirmed" scripts/publish.sh release 1.0.0 --confirm 1.0.1
refuses "a site deploy without the Vercel scope" "PLI_VERCEL_SCOPE" env -u PLI_VERCEL_SCOPE scripts/publish.sh site 1.0.0 --confirm 1.0.0
refuses "a release from an incomplete dist/" "dist/ is incomplete" scripts/publish.sh release 9.9.9 --confirm 9.9.9
refuses "a tap push from an incomplete dist/" "is missing" scripts/publish.sh tap 9.9.9 --confirm 9.9.9

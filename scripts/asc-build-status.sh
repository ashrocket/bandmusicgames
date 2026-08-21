#!/usr/bin/env bash
# Wait for a TestFlight build to finish processing, auto-patching the export
# compliance flag (usesNonExemptEncryption=false) if Apple is waiting on it.
# Uses the asc CLI instead of a hand-rolled JWT/REST client.
#
# Usage: asc-build-status.sh [BUILD_NUMBER]   (or set ASC_BUILD_NUMBER)
set -euo pipefail

ASC_BUNDLE_ID="${ASC_BUNDLE_ID:-com.party.bandmusicgames.app}"
BUILD_NUMBER="${ASC_BUILD_NUMBER:-${1:-}}"
WAIT_SECONDS="${ASC_WAIT_SECONDS:-900}"
POLL_SECONDS="${ASC_POLL_SECONDS:-30}"
SET_EXPORT_COMPLIANCE="${ASC_SET_EXPORT_COMPLIANCE:-1}"

if [ -z "$BUILD_NUMBER" ]; then
  echo "Missing build number. Pass it as \$1 or ASC_BUILD_NUMBER." >&2
  exit 2
fi

deadline=$(( $(date +%s) + WAIT_SECONDS ))

while true; do
  INFO="$(asc builds info --app "$ASC_BUNDLE_ID" --build-number "$BUILD_NUMBER" --platform IOS --output json 2>/dev/null || echo '{}')"
  BUILD_ID="$(echo "$INFO" | jq -r '.data.id // empty')"

  if [ -z "$BUILD_ID" ]; then
    echo "upload not visible in App Store Connect yet…" >&2
  else
    PROCESSING_STATE="$(echo "$INFO" | jq -r '.data.attributes.processingState')"
    ENCRYPTION="$(echo "$INFO" | jq -r '.data.attributes.usesNonExemptEncryption')"
    DETAIL="$(asc builds build-beta-detail view --build-id "$BUILD_ID" --output json 2>/dev/null || echo '{}')"
    INTERNAL_STATE="$(echo "$DETAIL" | jq -r '.data.attributes.internalBuildState // empty')"
    EXTERNAL_STATE="$(echo "$DETAIL" | jq -r '.data.attributes.externalBuildState // empty')"

    if [ "$SET_EXPORT_COMPLIANCE" = "1" ] && { [ "$INTERNAL_STATE" = "MISSING_EXPORT_COMPLIANCE" ] || [ "$ENCRYPTION" = "null" ]; }; then
      echo "Patching usesNonExemptEncryption=false for build $BUILD_NUMBER" >&2
      asc builds update --build-id "$BUILD_ID" --uses-non-exempt-encryption=false --output table
      INFO="$(asc builds info --build-id "$BUILD_ID" --output json)"
      PROCESSING_STATE="$(echo "$INFO" | jq -r '.data.attributes.processingState')"
    fi

    printf '{"found":true,"buildId":"%s","buildNumber":"%s","processingState":"%s","internalBuildState":"%s","externalBuildState":"%s"}\n' \
      "$BUILD_ID" "$BUILD_NUMBER" "$PROCESSING_STATE" "$INTERNAL_STATE" "$EXTERNAL_STATE"

    if [ "$PROCESSING_STATE" = "VALID" ] && [ "$INTERNAL_STATE" != "PROCESSING" ] && [ "$INTERNAL_STATE" != "MISSING_EXPORT_COMPLIANCE" ]; then
      exit 0
    fi
  fi

  if [ "$(date +%s)" -ge "$deadline" ]; then
    if [ -n "$BUILD_ID" ]; then exit 3; else exit 2; fi
  fi
  echo "Waiting ${POLL_SECONDS}s for TestFlight readiness..." >&2
  sleep "$POLL_SECONDS"
done

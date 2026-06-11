#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"

SCHEME="${SCHEME:-BandMusicGames}"
CONFIGURATION="${CONFIGURATION:-Release}"
PROJECT_PATH="${PROJECT_PATH:-$IOS_DIR/BandMusicGames.xcodeproj}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$IOS_DIR/ExportOptions.plist}"

ASC_KEY_ID="${ASC_KEY_ID:-N89CARWD2R}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-69a6de77-108b-47e3-e053-5b8c7c11a4d1}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.env/ashcode/apple/AuthKey_${ASC_KEY_ID}.p8}"
ASC_BUNDLE_ID="${ASC_BUNDLE_ID:-com.party.bandmusicgames.app}"

BUILD_NUMBER="${BMG_BUILD_NUMBER:-$(date -u +%Y%m%d%H%M%S)}"
ARCHIVE_PATH="${ARCHIVE_PATH:-/private/tmp/BandMusicGames-${BUILD_NUMBER}.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-/private/tmp/BandMusicGames-${BUILD_NUMBER}-export}"

if [[ ! -f "$ASC_KEY_PATH" ]]; then
  echo "Missing App Store Connect key: $ASC_KEY_PATH" >&2
  echo "Set ASC_KEY_PATH, or place AuthKey_${ASC_KEY_ID}.p8 at $HOME/.env/ashcode/apple/." >&2
  exit 2
fi

if [[ ! -f "$EXPORT_OPTIONS_PLIST" ]]; then
  echo "Missing export options plist: $EXPORT_OPTIONS_PLIST" >&2
  exit 2
fi

echo "Uploading $SCHEME build $BUILD_NUMBER to TestFlight"
echo "Project: $PROJECT_PATH"
echo "Archive: $ARCHIVE_PATH"
echo "Export: $EXPORT_PATH"
echo "ASC key: $ASC_KEY_ID ($ASC_KEY_PATH)"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

ASC_KEY_ID="$ASC_KEY_ID" \
ASC_ISSUER_ID="$ASC_ISSUER_ID" \
ASC_KEY_PATH="$ASC_KEY_PATH" \
ASC_BUNDLE_ID="$ASC_BUNDLE_ID" \
ASC_BUILD_NUMBER="$BUILD_NUMBER" \
node "$ROOT_DIR/scripts/app-store-connect-build-status.mjs"

#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEVICE_NAME=${DEVICE_NAME:-iPhone 17}
BUNDLE_ID=${BUNDLE_ID:-party.bandmusicgames.app}
DERIVED_DATA=${DERIVED_DATA:-/private/tmp/bmg-ios-smoke-derived}
SMOKE_SETTLE_SECONDS=${SMOKE_SETTLE_SECONDS:-8}

cd "$ROOT"

find_device() {
  DEVICE_NAME="$DEVICE_NAME" python3 - <<'PY'
import json
import os
import subprocess

target = os.environ["DEVICE_NAME"]
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
data = json.loads(raw)
for _runtime, devices in data["devices"].items():
    for device in devices:
        if device["name"] == target and device["isAvailable"]:
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(f"No available simulator named {target!r}")
PY
}

DEVICE_UDID=$(find_device)
APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/BandMusicGames.app"

printf 'BUILD %s\n' "$APP"
xcodebuild \
  -project ios/BandMusicGames.xcodeproj \
  -scheme BandMusicGames \
  -sdk iphonesimulator \
  -destination "id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build >/tmp/bmg-ios-smoke-xcodebuild.log

printf 'BOOT  %s (%s)\n' "$DEVICE_NAME" "$DEVICE_UDID"
xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_UDID" -b >/dev/null

printf 'INSTALL %s\n' "$BUNDLE_ID"
xcrun simctl install "$DEVICE_UDID" "$APP"

run_state() {
  local name=$1
  shift || true
  printf 'LAUNCH %-18s %s\n' "$name" "$*"
  xcrun simctl launch \
    --terminate-running-process \
    --stdout="/tmp/bmg-ios-smoke-$name.stdout.log" \
    --stderr="/tmp/bmg-ios-smoke-$name.stderr.log" \
    "$DEVICE_UDID" \
    "$BUNDLE_ID" \
    "$@" >/tmp/bmg-ios-smoke-"$name".log
  sleep "$SMOKE_SETTLE_SECONDS"
  xcrun simctl io "$DEVICE_UDID" screenshot "/private/tmp/bmg-ios-smoke-$name.png" >/dev/null
}

run_state "lobby"
run_state "goon" "-bmg-open-goon"
run_state "goon-level2" "-bmg-open-goon" "-bmg-goon-level" "2"
run_state "goon-level3" "-bmg-open-goon" "-bmg-goon-level" "3"
run_state "francis" "-bmg-open-francis"
run_state "lizzy-title" "-bmg-open-lizzy"
run_state "lizzy-picker" "-bmg-open-lizzy" "-bmg-lizzy-teammate-picker"
run_state "lizzy-gameplay" "-bmg-open-lizzy" "-bmg-lizzy-gameplay"

xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
printf 'OK screenshots written to /private/tmp/bmg-ios-smoke-*.png\n'

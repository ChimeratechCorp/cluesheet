#!/bin/bash
# Builds the app, runs it in iPhone and iPad simulators with the sample
# game loaded, and saves screenshots to ./screenshots. Needs a Mac with Xcode.
set -euo pipefail

BUNDLE_ID=com.chimeratech.cluesheet
OUT=screenshots
mkdir -p "$OUT"

xcodebuild build \
  -project ClueSheet.xcodeproj \
  -scheme ClueSheet \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO | tail -3
APP=build/Build/Products/Debug-iphonesimulator/ClueSheet.app

# First available simulator whose name matches the pattern.
device() {
  xcrun simctl list devices available -j |
    python3 -c "import json,re,sys; d=json.load(sys.stdin)['devices']; print(next(x['udid'] for r in sorted(d, reverse=True) for x in d[r] if re.search(sys.argv[1], x['name'])))" "$1"
}

shoot() { # udid name [launch args...]
  local udid=$1 name=$2; shift 2
  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$udid" "$BUNDLE_ID" "$@" >/dev/null
  sleep 6
  xcrun simctl io "$udid" screenshot "$OUT/$name.png"
}

prepare() { # udid
  xcrun simctl boot "$1" 2>/dev/null || true
  xcrun simctl bootstatus "$1" -b >/dev/null
  xcrun simctl status_bar "$1" override --time 9:41 --batteryState charged --batteryLevel 100 || true
  xcrun simctl install "$1" "$APP"
}

PHONE=$(device '^iPhone 16 Pro$' || device '^iPhone')
prepare "$PHONE"
shoot "$PHONE" 1-setup
shoot "$PHONE" 2-sheet-folded -demoGame

# iPad mini is 744 pt wide, close to the unfolded iPhone Duo's 626 pt,
# so it shows the same split layout.
TABLET=$(device '^iPad mini' || device '^iPad')
prepare "$TABLET"
shoot "$TABLET" 3-split-unfolded -demoGame

ls -l "$OUT"

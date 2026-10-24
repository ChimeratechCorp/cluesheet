#!/bin/bash
# Builds the app, runs it in the iPhone Duo simulator with the sample game
# loaded, folded and unfolded, and saves screenshots to ./screenshots.
# Needs a Mac with Xcode 27.1 or later and duoctl
# (brew install skarol/tap/duoctl) to work the hinge.
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

# An available iPhone Duo, created on the newest iOS runtime if there's none.
duo() {
  local udid
  udid=$(xcrun simctl list devices available -j |
    python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next((x['udid'] for r in sorted(d, reverse=True) for x in d[r] if x['name'] == 'iPhone Duo'), ''))")
  if [ -z "$udid" ]; then
    local runtime
    runtime=$(xcrun simctl list runtimes -j |
      python3 -c "import json,sys; print([r['identifier'] for r in json.load(sys.stdin)['runtimes'] if r['platform'] == 'iOS' and r['isAvailable']][-1])")
    udid=$(xcrun simctl create "iPhone Duo" "iPhone Duo" "$runtime")
  fi
  echo "$udid"
}

DUO=$(duo)
export DUOCTL_UDID=$DUO
xcrun simctl boot "$DUO" 2>/dev/null || true
xcrun simctl bootstatus "$DUO" -b >/dev/null
xcrun simctl status_bar "$DUO" override --time 9:41 --batteryState charged --batteryLevel 100 || true
xcrun simctl install "$DUO" "$APP"

# duoctl captures whichever screen is lit; simctl's own screenshot of a
# folded Duo comes out black.
shoot() { # name [launch args...]
  local name=$1; shift
  xcrun simctl terminate "$DUO" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DUO" "$BUNDLE_ID" "$@" >/dev/null
  sleep 6
  duoctl screenshot "$OUT/$name.png"
}

duoctl close
duoctl rotate portrait
shoot 1-setup
shoot 2-sheet-folded -demoGame
shoot 4-helper-off -demoGame -helperOn NO

duoctl open
duoctl rotate portrait
shoot 3-split-unfolded -demoGame
duoctl rotate landscape
shoot 5-split-unfolded-landscape -demoGame
duoctl rotate portrait
xcrun simctl ui "$DUO" appearance dark
shoot 6-split-unfolded-dark -demoGame
xcrun simctl ui "$DUO" appearance light

ls -l "$OUT"

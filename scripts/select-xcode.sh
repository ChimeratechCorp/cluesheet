#!/bin/bash
# Switches to Xcode 27.1 or later (the first with the iOS 27.1 SDK and the
# iPhone Duo simulator) and makes sure its iOS simulator runtime is
# installed. Used by CI; needs sudo for xcode-select.
set -euo pipefail

# Runner images name it Xcode_27.1.app or Xcode_27.1_Release_Candidate.app;
# the plain name sorts first, so a final release wins over a candidate.
XCODE=$(ls -d /Applications/Xcode_27.[1-9]*.app 2>/dev/null | grep -vi beta | sort | head -1 || true)
if [ -z "$XCODE" ]; then
  echo "No Xcode 27.1 or later on this machine. Installed:" >&2
  ls -d /Applications/Xcode*.app >&2
  exit 1
fi
sudo xcode-select -s "$XCODE"
xcodebuild -version

if ! xcrun simctl list runtimes | grep -q '^iOS 27\.[1-9]'; then
  echo "Downloading the iOS simulator runtime for $XCODE"
  xcodebuild -downloadPlatform iOS
fi
xcrun simctl list runtimes | grep '^iOS'

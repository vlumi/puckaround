#!/usr/bin/env bash
# Build the iOS app for the simulator, unsigned. Usage: build.sh [ios]
# Assumes the Xcode project is already generated (the Makefile handles that).
# iOS is the only platform there will be; the argument exists so the call
# shape matches the sibling projects' scripts.
set -euo pipefail
cd "$(dirname "$0")/.."

platform="${1:-ios}"
case "$platform" in
    ios) scheme="Puckaround-iOS"; destination="generic/platform=iOS Simulator" ;;
    *) echo "usage: build.sh [ios]" >&2; exit 2 ;;
esac

build() {
    xcodebuild -project Puckaround.xcodeproj -scheme "$scheme" \
        -destination "$destination" -derivedDataPath .build-xcode \
        CODE_SIGNING_ALLOWED=NO build
}

echo "Building ${scheme}..."
# Pipe through xcbeautify if it's installed (nicer output); otherwise raw.
if command -v xcbeautify >/dev/null; then
    set -o pipefail
    build | xcbeautify
else
    build
fi

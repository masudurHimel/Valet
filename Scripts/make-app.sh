#!/bin/bash
# Assembles Valet.app from the SPM build product and ad-hoc signs it.
# Usage: Scripts/make-app.sh [--universal]
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--universal" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN=".build/apple/Products/Release/Valet"
else
    swift build -c release
    BIN=".build/release/Valet"
fi

APP="build/Valet.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Valet"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"
echo "Built $APP"

#!/bin/bash
# Assembles Valet.app from the SPM build product and ad-hoc signs it.
# Usage: Scripts/make-app.sh [--universal] [--install]
#   --universal  build arm64 + x86_64 slices
#   --install    copy the result to /Applications and launch it
set -euo pipefail
cd "$(dirname "$0")/.."

UNIVERSAL=0
INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --universal) UNIVERSAL=1 ;;
        --install) INSTALL=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [[ "$UNIVERSAL" == 1 ]]; then
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

if [[ "$INSTALL" == 1 ]]; then
    pkill -x Valet 2>/dev/null || true
    rm -rf /Applications/Valet.app
    cp -R "$APP" /Applications/Valet.app
    echo "Installed /Applications/Valet.app"
    echo "Note: re-signing resets Screen Recording/Accessibility grants — re-grant in System Settings if needed."
    open /Applications/Valet.app
fi

#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
APP_DIR="$PROJECT_DIR/.build/release/CodexQuotaTouchBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$PROJECT_DIR"

if [ -d /Applications/Xcode.app/Contents/Developer ]; then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
        xcrun swift build -c release --product CodexQuotaTouchBar
else
    swift build -c release --product CodexQuotaTouchBar
fi

mkdir -p "$MACOS_DIR"
cp "$PROJECT_DIR/.build/release/CodexQuotaTouchBar" "$MACOS_DIR/CodexQuotaTouchBar"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/CodexQuotaTouchBar"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$APP_DIR" >/dev/null 2>&1
fi

printf '%s\n' "$APP_DIR"

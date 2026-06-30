#!/bin/bash
#
# Builds ResizeMacWindow with SwiftPM and assembles a runnable .app bundle.
# Works with Command Line Tools only (no full Xcode required).
#
set -euo pipefail

APP_NAME="Wield"
CONFIG="release"

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_BIN="$ROOT/.build/$CONFIG/$APP_NAME"
APP_DIR="$ROOT/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"

echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp "$BUILD_BIN" "$CONTENTS/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
cp "$ROOT/Resources/MenuBarIcon.png" "$CONTENTS/Resources/MenuBarIcon.png"
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "==> Ad-hoc code signing…"
codesign --force --sign - "$APP_DIR"

echo ""
echo "==> Done: $APP_DIR"
echo "    Launch with:  open \"$APP_DIR\""
echo "    First run will ask for Accessibility permission in System Settings."

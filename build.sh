#!/bin/bash
#
# Builds Wield with SwiftPM and assembles a runnable .app bundle.
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

# Pick a stable signing identity so the macOS Accessibility grant survives
# rebuilds. An ad-hoc signature (`-`) changes every build, which resets the
# grant; a real certificate keeps the code's designated requirement constant.
# Override explicitly with WIELD_SIGN_IDENTITY, otherwise auto-detect the most
# durable identity available, falling back to ad-hoc when none is installed.
SIGN_IDENTITY="${WIELD_SIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
    for pattern in "Developer ID Application" "Apple Development"; do
        SIGN_IDENTITY="$(security find-identity -v -p codesigning \
            | awk -F'"' -v p="$pattern" '$0 ~ p {print $2; exit}')"
        [ -n "$SIGN_IDENTITY" ] && break
    done
fi
[ -z "$SIGN_IDENTITY" ] && SIGN_IDENTITY="-"

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "==> Ad-hoc code signing (no certificate found — Accessibility grant may reset on rebuild)…"
else
    echo "==> Code signing with: $SIGN_IDENTITY"
fi
codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR"

echo ""
echo "==> Done: $APP_DIR"
echo "    Launch with:  open \"$APP_DIR\""
echo "    First run will ask for Accessibility permission in System Settings."

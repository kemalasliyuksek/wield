#!/bin/bash
# Regenerate Resources/AppIcon.icns and Resources/MenuBarIcon.png from glyph.png.
set -euo pipefail
cd "$(dirname "$0")"
swift make-icons.swift
echo "Done. Rebuild the app (../build.sh) to embed the updated icons."

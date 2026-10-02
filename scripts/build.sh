#!/usr/bin/env bash
# Compila em release e monta build/cueio.app (assinatura ad-hoc, sem precisar do Xcode).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Cueio"
APP="build/cueio.app"

rm -rf build/cueio.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/cueio"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/icon.icns "$APP/Contents/Resources/icon.icns"
cp -R Resources/pt-BR.lproj "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

echo "$APP"

#!/bin/zsh
# Builds build/Maestro.app from the Swift package and signs it ad hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Maestro"
APP=build/Maestro.app

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts"
# rsync replaces files by rename, so a running copy of the app keeps working.
rsync -a "$BIN" "$APP/Contents/MacOS/Maestro"
rsync -a Support/Info.plist "$APP/Contents/Info.plist"
rsync -a Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
rsync -a --delete Support/Fonts/ "$APP/Contents/Resources/Fonts/"
codesign --force --sign - "$APP"
echo "Built $APP"

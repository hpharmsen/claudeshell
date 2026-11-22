#!/bin/zsh
# Builds build/Claudeshell.app from the Swift package and signs it ad hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Claudeshell"
APP=build/Claudeshell.app

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts"
# rsync replaces files by rename, so a running copy of the app keeps working.
rsync -a "$BIN" "$APP/Contents/MacOS/Claudeshell"
rsync -a Support/Info.plist "$APP/Contents/Info.plist"
rsync -a Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
rsync -a --delete Support/Fonts/ "$APP/Contents/Resources/Fonts/"
codesign --force --sign - "$APP"
echo "Built $APP"

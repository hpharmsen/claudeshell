#!/bin/zsh
# Builds the app and installs it in /Applications, where the Dock icon points to.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh
rsync -a --delete build/Maestro.app/ /Applications/Maestro.app/
# Makes Finder and the Dock pick up a changed icon.
touch /Applications/Maestro.app
echo "Installed /Applications/Maestro.app; restart Maestro to run the new version"

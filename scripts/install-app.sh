#!/bin/zsh
# Builds the app and installs it in /Applications, where the Dock icon points to.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh
rsync -a --delete build/Claudeshell.app/ /Applications/Claudeshell.app/
# Makes Finder and the Dock pick up a changed icon.
touch /Applications/Claudeshell.app
echo "Installed /Applications/Claudeshell.app; restart Claudeshell to run the new version"

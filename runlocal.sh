#!/bin/zsh
# Builds the app and opens it.
set -euo pipefail
cd "$(dirname "$0")"
scripts/build-app.sh
open build/Maestro.app

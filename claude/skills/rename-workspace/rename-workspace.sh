#!/usr/bin/env bash
# Rename the current cmux workspace.
# Usage: rename-workspace.sh "Five To Six Word Title"
set -euo pipefail

TITLE="${1:?usage: rename-workspace.sh \"Title\"}"

CMUX_QUIET=1 cmux rename-workspace "$TITLE" >/dev/null

echo "Renamed to \"$TITLE\"."

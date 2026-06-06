#!/usr/bin/env bash
# Installer for the dotcalum centralized git-hook dispatcher.
# Points the GLOBAL core.hooksPath at this repo's git/hooks dir and makes sure
# every hook name symlinks to _dispatch. Idempotent: safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks"

# Every git hook name -> symlink to _dispatch (which recovers the fired hook from $0).
HOOK_NAMES=(
  applypatch-msg pre-applypatch post-applypatch
  pre-commit prepare-commit-msg commit-msg post-commit
  pre-merge-commit post-merge pre-rebase
  pre-push post-checkout post-rewrite
  pre-auto-gc push-to-checkout sendemail-validate
)
for h in "${HOOK_NAMES[@]}"; do
  ln -sfn _dispatch "$HOOKS_DIR/$h"
done

chmod +x "$HOOKS_DIR/_dispatch"
find "$HOOKS_DIR/handlers.d" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

# Back up any pre-existing global hooks dir that isn't already us.
PREV="$(git config --global --get core.hooksPath || true)"
if [ -n "$PREV" ] && [ "$PREV" != "$HOOKS_DIR" ] && [ -e "$PREV" ] && [ ! -L "$PREV" ]; then
  mv "$PREV" "$PREV.bak.$(date +%s)"
  echo "  backed up previous hooks dir: $PREV"
fi

git config --global core.hooksPath "$HOOKS_DIR"
echo "core.hooksPath -> $HOOKS_DIR"
echo "hooks log       -> ${HOOKS_LOG:-$HOME/.local/state/hooks/timing.jsonl}"
echo
echo "Note: repos with their own core.hooksPath (lefthook, beads' .beads/hooks, husky)"
echo "bypass this global dispatcher and are not timed."

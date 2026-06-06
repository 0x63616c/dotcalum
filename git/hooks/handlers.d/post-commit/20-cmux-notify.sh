#!/usr/bin/env bash
# post-commit handler: notify on commit when working inside a cmux session.
# CMUX_WORKSPACE_ID is exported by the cmux pane shell and inherited by the hook, so
# its presence is the "I'm working in cmux" gate. Backgrounded + detached + `|| true`
# so a slow/failed notify can never block or fail the commit.
#
# We fire two ways for guaranteed visibility:
#   1. cmux notify        -> records in cmux's notification panel (Cmd+Shift+U).
#   2. a macOS banner+sound via terminal-notifier (preferred: it posts under its OWN
#      app identity, so macOS shows the banner even while cmux is the focused app —
#      a plain cmux/macOS banner is suppressed for the focused app). osascript is the
#      fallback if terminal-notifier isn't installed.
[ -n "${CMUX_WORKSPACE_ID:-}" ] || exit 0
(
  project="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
  sha="$(git rev-parse --short HEAD 2>/dev/null)"
  subject="$(git log -1 --pretty=%s 2>/dev/null)"
  body="committed #$sha · $subject"

  command -v cmux >/dev/null 2>&1 && cmux notify --title "$project" --body "$body" </dev/null >/dev/null 2>&1 || true

  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "✅ $project" -message "$body" -sound Glass </dev/null >/dev/null 2>&1 || true
  elif command -v osascript >/dev/null 2>&1; then
    safe="${body//\"/}"   # strip quotes so the AppleScript string can't break
    osascript -e "display notification \"$safe\" with title \"$project\" sound name \"Glass\"" >/dev/null 2>&1 || true
  fi
) &
exit 0

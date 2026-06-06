#!/usr/bin/env bash
# post-commit handler: cmux toast, but only inside a cmux session. CMUX_WORKSPACE_ID
# is exported by the cmux pane shell and inherited by the hook subprocess, so its
# presence is the detection signal. Backgrounded + detached + `|| true` so a slow
# or failed socket round-trip never blocks or fails the commit.
[ -n "${CMUX_WORKSPACE_ID:-}" ] || exit 0
command -v cmux >/dev/null 2>&1 || exit 0
(
  project="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
  sha="$(git rev-parse --short HEAD 2>/dev/null)"
  subject="$(git log -1 --pretty=%s 2>/dev/null)"
  cmux notify --title "$project" --body "committed #$sha · $subject" </dev/null >/dev/null 2>&1 || true
) &
exit 0

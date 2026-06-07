#!/usr/bin/env bash
# UserPromptSubmit hook: nudge Claude to re-title the cmux workspace when the
# current title no longer describes the work. Fires every message (no counting);
# the strong conditional in the injected reminder is what prevents over-renaming.
#
# Reads this session's workspace via $CMUX_WORKSPACE_ID (inherited from the
# cmux-launched env), looks up its title, and injects a system-reminder as
# UserPromptSubmit additionalContext. Silent no-op if cmux/title is unavailable.
set -euo pipefail

CMUX_BIN="${CMUX_CLAUDE_HOOK_CMUX_BIN:-cmux}"
ws_id="${CMUX_WORKSPACE_ID:-}"
[ -z "$ws_id" ] && exit 0

# Pull custom_color AND title in one shot. custom_color is the provenance tell:
# our rename-workspace skill ALWAYS assigns a named color, so a non-null color
# means we set this title. A null color means the title is cmux/Claude's
# auto-generated first guess that we have never owned. Put color first so the
# title (which may contain spaces/tabs) is the unambiguous trailing field.
# Best-effort lookup: cmux IPC can fail transiently (broken socket) and `head`
# can SIGPIPE the upstream. With `set -e -o pipefail` any such non-zero would
# abort the whole hook with exit 1 BEFORE the graceful guards below, which
# Claude surfaces as "UserPromptSubmit hook failed with status code 1". The
# `|| true` keeps failures silent: an empty $line falls through to the
# [ -z "$title" ] exit 0 below, exactly as the "stay silent" contract intends.
line="$(CMUX_QUIET=1 "$CMUX_BIN" workspace list --json --id-format both 2>/dev/null \
  | jq -r --arg id "$ws_id" '.workspaces[] | select(.id==$id) | "\(.custom_color // "")\t\(.title)"' 2>/dev/null \
  | head -1)" || true
color="${line%%$'\t'*}"
title="${line#*$'\t'}"

# No title yet (fresh/unnamed workspace) or lookup failed: stay silent.
[ -z "$title" ] && exit 0

# No custom color => this title was NOT set by our skill (it is the auto-generated
# first guess). It must be replaced with a skill-owned title + load-balanced color,
# regardless of how descriptive the auto-title happens to look.
if [ -z "$color" ]; then
  printf '<system-reminder>The workspace title "%s" is the auto-generated default (no color assigned), NOT one set by the rename-workspace skill. You MUST run the rename-workspace skill NOW to give it a proper skill-owned title and color, before responding. This is not optional, even if the current title looks descriptive.</system-reminder>\n' "$title"
  exit 0
fi

# We own this title (it has a color). Forceful but conditional, so we do not
# thrash a good title: rename only when the work has clearly moved on.
printf '<system-reminder>The workspace title is "%s". If this NO LONGER describes what we are working on, you MUST run the rename-workspace skill immediately to regenerate it, before responding. If it still fits, do nothing.</system-reminder>\n' "$title"

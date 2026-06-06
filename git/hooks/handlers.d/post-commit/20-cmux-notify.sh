#!/usr/bin/env bash
# post-commit handler: notify on commit when working inside a cmux session.
# CMUX_WORKSPACE_ID is exported by the cmux pane shell and inherited by the hook, so
# its presence is the "I'm working in cmux" gate. Backgrounded + detached + `|| true`
# so a slow/failed notify can never block or fail the commit.
#
# Two channels for guaranteed visibility:
#   1. cmux notify        -> records in cmux's notification panel (Cmd+Shift+U).
#   2. macOS banner+sound via terminal-notifier (preferred: posts under its OWN app
#      identity, so the banner shows even while cmux is the focused app — a plain
#      cmux/macOS banner is suppressed for the focused app). osascript is the fallback.
#
# LAYOUT (three fields):
#   title    = repo slug          (bold)
#   subtitle = commit subject
#   message  = #shortsha · branch
# NB: terminal-notifier mangles a -title containing ( ) [ ] (it silently replaces the
# title with "Terminal" AND drops -appIcon). So the title is the repo slug only (with
# any stray brackets stripped); the subject — which may be a conventional commit like
# "feat(web): ..." — goes in subtitle/message, which tolerate those characters.
[ -n "${CMUX_WORKSPACE_ID:-}" ] || exit 0
(
  project="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
  sha="$(git rev-parse --short HEAD 2>/dev/null)"
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  subject="$(git log -1 --pretty=%s 2>/dev/null)"

  title="${project//[()\[\]]/}"   # strip brackets/parens — they break terminal-notifier's title
  subtitle="$subject"
  body="#$sha · $branch"

  command -v cmux >/dev/null 2>&1 && \
    cmux notify --title "$title" --subtitle "$subtitle" --body "$body" </dev/null >/dev/null 2>&1 || true

  # Custom logo (true-black tile + green check), shipped in dotcalum/git/assets and
  # resolved relative to this handler so it works on any machine. Only used if present.
  hdir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
  icon="$(cd "$hdir/../../../assets" 2>/dev/null && pwd)/commit-icon.png"
  icon_args=(); [ -f "$icon" ] && icon_args=(-appIcon "$icon")

  if command -v terminal-notifier >/dev/null 2>&1; then
    # -group: rapid commits in the same repo collapse instead of stacking.
    # -ignoreDnD: show even in a Focus/Do-Not-Disturb mode. How LONG it stays is
    # macOS-controlled by the notification *style* for the terminal-notifier sender
    # (Banner = auto-dismiss ~5s; Alert = until dismissed) — set once in
    # System Settings > Notifications > terminal-notifier > Alerts.
    terminal-notifier -title "$title" -subtitle "$subtitle" -message "$body" "${icon_args[@]}" \
      -group "dotcalum-commit-$project" -sound Glass -ignoreDnD </dev/null >/dev/null 2>&1 || true
  elif command -v osascript >/dev/null 2>&1; then
    st="${title//\"/}"; ss="${subtitle//\"/}"; sb="${body//\"/}"   # strip quotes so AppleScript can't break
    osascript -e "display notification \"$sb\" with title \"$st\" subtitle \"$ss\" sound name \"Glass\"" >/dev/null 2>&1 || true
  fi
) &
exit 0

#!/usr/bin/env bash
# Keep our global git-hook dispatcher in charge of EVERY repo, without breaking the
# tools (beads/lefthook/husky) that try to claim core.hooksPath for themselves.
#
# THE PROBLEM
#   git runs exactly ONE hooks dir. A repo-local `core.hooksPath` (set by beads,
#   lefthook, husky, or you) shadows our global one, so our dispatcher never runs
#   there — no timing, no commit notify.
#
# THE FIX ("capture & delegate", fully reversible, non-breaking)
#   For a repo whose local core.hooksPath is NOT ours, we:
#     1. save that path into `hooks.delegate` (the tool's intent, preserved)
#     2. unset the local core.hooksPath, so our GLOBAL dispatcher wins again
#   Our dispatcher then runs global behavior and DELEGATES to `hooks.delegate`, so
#   the tool's own hook scripts still run, untouched, same order/stdin/exit.
#
# SELF-HEALING
#   Tools can re-set core.hooksPath any time (e.g. `bd`, `lefthook install`). This
#   script is idempotent and cheap, so we re-run it at every cheap moment (cd via
#   zsh chpwd, before git commit/push/merge via the git wrapper, after `bd` via its
#   shim, and a background launchd sweep). Whatever re-claims core.hooksPath is
#   re-captured before the next hook fires.
#
# ESCAPE HATCH
#   Set `git config hooks.optout true` in a repo to make this leave it ALONE
#   forever (deliberate bypass of our dispatcher).
#
# Fail-open: every path swallows its own errors. This must NEVER block git or a shell.
set -uo pipefail

ROOTS_DEFAULT=("$HOME/code")
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/../lib/hooklog.sh" 2>/dev/null || { hooklog_now_ms() { echo 0; }; hooklog_step() { :; }; }

OURS="$(git config --global --get core.hooksPath 2>/dev/null || true)"

# reconcile_repo <repo-dir> [quiet]
# Returns 0 always (fail-open). Captures a stray local core.hooksPath.
reconcile_repo() {
  local repo="$1" quiet="${2:-}"
  [ -n "$OURS" ] || return 0
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 0

  # Deliberate opt-out wins.
  local optout; optout="$(git -C "$repo" config --local --get hooks.optout 2>/dev/null || true)"
  case "$optout" in true|1|yes) return 0 ;; esac

  local localhp; localhp="$(git -C "$repo" config --local --get core.hooksPath 2>/dev/null || true)"
  [ -z "$localhp" ] && return 0          # nothing set -> global (us) already wins
  [ "$localhp" = "$OURS" ] && return 0   # already ours

  # Capture the tool's intended dir (latest wins), then hand control back to global.
  local prev; prev="$(git -C "$repo" config --local --get hooks.delegate 2>/dev/null || true)"
  if [ "$prev" != "$localhp" ]; then
    git -C "$repo" config --local hooks.delegate "$localhp" 2>/dev/null || return 0
  fi
  git -C "$repo" config --local --unset-all core.hooksPath 2>/dev/null || return 0

  local name; name="$(basename "$repo")"
  hooklog_step reconcile "$name" capture "$localhp" 0 0
  [ "$quiet" = quiet ] || echo "hooks: captured core.hooksPath for $name ($localhp) -> hooks.delegate; global dispatcher now active"
  return 0
}

# restore_repo <repo-dir>: put the tool's core.hooksPath back, drop our capture.
restore_repo() {
  local repo="$1"
  local d; d="$(git -C "$repo" config --local --get hooks.delegate 2>/dev/null || true)"
  if [ -n "$d" ]; then
    git -C "$repo" config --local core.hooksPath "$d" 2>/dev/null || true
    git -C "$repo" config --local --unset-all hooks.delegate 2>/dev/null || true
    echo "hooks: restored core.hooksPath=$d for $(basename "$repo") (our dispatcher no longer in front)"
  else
    echo "hooks: nothing to restore for $(basename "$repo") (no hooks.delegate captured)"
  fi
}

# sweep <quiet> <roots...>: reconcile every repo under the given roots.
sweep() {
  local quiet="$1"; shift
  local roots=("$@"); [ ${#roots[@]} -eq 0 ] && roots=("${ROOTS_DEFAULT[@]}")
  local n=0 cap_before cap_after
  while IFS= read -r gitdir; do
    reconcile_repo "$(dirname "$gitdir")" "$quiet"
    n=$((n+1))
  done < <(find "${roots[@]}" -maxdepth 6 -type d -name .git 2>/dev/null)
  [ "$quiet" = quiet ] || echo "hooks: swept $n repos under ${roots[*]}"
}

# status: list repos we've captured (and any opt-outs) under the roots.
status() {
  local roots=("${ROOTS_DEFAULT[@]}")
  echo "global core.hooksPath (ours): ${OURS:-<unset>}"
  echo "CAPTURED (delegating through our dispatcher):"
  while IFS= read -r gitdir; do
    local repo; repo="$(dirname "$gitdir")"
    local d; d="$(git -C "$repo" config --local --get hooks.delegate 2>/dev/null || true)"
    [ -n "$d" ] && printf '  %-50s -> %s\n' "${repo/#$HOME/~}" "$d"
  done < <(find "${roots[@]}" -maxdepth 6 -type d -name .git 2>/dev/null)
  echo "OPT-OUT (left alone):"
  while IFS= read -r gitdir; do
    local repo; repo="$(dirname "$gitdir")"
    local o; o="$(git -C "$repo" config --local --get hooks.optout 2>/dev/null || true)"
    case "$o" in true|1|yes) printf '  %s\n' "${repo/#$HOME/~}" ;; esac
  done < <(find "${roots[@]}" -maxdepth 6 -type d -name .git 2>/dev/null)
}

cmd="${1:-current}"
case "$cmd" in
  current)        shift || true; reconcile_repo "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")" "${1:-}" ;;
  --repo)         reconcile_repo "$2" "${3:-}" ;;
  --all|--sweep)  shift || true; sweep "${QUIET:-}" "$@" ;;
  --restore)      restore_repo "${2:-$(git rev-parse --show-toplevel 2>/dev/null)}" ;;
  --status)       status ;;
  *)              echo "usage: reconcile-hooks.sh [current [quiet] | --repo <dir> [quiet] | --all [roots...] | --restore [repo] | --status]" >&2; exit 2 ;;
esac

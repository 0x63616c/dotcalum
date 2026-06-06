# dotcalum: keep our global git-hook dispatcher in front of EVERY repo.
#
# Tools (beads/lefthook/husky) and manual edits can set a repo-local core.hooksPath
# that shadows our global dispatcher. reconcile-hooks.sh "captures" that (saves it to
# hooks.delegate, unsets the override) so our dispatcher runs and then delegates back
# to the tool — nothing breaks. This file triggers that reconcile at the cheap,
# high-value moments. All hot-path calls touch ONLY the current repo and are
# fail-open: they can never block a shell or a git command.
#
# Other self-heal layers: a background launchd sweep (all repos, every few minutes)
# and the pre-session hook. See git/reconcile-hooks.sh for the full rationale.

_DOTCALUM_RECONCILE="${_DOTCALUM_RECONCILE:-$HOME/code/github.com/0x63616c/dotcalum/git/reconcile-hooks.sh}"

# Reconcile just the current repo, quietly. Never errors out.
_dotcalum_reconcile_cwd() {
  [ -x "$_DOTCALUM_RECONCILE" ] || return 0
  command git rev-parse --git-dir >/dev/null 2>&1 || return 0
  "$_DOTCALUM_RECONCILE" current quiet >/dev/null 2>&1 || true
}

# chpwd: reconcile whenever you cd into a repo.
autoload -Uz add-zsh-hook 2>/dev/null && add-zsh-hook chpwd _dotcalum_reconcile_cwd

# git wrapper: reconcile right before the subcommands that actually fire hooks, so a
# re-override is healed in the same breath as the operation. `command git` bypasses
# this function (no recursion); the function only exists in interactive shells, so
# hooks calling `git` are unaffected.
git() {
  case "${1:-}" in
    commit|push|merge|rebase|cherry-pick|revert|am) _dotcalum_reconcile_cwd ;;
  esac
  command git "$@"
}

# beads shim: `bd` can re-claim core.hooksPath (init / hook reinstall). Reconcile
# right after it runs so the next commit is already ours again.
if command -v bd >/dev/null 2>&1; then
  bd() { command bd "$@"; local rc=$?; _dotcalum_reconcile_cwd; return $rc; }
fi

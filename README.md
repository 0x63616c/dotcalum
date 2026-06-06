# dotcalum

My dotfiles, configs, and other bits worth sharing across machines.

## Contents

### Hook timing (centralized)

Every git hook and every personal Claude Code hook is routed through a single
dispatcher that times each one and appends a JSONL line to one shared log:
`~/.local/state/hooks/timing.jsonl` (`{ts,source,scope,event,step,ms,exit}`).
See it live with `tail -f ~/.local/state/hooks/timing.jsonl | jq .`.

| Path | What it does |
|---|---|
| `lib/hooklog.sh` | Shared timing/logging primitive both dispatchers source. Millisecond clock (free via bash5 `$EPOCHREALTIME`, perl fallback) + `hooklog_step`. Swallows its own errors so it can never break a commit or a Claude turn. |
| `git/hooks/_dispatch` | Centralized git-hook dispatcher. Every hook name symlinks to it (installed via global `core.hooksPath`). Runs `handlers.d/<hook>/NN-*.sh` in order (drop a file to extend — never edit the dispatcher), times each + the repo's own delegated hook, then chains to it. Gating hooks (`pre-*`, `commit-msg`) fail-fast; `post-*` run everything. |
| `git/hooks/handlers.d/post-commit/` | Current post-commit handlers: `10-lolcommits.sh` (webcam commit selfie), `20-cmux-notify.sh` (cmux toast when committing inside cmux). |
| `git/reconcile-hooks.sh` | **Capture-and-delegate**, so the dispatcher fronts EVERY repo even when beads/lefthook/husky claim a repo-local `core.hooksPath`. Saves the tool's path into `hooks.delegate`, unsets the local override (our dispatcher then delegates back to the tool — nothing breaks). Idempotent + reversible: `--all` (sweep), `--restore [repo]`, `--status`. Opt a repo out with `git config hooks.optout true`. |
| `shell/git-hooks-shell.zsh` | Self-heal triggers sourced from `~/.aliases`: zsh `chpwd` + a `git` wrapper (reconciles before commit/push/merge) + a `bd` shim. Current-repo-only, fail-open. |
| `git/launchd/…plist.template` | Background launchd sweep (`com.calum.git-hooks-reconcile`, every 600s) that re-captures any stray override across all repos. `install.sh` fills in paths and loads it. |
| `git/install.sh` | Points global `core.hooksPath` at `git/hooks`, (re)creates the hook symlinks, wires the shell self-heal into `~/.aliases`, installs+loads the launchd sweep, and runs an initial capture sweep. Idempotent. |
| `shell/claude-wrapper.zsh` | Launch wrapper sourced from `~/.aliases`. Makes `claude` and `c` identical — both always run with `--dangerously-skip-permissions`; `cc` is the escape hatch (no skip). Every launch first runs the pre-session lifecycle hook. `command claude` bypasses the functions to the real binary, so no recursion and cmux integration is preserved. |
| `claude/hooks/dispatch.sh` | Transparent Claude-hook timing wrapper: `dispatch.sh <Event> <label> <cmd...>` runs the real hook with stdin/stdout/exit inherited (Claude's hook protocol untouched), times it, logs one line. |
| `claude/hooks/wire-timing.sh` | Idempotent jq transform that routes Calum's **personal** `settings.json` hooks through `dispatch.sh`. Leaves externally-managed hooks (NotchBar, tagged `# notchbar-`) alone. Backs up + validates before replacing. |
| `claude/hooks/pre-session.sh` | Pre-session lifecycle hook. Runs once before every `claude`/`c`/`cc` launch (before the actual session starts), receives the launch args, best-effort (exit code doesn't block). Edit it to run anything you want before any session. |
| `skills/install-claude-hooks/` | Skill + `install.sh` to symlink the wrapper sourcing, pre-session hook, `dispatch.sh`, and this skill into `~/.claude`, and run `wire-timing.sh`. Idempotent. |

### `claude/`

[Claude Code](https://claude.com/claude-code) setup. Symlink these into `~/.claude/`.

| Path | What it does |
|---|---|
| `hooks/rename-workspace-nudge.sh` | `UserPromptSubmit` hook that nudges Claude to re-title the current [cmux](https://github.com/manaflow-ai/cmux) workspace when the title no longer matches the work. |
| `skills/rename-workspace/` | Skill + script to rename the current cmux workspace title (and log the rename to the workspace↔session map for `cwr`). |
| `skills/move-to-new-workspace/` | Skill to split the current cmux tab out into a brand-new workspace. |
| `skills/organize-window/` | Skill to organize a cmux window's workspaces into themed, collapsible groups, each with a distinct color and SF Symbol icon. |
| `skills/saving-a-memory/` | Skill for where/how to save memories (global `~/.claude/CLAUDE.md` by default; never project-local from a worktree). |
| `skills/using-1password/` | Skill for using the `op` CLI — Homelab vault, the read-cache shim staleness trap, and the save-script pattern for new secrets. |
| `skills/writing-goals/` | Skill for composing `/goal` conditions that are tight, transcript-verifiable, and dodge-proof. |

> The workspace skills/hook need [cmux](https://github.com/manaflow-ai/cmux) on the machine.

## Install

```bash
git clone https://github.com/0x63616c/dotcalum.git
cd dotcalum

# Centralized git-hook dispatcher: sets global core.hooksPath, times every hook,
# wires the self-heal (shell + launchd), and captures repos that claim core.hooksPath
./git/install.sh

# Claude launch wrapper + pre-session hook + hook-timing dispatcher
# (symlinks, wires ~/.aliases, routes personal settings.json hooks through dispatch.sh)
./claude/skills/install-claude-hooks/install.sh   # then run `reload`

# Claude hooks + skills
ln -s "$PWD/claude/hooks/rename-workspace-nudge.sh"        ~/.claude/hooks/
ln -s "$PWD/claude/skills/rename-workspace"                ~/.claude/skills/rename-workspace
ln -s "$PWD/claude/skills/move-to-new-workspace"           ~/.claude/skills/move-to-new-workspace
ln -s "$PWD/claude/skills/organize-window"                 ~/.claude/skills/organize-window
ln -s "$PWD/claude/skills/saving-a-memory"                 ~/.claude/skills/saving-a-memory
ln -s "$PWD/claude/skills/using-1password"                 ~/.claude/skills/using-1password
ln -s "$PWD/claude/skills/writing-goals"                   ~/.claude/skills/writing-goals
```

Then wire the hook into `~/.claude/settings.json` under `hooks.UserPromptSubmit`:

```json
{ "type": "command", "command": "/Users/<you>/.claude/hooks/rename-workspace-nudge.sh" }
```

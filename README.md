# dotcalum

My dotfiles, configs, and other bits worth sharing across machines.

## Contents

### `claude/`

[Claude Code](https://claude.com/claude-code) setup. Symlink these into `~/.claude/`.

| Path | What it does |
|---|---|
| `shell/claude-wrapper.zsh` | Launch wrapper sourced from `~/.aliases`. Makes `claude` and `c` identical — both always run with `--dangerously-skip-permissions`; `cc` is the escape hatch (no skip). Every launch first runs the pre-session lifecycle hook. `command claude` bypasses the functions to the real binary, so no recursion and cmux integration is preserved. |
| `hooks/pre-session.sh` | Pre-session lifecycle hook. Runs once before every `claude`/`c`/`cc` launch (before the actual session starts), receives the launch args, best-effort (exit code doesn't block). Edit it to run anything you want before any session. |
| `skills/install-claude-hooks/` | Skill + `install.sh` to symlink the wrapper sourcing, pre-session hook, and this skill into `~/.claude`. Idempotent. |
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

# Claude launch wrapper + pre-session hook (symlinks + wires ~/.aliases)
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

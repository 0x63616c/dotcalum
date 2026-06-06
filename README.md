# dotcalum

My dotfiles, configs, and other bits worth sharing across machines.

## Contents

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

# dotcalum

My dotfiles, configs, and other bits worth sharing across machines.

## Contents

### `claude/`

[Claude Code](https://claude.com/claude-code) setup. Symlink these into `~/.claude/`.

| Path | What it does |
|---|---|
| `hooks/rename-workspace-nudge.sh` | `UserPromptSubmit` hook that nudges Claude to re-title the current [cmux](https://github.com/manaflow-ai/cmux) workspace when the title no longer matches the work. |
| `skills/rename-workspace/` | Skill + script to rename the current cmux workspace and assign the least-used named color (load-balanced). |
| `skills/move-to-new-workspace/` | Skill to split the current cmux tab out into a brand-new workspace. |

> The workspace skills/hook need [cmux](https://github.com/manaflow-ai/cmux) on the machine.

### `cmux/`

[cmux](https://github.com/manaflow-ai/cmux) settings. Symlink (or copy) into `~/.config/cmux/`.

| Path | What it does |
|---|---|
| `cmux.json` | cmux config (JSONC template — uncomment settings to make them file-managed). |
| `settings.json` | cmux settings; takes precedence over the Application Support fallback. |

## Install

```bash
git clone https://github.com/0x63616c/dotcalum.git
cd dotcalum

# Claude hooks + skills
ln -s "$PWD/claude/hooks/rename-workspace-nudge.sh"        ~/.claude/hooks/
ln -s "$PWD/claude/skills/rename-workspace"                ~/.claude/skills/rename-workspace
ln -s "$PWD/claude/skills/move-to-new-workspace"           ~/.claude/skills/move-to-new-workspace

# cmux settings
ln -s "$PWD/cmux/cmux.json"                                ~/.config/cmux/cmux.json
ln -s "$PWD/cmux/settings.json"                            ~/.config/cmux/settings.json
```

Then wire the hook into `~/.claude/settings.json` under `hooks.UserPromptSubmit`:

```json
{ "type": "command", "command": "/Users/<you>/.claude/hooks/rename-workspace-nudge.sh" }
```

---
name: rename-workspace
description: Use when Calum runs /rename-workspace, or asks to rename/retitle the current cmux workspace/tab to reflect what's being worked on.
---

# Rename Workspace

Rename the current cmux workspace to a short summary of recent work.

## Steps

1. Summarize the last few messages into a **5-6 word** title (Title Case, no trailing punctuation). Describe the work, not the chat. e.g. `Auto-rename cmux workspace skill`.
2. Run the script with that title. It renames the current workspace (title only, no color change):
   ```bash
   ~/.claude/skills/rename-workspace/rename-workspace.sh "<title>"
   ```
3. Confirm the new title back to Calum in one line (the script prints it).

## Notes

- Always targets the current workspace. ~0.3s (cmux socket round-trip).
- This is cmux's workspace title (set over its socket), not the terminal tab title Claude Code clobbers, so it sticks.

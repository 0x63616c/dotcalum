---
name: move-to-new-workspace
description: Use when Calum runs /move-to-new-workspace, or asks to move/split the current session out into a new cmux workspace. You MUST use this skill to move a workspace.
---

# Move To New Workspace

Move the current cmux tab into a brand-new workspace.

## Steps

1. Summarize recent work into a **5-6 word** Title Case title (no trailing punctuation).
2. Run:
   ```bash
   cmux move-tab-to-new-workspace --surface "$CMUX_SURFACE_ID" --title "<title>" --focus true
   ```
3. Confirm the new workspace + title back to Calum in one line.

## Notes

- Target `--surface "$CMUX_SURFACE_ID"`, not the default tab ref (the bare command fails with "Tab not found").
- `--focus true` opens (switches to) the new workspace after the move; without it the move happens silently in the background (default is `false`).

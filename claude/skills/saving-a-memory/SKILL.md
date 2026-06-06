---
name: saving-a-memory
description: Use whenever Calum says "save globally", "remember this", or you're about to write to a memory file (`~/.claude/CLAUDE.md`, project-local `memory/`, or any `MEMORY.md`). Saves go global by default; project-local saves from inside a git worktree silently disappear.
---

# Saving a memory

## "Save globally"

Calum says "save globally" → ALSO update `~/.claude/CLAUDE.md`.

If the memory is heavy (>10 lines, full pattern with examples), DON'T inline-stuff `~/.claude/CLAUDE.md`. Instead:

1. Write the full detail to `~/.claude/docs/<topic>.md` (or to a `~/.claude/skills/<skill-name>/SKILL.md` if it fits the skill model — has a clear trigger and self-contained instructions).
2. In `~/.claude/CLAUDE.md`, add a one-line trigger pointing at the doc / skill. Use forceful language: "TOUCHING X? YOU MUST READ <path> FIRST. NO EXCEPTIONS."
3. The triggered-docs table in CLAUDE.md is the canonical index — add an entry there.

## Default is global

When in doubt, save to `~/.claude/CLAUDE.md` (or a doc/skill it points at). Project-local memory is rarely worth it — by the time the next session opens, you're often in a different repo anyway.

## CRITICAL: never write project-local memory from a worktree

NEVER save to a project-local `memory/` dir while cwd is inside a worktree (e.g. `.claude/worktrees/<branch>/`).

**Why:** auto-memory is keyed by cwd. Writes from the worktree land in a different project memory dir than the main repo will read from on the next session. Result: the memory **disappears**.

**If you must write project-local memory:** `cd` to the canonical repo path first (the non-worktree clone), then write.

## Format inside CLAUDE.md or any doc

- Bullet points or short paragraphs. No prose-walls.
- Lead with the rule. Then "Why:" if non-obvious.
- Forceful language for non-negotiables: ALL CAPS, "NEVER", "ALWAYS", "MUST".
- Link to docs / skills rather than inline-stuffing long patterns.

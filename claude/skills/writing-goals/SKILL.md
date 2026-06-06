---
name: writing-goals
description: Use when Calum asks to create, write, set, formulate, or improve a /goal (Claude Code's goal command). ALWAYS load this BEFORE composing any goal condition, no matter what — even a one-line "set a goal to X" request.
---

# Writing Goals

## Core principle

A `/goal` condition is judged by a fast model running as a Stop hook. **The evaluator only reads the conversation transcript — it does NOT run commands or read files.** So the goal must be provable from Claude's own surfaced output, and the more specific the condition, the less room Claude has to declare victory early or wander off.

**Vague goals go off the rails. Specific goals can't.**

## The formula

Every goal = **end state + the exact check that proves it + the boundaries that must not move**.

1. **One measurable end state** — an exit code, a count, an empty queue, a clean tree. Not "it works", not "the bug is fixed".
2. **The exact check** — name the command and the success signal: ``gate.sh`` exits 0, "142 tests pass", ``git status`` clean.
3. **Boundaries / forbidden shortcuts** — what must NOT change to get there: don't delete or skip tests, don't touch other files, don't weaken assertions.

## Make it sharper (the specificity ladder)

Calum's rule: keep tightening until there's exactly one way to satisfy it. "All tests pass and lint is clean" is a starting point, not a finished goal.

| Level | Condition |
|---|---|
| ❌ Vague | `fix the bug` / `make it work` / `optimize performance` |
| ⚠️ Loose | `all tests pass and lint is clean` |
| ✅ Tight | ``gate.sh`` exits 0 with zero warnings, all 142 tests in `test/` pass with 0 skipped and 0 new xfail, ``git status`` shows only the files I set out to change, and no test was deleted or weakened to get there |

Each rung adds a dimension Claude could otherwise exploit:
- **Exact signal** — `exit 0` / a count, not "passes"
- **Scope** — *which* tests, *which* files
- **Anti-cheating** — forbid skip/xfail/delete/weaken (the evaluator can see the transcript, so name the dodge)
- **Blast radius** — only the intended files changed

## Fuzzy goals (no natural exit code)

The dangerous case: "document the config module", "clean up X", "improve the API". There's no command that returns 0/1, so a vague goal lets Claude declare victory on a vibe. **Invent a transcript-checkable proxy:**

- A **count driven to 0** — "surface the count of exported symbols with no doc comment, show it reach 0" (or a `missing_docs` / doc-lint that exits 0).
- A **command** that stands in for the quality — a linter/formatter/typecheck on the named scope, exit 0, output shown.
- And an **anti-fake clause** — "no placeholder or TODO doc comments", "don't suppress warnings or weaken the linter config to pass".

Never ship a goal whose only success word is "clean", "good", or "well-documented". The evaluator can't judge a vibe.

## Quick checklist

- [ ] Can I name the single command whose output settles done-or-not? If not, tighten.
- [ ] Is the success signal exact (exit code / count), not a vibe?
- [ ] Did I forbid the obvious shortcuts (skipping tests, editing unrelated files, loosening asserts)?
- [ ] Is the scope named (which files / which suite)?

## Common mistakes

- **Unverifiable from transcript** — `the code is correct`. The evaluator can't check it. Make Claude run a command and surface the result.
- **Leaving the dodge open** — `all tests pass` invites `#[ignore]` / `.skip`. Close it: "...with 0 skipped and no test deleted."
- **No scope** — `tests pass` vs `all tests in test/auth pass`. Name it.

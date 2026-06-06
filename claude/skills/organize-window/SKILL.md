---
name: organize-window
description: Use when Calum runs /organize-window, or asks to "organize this window", "organize my workspaces", "group these workspaces", "tidy the window", or "organize all my windows". Organizes the cmux workspaces in a window into sensible, themed, collapsible groups, each with a distinct color and a fitting SF Symbol icon.
---

# Organize Window

Sort the cmux workspaces in a window into a small set of themed, collapsible groups — each group gets its own name, a DISTINCT color, and a fitting SF Symbol icon. This is a judgment skill: read the actual workspaces and pick names/colors/icons that fit what you see. Do NOT hardcode a palette or icon set.

Default scope is the **current window**. If Calum says "all windows", iterate over every window.

## Steps

1. **Inspect first — never change anything before you've looked.**
   - `cmux current-window` and `cmux list-windows` to know the scope.
   - For each target window, `cmux workspace list --window <id> --json` to read every workspace's title, cwd, pinned state, `custom_color`, and `latest_submitted_message`.
   - `cmux workspace-group list --window <id> --json` to see groups that already exist.
2. **Infer themes.** Cluster the workspaces by title / cwd / recent activity into a small coherent set of groups (aim ~4-8). Name each group for its theme.
3. **Pick per group:** a name, a DISTINCT color (no two groups share one), and a fitting SF Symbol icon. Choose contextually — a "Bugs" group might get `ladybug`/Red, "Infra" `server.rack`/Charcoal, "Docs" `doc.text`/Teal. Examples are inspiration, not a fixed list.
4. **Be idempotent.** If groups already exist, rebalance/extend them rather than creating duplicates. Move stray workspaces into the right existing group; only create groups for genuinely new themes.
5. **Create / populate groups** (see commands). For a cohesive band, set each member workspace's color to match its group.
6. **Report** the resulting structure as a compact table (group → color → icon → member workspaces).

## Boundaries

- ONLY organize: group, color, icon, optional description. Do NOT rename workspaces. Do NOT run any commands inside the terminals.

## cmux command reference

```
Inspect:
  cmux list-windows
  cmux current-window
  cmux workspace list [--window <id|ref|index>] --json     # titles, cwd, pinned, custom_color, latest_submitted_message
  cmux workspace-group list [--window <id|ref|index>] --json

Named colors (or use --color "#RRGGBB"):
  Red, Crimson, Orange, Amber, Olive, Green, Teal, Aqua, Blue, Navy, Indigo, Purple, Magenta, Rose, Brown, Charcoal

Create a group (spawns a dedicated labeled HEADER/anchor workspace and nests the members):
  cmux workspace-group create --name "Name" --from <ref>,<ref>,... --json   # returns group ref like workspace_group:N
Add/remove a member:
  cmux workspace-group add --group <group> --workspace <ref>
  cmux workspace-group remove --workspace <ref>
Group color / icon (SF Symbol):
  cmux workspace-group set-color <group> --hex "#RRGGBB"
  cmux workspace-group set-icon  <group> --symbol "square.grid.2x2"
Pin / collapse a group:
  cmux workspace-group pin <group>
  cmux workspace-group collapse <group>
Per-workspace color (match members to their group for a cohesive band):
  cmux workspace-action --workspace <ref> --action set-color --color <name|#hex>
Optional per-workspace description:
  cmux workspace-action --workspace <ref> --action set-description --description "text"
```

## Gotchas (critical)

- **PINNED workspaces cannot join a group** — you get `invalid_state: Workspace is pinned`. Unpin first, then add:
  ```
  cmux workspace-action --workspace <ref> --action unpin
  ```
  Optionally re-pin the resulting GROUP (`cmux workspace-group pin <group>`) to keep it at the top.
- `workspace-group create` creates a NEW empty header/anchor workspace named after the group; the real task workspaces nest under it. This is the desired clean "section header" look.
- Adding the live/current session's own workspace to a group is fine (it's not pinned).
- Workspace refs (`workspace:N`) are per-window; pass `--window` when targeting another window.
- SF Symbol icon examples (pick contextually, don't be limited to these): `square.grid.2x2`, `ladybug`, `shippingbox`, `wrench.and.screwdriver`, `checklist`, `terminal`, `menubar.rectangle`, `paintbrush.pointed`, `hammer`, `network`, `server.rack`, `globe`, `doc.text`, `gearshape`, `flask`, `chart.bar.xaxis`, `bolt`, `sparkles`, `folder`, `cube.box`, `books.vertical`, `testtube.2`.

#!/usr/bin/env bash
# Rename the current cmux workspace and assign the least-used named color.
# Usage: rename-workspace.sh "Five To Six Word Title"
#
# Color choice is load-balanced: every named color starts at count 0, each
# workspace already using a color bumps that color's count, and we pick a
# random color from the lowest-count bucket. This stays even past 16
# workspaces (once all are used once, counts tie at 1 and it balances again).
set -euo pipefail

TITLE="${1:?usage: rename-workspace.sh \"Title\"}"

# Named color -> hex, as cmux stores them in custom_color.
NAMES=(Red Crimson Orange Amber Olive Green Teal Aqua Blue Navy Indigo Purple Magenta Rose Brown Charcoal)
declare -A HEX=(
  [Red]=#C0392B [Crimson]=#922B21 [Orange]=#A04000 [Amber]=#7D6608
  [Olive]=#4A5C18 [Green]=#196F3D [Teal]=#006B6B  [Aqua]=#0E6B8C
  [Blue]=#1565C0 [Navy]=#1A5276  [Indigo]=#283593 [Purple]=#6A1B9A
  [Magenta]=#AD1457 [Rose]=#880E4F [Brown]=#7B3F00 [Charcoal]=#3E4B5E
)

# Reverse map hex -> name for counting in-use colors.
declare -A NAME_OF
for n in "${NAMES[@]}"; do NAME_OF[${HEX[$n]^^}]="$n"; done

# Tally every workspace's color across every window.
declare -A COUNT
for n in "${NAMES[@]}"; do COUNT[$n]=0; done
while read -r idx; do
  while read -r hex; do
    [ -z "$hex" ] && continue
    name="${NAME_OF[${hex^^}]:-}"
    [ -n "$name" ] && COUNT[$name]=$(( COUNT[$name] + 1 ))
  done < <(CMUX_QUIET=1 cmux workspace list --json --window "$idx" 2>/dev/null \
             | jq -r '.workspaces[].custom_color // empty')
done < <(CMUX_QUIET=1 cmux list-windows 2>/dev/null | sed -E 's/^\*? *([0-9]+):.*/\1/')

# Find the minimum count, collect all colors at that count.
min=-1
for n in "${NAMES[@]}"; do
  c=${COUNT[$n]}
  if [ "$min" -lt 0 ] || [ "$c" -lt "$min" ]; then min=$c; fi
done
bucket=()
for n in "${NAMES[@]}"; do [ "${COUNT[$n]}" -eq "$min" ] && bucket+=("$n"); done

PICK=${bucket[RANDOM % ${#bucket[@]}]}

CMUX_QUIET=1 cmux rename-workspace "$TITLE" >/dev/null
CMUX_QUIET=1 cmux workspace-action --action set-color --color "$PICK" >/dev/null

echo "Renamed to \"$TITLE\", color $PICK (least-used, count was $min)."

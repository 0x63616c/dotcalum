#!/usr/bin/env bash
set -euo pipefail

# Store an Apple ID login (FASTLANE_SESSION) in 1Password so the skill can create
# App Store Connect app records headlessly. Apple's API key CANNOT create apps
# (apps is GET/UPDATE only), so app creation must go through a Spaceship web
# session — which needs your Apple ID + a 2FA code.
#
# This is one-time setup, BUT Apple expires the session every ~2-4 weeks. When it
# lapses, just re-run this script (one 2FA) — the skill warns you when that's needed.
# Secret capture happens here in the terminal, never in the Claude chat.

VAULT="Homelab"
export ASC_VAULT="$VAULT"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/asc-key.sh"

ITEM="$(asc_resolve)" || { echo "FATAL: no ASC item to attach the session to (run save-asc-key.sh first)" >&2; exit 1; }

command -v fastlane >/dev/null || { echo "FATAL: fastlane not found (gem install fastlane)" >&2; exit 1; }

echo "Apple ID login for headless app creation."
read -rp "Apple ID (developer account email): " APPLE_ID
[ -n "$APPLE_ID" ] || { echo "FATAL: empty Apple ID" >&2; exit 1; }

echo "Running fastlane spaceauth — enter your Apple password + 2FA code when prompted."
# Prompts go to the terminal (2>/dev/tty); the `export FASTLANE_SESSION=...` line
# is printed to stdout and captured here.
SESSION_OUT="$(fastlane spaceauth -u "$APPLE_ID" 2>/dev/tty)"
# shellcheck disable=SC2086
eval "$(printf '%s\n' "$SESSION_OUT" | grep -E '^export FASTLANE_SESSION=')"
[ -n "${FASTLANE_SESSION:-}" ] || { echo "FATAL: spaceauth produced no session" >&2; exit 1; }

op item edit "$ITEM" --vault "$VAULT" \
  "apple-id[text]=$APPLE_ID" \
  "fastlane-session[password]=$FASTLANE_SESSION" >/dev/null

# Invalidate the op-shim read cache for the new refs (REQUIRED after a write).
EVEE_OP_DIR="${OP_CACHE_DIR:-$HOME/.local/share/evee-op}"
if [ -d "$EVEE_OP_DIR" ]; then
  for REF in "op://$VAULT/$ITEM/apple-id" "op://$VAULT/$ITEM/fastlane-session"; do
    KEY_HASH=$(printf '%s' "$REF" | shasum -a 256 | cut -d' ' -f1)
    rm -f "$EVEE_OP_DIR/$KEY_HASH"
  done
fi

echo "Verifying..."
apple_id >/dev/null && fastlane_session >/dev/null \
  && echo "  ok - stored on op://$VAULT/$ITEM (apple-id, fastlane-session)"
echo "Note: this session expires in ~2-4 weeks; re-run this script then (one 2FA)."

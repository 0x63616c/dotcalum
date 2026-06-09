#!/usr/bin/env bash
set -euo pipefail

# Sync signing secrets from 1Password (source of truth) into a repo's GitHub
# secrets (a synced copy CI reads). Re-run after rotating any cert/key.
#
# Usage: sync-secrets.sh <owner/repo> <app_name> [ios|macos]
#   app_name must match the one used in setup-app.sh (-> <app>-signing item).

REPO="${1:?usage: sync-secrets.sh <owner/repo> <app_name> [ios|macos]}"
APP_NAME="${2:?app name required}"
PLATFORM="${3:-ios}"
VAULT="Homelab"
SIGN_ITEM="${APP_NAME// /-}-signing"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ASC_VAULT="$VAULT"
source "$SKILL_DIR/scripts/lib/asc-key.sh"

command -v gh >/dev/null || { echo "FATAL: gh not found" >&2; exit 1; }
gh repo view "$REPO" >/dev/null 2>&1 || { echo "FATAL: cannot see repo $REPO" >&2; exit 1; }

set_secret() { gh secret set "$1" --repo "$REPO" --body "$2" >/dev/null && echo "  set $1"; }

echo "==> syncing secrets to $REPO"
echo "    ASC key: op://$VAULT/$(asc_resolve)"
set_secret ASC_KEY_ID    "$(asc_key_id)"
set_secret ASC_ISSUER_ID "$(asc_issuer_id)"
# p8 base64-encoded so it survives as a single-line GitHub secret.
set_secret ASC_KEY_P8    "$(asc_p8_base64)"

set_secret SIGNING_P12          "$(op read "op://$VAULT/$SIGN_ITEM/p12")"
set_secret SIGNING_P12_PASSWORD "$(op read "op://$VAULT/$SIGN_ITEM/p12-password")"
if [ "$PLATFORM" = "ios" ]; then
  set_secret PROVISIONING_PROFILE "$(op read "op://$VAULT/$SIGN_ITEM/profile")"
fi

echo "==> done. Push a tag (vX.Y.Z) to trigger a release."

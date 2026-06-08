#!/usr/bin/env bash
set -euo pipefail

# Provision an app: register bundle id + app record, mint signing cert/profile,
# store the minted assets into 1Password. Idempotent. Run from the app repo root.
#
# Usage: setup-app.sh <ios|macos> <bundle_id> <app_name>

PLATFORM="${1:?platform required: ios|macos}"
BUNDLE_ID="${2:?bundle id required, e.g. co.worldwidewebb.myapp}"
APP_NAME="${3:?app name required}"
VAULT="Homelab"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$PLATFORM" in ios|macos) ;; *) echo "FATAL: platform must be ios|macos" >&2; exit 1 ;; esac

# --- ASC API key from 1Password -> env for fastlane -------------------------
export ASC_ISSUER_ID="$(op read "op://$VAULT/asc-api-key/issuer-id")"
export ASC_KEY_ID="$(op read "op://$VAULT/asc-api-key/key-id")"
ASC_KEY_P8_RAW="$(op read "op://$VAULT/asc-api-key/p8")"
# Fastfile reads the key content base64-encoded (newline-safe across env).
export ASC_KEY_P8="$(printf '%s' "$ASC_KEY_P8_RAW" | base64)"
[ -n "$ASC_ISSUER_ID" ] && [ -n "$ASC_KEY_ID" ] && [ -n "$ASC_KEY_P8" ] \
  || { echo "FATAL: ASC key missing in 1Password. Run save-asc-key.sh first." >&2; exit 1; }

# --- Drop fastlane templates into the repo if missing -----------------------
mkdir -p fastlane
[ -f fastlane/Fastfile ] || cp "$SKILL_DIR/templates/Fastfile" fastlane/Fastfile
[ -f Gemfile ]           || cp "$SKILL_DIR/templates/Gemfile" Gemfile
command -v bundle >/dev/null || { echo "FATAL: bundler not found (gem install bundler)" >&2; exit 1; }
bundle install --quiet

# --- Provision: bundle id, app record, cert, profile ------------------------
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export BUNDLE_ID APP_NAME
export CERT_OUTPUT_PATH="$WORK"   # Fastfile writes the .p12 here

echo "==> fastlane setup_$PLATFORM ($BUNDLE_ID)"
bundle exec fastlane "setup_$PLATFORM" \
  bundle_id:"$BUNDLE_ID" app_name:"$APP_NAME"

# --- Store the minted signing assets into 1Password -------------------------
P12="$(ls "$WORK"/*.p12 2>/dev/null | head -1 || true)"
[ -f "$P12" ] || { echo "FATAL: no .p12 produced by fastlane" >&2; exit 1; }
P12_B64="$(base64 < "$P12")"
# Fastfile writes the generated passphrase to $WORK/p12.pass.
P12_PASS="$(cat "$WORK/p12.pass" 2>/dev/null || echo "")"
PROFILE_B64=""
if [ "$PLATFORM" = "ios" ]; then
  PROF="$(ls "$WORK"/*.mobileprovision 2>/dev/null | head -1 || true)"
  [ -f "$PROF" ] && PROFILE_B64="$(base64 < "$PROF")"
fi

SIGN_ITEM="${APP_NAME// /-}-signing"
FIELDS=( "p12[password]=$P12_B64" "p12-password[password]=$P12_PASS" )
[ -n "$PROFILE_B64" ] && FIELDS+=( "profile[password]=$PROFILE_B64" )

if op item get "$SIGN_ITEM" --vault "$VAULT" >/dev/null 2>&1; then
  op item edit "$SIGN_ITEM" --vault "$VAULT" "${FIELDS[@]}" >/dev/null
else
  op item create --vault "$VAULT" --category "Secure Note" --title "$SIGN_ITEM" "${FIELDS[@]}" >/dev/null
fi

# Invalidate op-shim cache for the new refs.
EVEE_OP_DIR="${OP_CACHE_DIR:-$HOME/.local/share/evee-op}"
if [ -d "$EVEE_OP_DIR" ]; then
  for f in p12 p12-password profile; do
    KEY_HASH=$(printf '%s' "op://$VAULT/$SIGN_ITEM/$f" | shasum -a 256 | cut -d' ' -f1)
    rm -f "$EVEE_OP_DIR/$KEY_HASH"
  done
fi

echo "==> done. Signing assets in op://$VAULT/$SIGN_ITEM"
echo "    Next: sync-secrets.sh <owner/repo>"

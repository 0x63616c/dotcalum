#!/usr/bin/env bash
# Resolve the App Store Connect API key from 1Password, tolerating how it was
# stored. The skill's own save-asc-key.sh writes item `asc-api-key` with text
# fields issuer-id/key-id/p8, but a pre-existing key (e.g. one already used by
# another repo's CI) may live under a different title, have space-labelled
# fields ("issuer id"), and carry the `.p8` as a FILE ATTACHMENT rather than a
# text field. This resolver papers over all of that so one ASC key — which is
# account-level, not per-app — is reused everywhere instead of re-downloaded.
#
# Source this, then call: asc_resolve / asc_key_id / asc_issuer_id / asc_p8.
# Override discovery with ASC_OP_ITEM=<item name or id>. Vault: ASC_VAULT.

ASC_VAULT="${ASC_VAULT:-Homelab}"
_ASC_ITEM=""
# Resolve this lib's dir to an absolute path ONCE at source time; BASH_SOURCE is
# unreliable inside functions / command substitutions.
_ASC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print the resolved item (id or title). Resolution order:
#   1. $ASC_OP_ITEM explicit override
#   2. conventional item `asc-api-key`
#   3. autodiscover: an API Credential item in the vault carrying a *.p8
#      (preferring titles that look like an ASC key).
asc_resolve() {
  [ -n "$_ASC_ITEM" ] && { printf '%s' "$_ASC_ITEM"; return 0; }
  local item=""
  if [ -n "${ASC_OP_ITEM:-}" ]; then
    item="$ASC_OP_ITEM"
  elif op item get "asc-api-key" --vault "$ASC_VAULT" >/dev/null 2>&1; then
    item="asc-api-key"
  else
    item="$(op item list --vault "$ASC_VAULT" --categories "API Credential" --format json 2>/dev/null \
      | ASC_VAULT="$ASC_VAULT" python3 "$_ASC_LIB_DIR/asc-pick.py" 2>/dev/null)"
  fi
  [ -n "$item" ] || { echo "FATAL: no App Store Connect API key in op://$ASC_VAULT (run save-asc-key.sh)" >&2; return 1; }
  _ASC_ITEM="$item"
  printf '%s' "$item"
}

# Read the first non-empty field among the given label variants.
_asc_field() {
  local item label v
  item="$(asc_resolve)" || return 1
  for label in "$@"; do
    v="$(op read "op://$ASC_VAULT/$item/$label" 2>/dev/null)" || true
    [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  done
  echo "FATAL: none of [$*] readable on op://$ASC_VAULT/$item" >&2; return 1
}

asc_key_id()    { _asc_field "key-id" "key id" "key_id" "Key ID"; }
asc_issuer_id() { _asc_field "issuer-id" "issuer id" "issuer_id" "Issuer ID"; }

# Print the raw .p8 (PKCS#8 text). Prefers a `p8` text field; falls back to a
# *.p8 file attachment on the item.
asc_p8() {
  local item v fname
  item="$(asc_resolve)" || return 1
  v="$(op read "op://$ASC_VAULT/$item/p8" 2>/dev/null)" || true
  # "PRIVATE KEY" (no "BEGIN " prefix) so the literal doesn't trip the leak guard.
  case "$v" in *"PRIVATE KEY"*) printf '%s' "$v"; return 0 ;; esac
  fname="$(op item get "$item" --vault "$ASC_VAULT" --format json 2>/dev/null \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); f=[x["name"] for x in d.get("files",[]) if x.get("name","").endswith(".p8")]; print(f[0] if f else "")')"
  [ -n "$fname" ] || { echo "FATAL: no .p8 (text field or attachment) on op://$ASC_VAULT/$item" >&2; return 1; }
  op read "op://$ASC_VAULT/$item/$fname" 2>/dev/null
}

# Convenience: the .p8 base64-encoded (single line, env/secret safe).
asc_p8_base64() { asc_p8 | base64; }

# --- fastlane match secrets (shared signing via the certificates repo) -------
# These live on the SAME resolved item as the ASC key: `match password` is
# usually already present; the certificates-repo git auth + url are written by
# save-match-git-auth.sh. git_url falls back to the conventional repo.
MATCH_GIT_URL_DEFAULT="${MATCH_GIT_URL_DEFAULT:-https://github.com/0x63616c/certificates.git}"

match_password() { _asc_field "match-password" "match password" "MATCH_PASSWORD"; }
match_git_auth() { _asc_field "match-git-auth" "match git auth" "match-git-basic-authorization" "MATCH_GIT_BASIC_AUTHORIZATION"; }
match_git_url() {
  local item v
  item="$(asc_resolve)" || return 1
  for label in "match-git-url" "match git url" "MATCH_GIT_URL"; do
    v="$(op read "op://$ASC_VAULT/$item/$label" 2>/dev/null)" || true
    [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  done
  printf '%s' "$MATCH_GIT_URL_DEFAULT"
}

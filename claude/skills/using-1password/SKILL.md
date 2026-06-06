---
name: using-1password
description: Use whenever you touch the `op` (1Password CLI) for any reason — reading a secret (`op read`), saving or rotating one, debugging stale-creds / 401 errors, or writing a `scripts/save-<thing>.sh`. Calum's local `op` is a PATH shim that caches reads for 24h and must be invalidated on write, and new secrets always ship with an interactive save script.
---

# Using `op` (1Password CLI)

## Calum's vault is "Homelab" — always

- All refs are `op://Homelab/<Item>/<field>`. Never guess other vault names.
- SSH agent socket: `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`.
- Prefer `op run` / `op inject` over plaintext `.env`.

## The shim — silent staleness trap

Calum installed a PATH shim at `~/.local/bin/op` → `~/code/github.com/0x63616c/evee/scripts/lib/op-shim.sh`. Reason: local agents hammered 1Password and got rate-limited.

- Caches `op read op://...` for **24h** at `~/.local/share/evee-op/<sha256-of-ref>` (XOR-obscured, mode 0600).
- Other op subcommands (`op item edit`, `op inject`) pass through to real op.
- After any rotation, `op read` returns the **stale cached value** until invalidated.
- Bust script (full reset): `~/code/github.com/0x63616c/evee/scripts/ops/op-cache-bust.sh`.

### The trap

Symptom when missed: deploys ship stale creds, get 401s, you waste an hour debugging ghosts.

### The fix

Per-ref invalidation, baked into every save-*.sh:

```bash
EVEE_OP_DIR="${OP_CACHE_DIR:-$HOME/.local/share/evee-op}"
if [ -d "$EVEE_OP_DIR" ]; then
  KEY_HASH=$(printf '%s' "$REF" | shasum -a 256 | cut -d' ' -f1)
  rm -f "$EVEE_OP_DIR/$KEY_HASH"
fi
```

`$REF` = exact string used in `op read` (e.g. `op://Homelab/Claude Code OAuth/credential`). The shim hashes the ref → cache filename, so deleting that file invalidates just that secret.

### Don't do

NEVER add `--cache=false` to `op read` calls in deploy scripts. Defeats the rate-limit protection that's the whole point. Bust on write instead.

## New secret → ALWAYS write a save script

When Calum needs to add a new credential / key / token to 1Password, write `scripts/save-<thing>.sh`. **Never just tell him the path/value** — he'll mess up naming/casing/field. The script eliminates that.

### Template

```bash
#!/usr/bin/env bash
set -euo pipefail

ITEM="My Service"
VAULT="Homelab"
REF="op://$VAULT/$ITEM/credential"

echo "Step 1. <where to get the credential>"
read -rsp "Paste <X>: " VAL; echo
[ -n "$VAL" ] || { echo "FATAL: empty" >&2; exit 1; }

if op item get "$ITEM" --vault "$VAULT" >/dev/null 2>&1; then
  op item edit "$ITEM" --vault "$VAULT" "credential[password]=$VAL" >/dev/null
else
  op item create --vault "$VAULT" --category "API Credential" --title "$ITEM" \
    "credential[password]=$VAL" >/dev/null
fi

# Invalidate the shim cache (REQUIRED — see "The trap" above).
EVEE_OP_DIR="${OP_CACHE_DIR:-$HOME/.local/share/evee-op}"
if [ -d "$EVEE_OP_DIR" ]; then
  KEY_HASH=$(printf '%s' "$REF" | shasum -a 256 | cut -d' ' -f1)
  rm -f "$EVEE_OP_DIR/$KEY_HASH"
fi

echo "Verifying..."
op read "$REF" >/dev/null && echo "  ok"
```

### Verify

Always read back: `op read "$REF" >/dev/null && echo "ok"`. Catches when the write silently went to the wrong field.

### Multi-field items

If the 1Password item has multiple concealed fields (e.g. Linear OAuth: `client-id`, `client-secret`, `webhook-signing-secret`), pass all in one `op item edit` / `op item create` call. Then loop the invalidation over each ref.

### Gold-standard examples

- `evee` repo: `scripts/save-ha-token.sh`, `scripts/save-tesla-credentials`, `scripts/save-tailscale-oauth.sh`, `scripts/save-slack-credentials.sh`
- `the-workflow-engine` repo: `scripts/save-claude-oauth.sh`, `scripts/save-anthropic-api.sh`, `scripts/save-linear-oauth.sh`

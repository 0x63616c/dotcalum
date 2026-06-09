---
name: publish-setup
description: Use when Calum wants to set up Apple app distribution for a repo, ship an app to TestFlight, or build/notarize a macOS app for release. One up-front interview surfaces only the human-only Apple steps (Developer Program enrollment, the one App Store Connect API key), stores signing assets in 1Password (Homelab), syncs them to GitHub secrets, and drops in self-installing CI that ships iOS to TestFlight or a notarized macOS DMG on a version tag. Triggers: "get this on TestFlight", "set up signing", "publish this app", "ship to the App Store", "notarize this Mac app".
---

# publish-setup

Take any app repo to **TestFlight (iOS)** or a **notarized DMG (macOS)** with the
smallest possible manual touch. The principle: **ask up front for the few things
only a human can do, then automate everything else.** Detect current state first;
ask for nothing you can discover yourself.

Design spec: `dotcalum/docs/superpowers/specs/2026-06-08-publish-setup-skill-design.md`.

## Operating rules

- **1Password is the source of truth.** Vault is always `Homelab`. Certs/keys live
  there; GitHub secrets are a synced copy pushed by `sync-secrets.sh`. CI never
  touches 1Password (no service account).
- **Secrets never enter the chat.** Capturing any credential happens in an
  interactive terminal script (`scripts/save-asc-key.sh`), terminal → 1Password.
  Never ask Calum to paste a `.p8`/`.p12` into the conversation.
- **No `fastlane match`** (no 1Password backend). Certs are minted by
  `fastlane cert`/`sigh`, stored in 1Password, synced to GitHub secrets.
- **Idempotent.** Every script is safe to re-run; second run is a near no-op.

## Checklist (work top to bottom; create a TodoWrite item per step)

> **Front-load every human-only input before you automate anything.** Steps 0 and
> 0.5 below come first and gather ALL human-gated inputs in one batch, so Calum can
> work them in parallel (downloading the ASC key, confirming enrollment) while you
> build the rest. Do NOT start step 3+ automation and only later realize you need a
> credential — that strands Calum waiting. The rule: detect, then ask for
> everything at once, then go heads-down.

### 0. Detect state
Run, in the target repo:
- `command -v fastlane gh op` — tooling present?
- `op item get asc-api-key --vault Homelab >/dev/null 2>&1` — is the ASC key already
  stored? If yes, skip steps 1-2 entirely.
- Inspect repo to classify the app:
  - `Package.swift` or an Xcode macOS target → **macos** (notarize path).
  - `capacitor.config.*` / `ios/App/App.xcodeproj` → **ios** (TestFlight path).
  - bare web app, no native shell → tell Calum it needs Capacitor first; offer to
    add it (out of v1 scope — confirm before doing).

### 0.5. The up-front interview (one batch, before any automation)
Immediately after detection, ask Calum everything only a human can supply — in a
single round of questions, not drip-fed across steps. Then start automating while
he works the manual bits. The full human-only set:
- **Apple Developer Program** — enrolled? (gates everything; see step 1.)
- **App Store Connect API key** — only if `asc-api-key` not already in 1Password.
  Hand him the ASC path + `save-asc-key.sh` command NOW so he can download the
  `.p8` and run the script while you build (see step 2). This is the most common
  thing agents forget to front-load.
- **Bundle ID + app name** — default `co.worldwidewebb.<app>`; confirm once.
- **Capacitor (web-app repos only)** — if there's no native shell, confirm adding
  one (step 0 detection). Don't silently scaffold.
- **Hosted API base URL (Capacitor/iOS)** — a bundled offline shell can't use a
  relative `/api` path; it needs an absolute backend. Ask for the hosted URL, or
  confirm "not hosted yet" and wire it as a build-time `VITE_API_BASE` (Actions
  variable) with a documented placeholder.

Everything below this line is yours to automate. The human-gated items (1, 2) only
*block* the steps that consume them (3, 4) — keep building everything else
(Capacitor shell, CI files, docs) in parallel while Calum handles them.

### 1. Apple Developer Program (only if not enrolled)
Test enrollment by attempting an authenticated call (e.g. `setup-app.sh` dry step,
or `bundle exec fastlane spaceship` token). If unauthenticated/not enrolled, tell
Calum:
> Enroll at https://developer.apple.com/programs/enroll/ ($99/yr). Needs the Apple
> Developer iOS app + ~24-48h for approval. Re-run me once approved.
Then **stop** — nothing downstream works without it.

### 2. App Store Connect API key (only if `asc-api-key` not in 1Password)
Tell Calum the exact path, then hand off to the script:
> App Store Connect → Users and Access → Integrations → App Store Connect API →
> click `+` → name it "CI", role **Admin** → Generate → **Download the `.p8` now**
> (Apple only shows it once). Also copy the **Issuer ID** (top of the page) and the
> new key's **Key ID**.
Then: `bash scripts/save-asc-key.sh` — it prompts for Issuer ID, Key ID, and the
path to the downloaded `.p8`, and writes all three into 1Password.

### 3. Provision the app (per repo)
`bash scripts/setup-app.sh <ios|macos> <bundle_id> <app_name>`
- Copies `templates/Fastfile` + `templates/Gemfile` into the repo if missing.
- `fastlane produce` — registers the bundle ID + App Store Connect app record.
- `fastlane cert` + `fastlane sigh` — mints the distribution cert (`.p12`) and
  profile, reading the ASC key from 1Password.
- Stores the minted `.p12` (base64) + passphrase + profile back into 1Password as
  item `<app>-signing`.
Bundle ID convention: `co.worldwidewebb.<app>` (confirm with Calum on first run).

### 4. Sync secrets to GitHub
`bash scripts/sync-secrets.sh <owner/repo>` — `op read` → `gh secret set` for:
`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `SIGNING_P12`, `SIGNING_P12_PASSWORD`,
and (iOS) `PROVISIONING_PROFILE`. Nothing secret is written to the repo tree.

### 5. Install CI
Copy the matching workflow into the repo:
- ios → `templates/release-ios.yml` → `.github/workflows/release-ios.yml`
- macos → `templates/release-macos.yml` → `.github/workflows/release-macos.yml`
Also install the secret-leak pre-commit guard: `templates/pre-commit-guard.sh` →
`.git/hooks/pre-commit` (or append to existing). It blocks commits containing
`.p8`/`.p12` material or `PRIVATE KEY` blobs.

### 6. Commit + flag minutes
Commit the Fastfile/Gemfile/workflow (no secrets). Remind Calum: a release is
triggered by pushing a tag `vX.Y.Z`. If the repo is **private**, warn that macOS
runner minutes bill at 10x; public repos are free.

## What "done" looks like
Calum pushes `v0.1.0` → CI builds, signs, and either uploads to TestFlight or
notarizes + attaches a DMG to a GitHub Release, with zero further manual steps.

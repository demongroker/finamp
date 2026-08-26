# JellyAmp — Implementation Plan (KEEP + IMPROVE)

**Recommendation:** KEEP the Flutter fork. No rewrite. Small, gated phases; each
reversible. No Jellyfin/Flacky/Telenovela/Requests/CC changes.

---

## Phase 0 — Audit (DONE)

Read-only repo + Jellyfin audit + this document set. Nothing modified.

## Phase 1 — Hardening (no feature work)

1. **Secure token storage** — replace Isar token with `flutter_secure_storage`
   (Keychain/Keystore). Migration: read old token once → write to secure storage →
   delete from Isar.
2. **Tighten ATS** — iOS `NSAllowsArbitraryLoads=false`; require HTTPS. Verify the
   Tailscale HTTPS URL (`https://100.105.81.82:8921`) is the configured server URL.
3. **`main.dart` refactor** — 1316-line bootstrap → `bootstrap()` + `runApp`.
4. **Baseline tests** — unit tests for search-syntax, sort/filter mapping, queue
   aggregation; one widget smoke test (player + queue). CI runs them.

**Gate:** `flutter analyze` delta clean · unit+widget tests pass · release APK still
builds + installs. (APK build requires stopping the media stack first — see
jellyamp-fork-ops skill.)

## Phase 2 — iOS build pipeline (THE delivery gap)

1. Choose a macOS build path: **GitHub Actions macOS runner** (free-ish, no local Mac)
   or **Codemagic** (Flutter CI) or a physical Mac.
2. Apple Developer account + bundle id (`com.demongroker.jellyamp`), signing certs +
   provisioning profile.
3. Produce a signed `.ipa`; automate via CI on tag/push.
4. Distribute: **TestFlight** (needs paid account) or **sideload** (AltStore/SideStore /
   ad-hoc). Decide with owner.

**Gate:** `.ipa` builds green on CI; installs on the iPhone; app launches to login.

## Phase 3 — iPhone E2E validation (on-device checklist)

login (Quick Connect) → browse library → search → artist/album → play a **FLAC** track
and confirm the **Direct Play** chip → lock-screen play/pause/seek/next → Bluetooth/
headphone controls → offline download + offline playback → queue reorder → favorite +
playlist create/add.

**Gate:** every item passes on the device over Tailscale HTTPS.

## Phase 4 — Freeze + release

1. Version bump + CHANGELOG.
2. Tag + publish release (Android APK + iOS via TestFlight).
3. **Freeze** JellyAmp — bugs/security/maintenance only (same policy as Requests).

**Gate:** frozen; subsequent work is maintenance-only.

---

## Effort / risk

| Phase | Effort | Risk |
|---|---|---|
| 1 Hardening | small (hours) | Low — reversible, test-covered |
| 2 iOS pipeline | medium (setup + Apple account) | Medium — external dependency (Apple/macOS) |
| 3 On-device E2E | small | Low |
| 4 Freeze | trivial | Low |

**Biggest external dependency:** Phase 2 (macOS + Apple Developer account). This is the
only non-code blocker and the only item that requires a decision from the owner.

**De-risk note (verified):** upstream Finamp **already ships iOS builds** (App Store,
v0.5.0 first iOS release) with **FLAC direct-play** — the iOS delivery path is proven for
this exact codebase, so Phase 2 is a well-trodden path, not a novel one.

# JellyAmp — Security Model

**Context:** JellyAmp is a **native** Flutter client, not a web app. The mission's
web-style requirements (HttpOnly/SameSite cookies, CSRF tokens) are *inapplicable* to a
native app — there is no browser, no cookie jar, no cross-site request forgery surface.
This document maps each mission security requirement to its native-client equivalent.

---

## 1. Authentication

- **Model:** direct Jellyfin auth — Quick Connect or username/password.
- **Mechanism:** on success Jellyfin returns an `AccessToken` + `UserId`; the app sends
  an `X-Emby-Authorization` header (`Client="Jellyamp", Device, DeviceId, Version,
  UserId, Token`) on every request.
- **No credentials are stored** — only the resulting access token (and the server URL).
  Password is never persisted. ✅ meets "credentials must not leak to browser code" (there
  is no browser code).

## 2. Token storage (HARDEN — P0)

- **Current:** `FinampUser.accessToken` is stored in an **Isar** DB file (app-private
  storage). Not world-readable, but not hardware-backed.
- **Target:** move to **`flutter_secure_storage`** → iOS **Keychain** / Android
  **Keystore**. This is the single most important pre-ship security change.

## 3. Transport

- **HTTPS only.** Jellyfin is served over Tailscale HTTPS (`100.105.81.82:8921`) and via
  `watch.rumahadnan.online`. No public exposure beyond what Jellyfin already has.
- **HARDEN:** the iOS target ships `NSAllowsArbitraryLoads = true` (ATS off — allows
  cleartext HTTP). Once the Tailscale HTTPS URL is the canonical connection, set
  `NSAllowsArbitraryLoads = false` so the OS enforces TLS. (P1.)
- **Custom CA / client certs:** `flutter_user_certificates_android` + a client-cert
  installer are already present (supports mutual-TLS setups).

## 4. Session / logout

- Logout clears the stored `FinampUser` and calls `POST /Sessions/Logout` to invalidate
  the server session/token. ✅
- No server-side "session expiration" to manage (Jellyfin owns token expiry); the app
  handles `401` by surfacing a re-login flow.

## 5. CSRF / XSS / SSRF

- **CSRF:** N/A (no cookies/browser). ✅
- **XSS:** N/A (no DOM/HTML injection surface; Flutter renders native widgets, all text
  is escaped by construction). ✅
- **SSRF:** N/A (client-only; the only host it connects to is the user-entered server
  URL — validate scheme is `http(s)` and host is non-empty). ✅

## 6. Data boundaries

- Uses the Jellyfin API only. No Jellyfin DB, no media filesystem reads, no Flacky/
  Requests/other-container access. ✅
- Local data is limited to: token, settings, download index (Isar), artwork cache. No
  Jellyfin DB duplication. ✅

## 7. Privacy / telemetry

- No analytics, no cloud backup (`allowBackup=false`), no runtime permission prompts
  (no storage/media/camera/location). See PRIVACY.md. ✅

## 8. Logging

- `censored_log.dart` redacts secrets; verbose logging is opt-in and user-exportable.
  No tokens/paths/stack traces leak in normal operation. ✅ (audit the censored-log
  redaction list during hardening.)

## 9. Updates

- In-app self-updater verifies **SHA-256** of the APK against the release body before
  install (0.9.37). ✅

## 10. Secrets in the repo

- Keystore + `key.properties` are gitignored (local only). ✅
- **Residual risk:** git-pinned dependency forks (just_audio/media_kit/isar forks) —
  supply-chain audit is a P1 (see DEPENDENCIES.md).

---

## Security posture summary

| Requirement | Native-client equivalent | Status |
|---|---|---|
| Secure auth | Quick Connect / user-pass → token | ✅ |
| Token not in browser | No browser; token in app storage | 🟡 → Keychain (P0) |
| HTTPS | Tailscale HTTPS / domain TLS | 🟡 → disable ATS arbitrary-loads (P1) |
| HttpOnly/SameSite/CSRF | N/A (no cookies/browser) | ✅ N/A |
| Session expiration/logout | Jellyfin token expiry + logout | ✅ |
| Rate limiting | Jellyfin-side | ✅ N/A (client) |
| Input validation | search query → server-validated | ✅ |
| XSS / SSRF | N/A / scheme+host check | ✅ |
| Secret isolation | secure storage (after P0) | 🟡 |
| Safe logging | censored_log | ✅ |
| Body limits / timeouts | N/A (client) | ✅ |

**Bottom line:** the native model is *simpler and more secure* than the web model the
mission described — no cookie/CSRF/XSS surface at all. The two real work items are
**Keychain token storage** (P0) and **ATS tightening** (P1).

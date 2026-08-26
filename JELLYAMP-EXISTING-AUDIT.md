# JellyAmp — Existing Repository Audit (Phase 0)

**Repo:** `demongroker/jellyamp` · **Branch:** `features/share-seek-qol`
**Local:** `/home/adnan/finamp` · **Upstream:** `finamp-app/finamp` (`redesign`)
**Audit date:** 2026-08-17 · **Audit type:** read-only (no files modified)

---

## CURRENT STATE

| Dimension | Finding |
|---|---|
| Language / framework | Flutter (Dart SDK `>=3.7.0`), Material 3 |
| App version | `1.0.0+139` |
| Codebase size | 397 Dart files under `lib/`, ~50 l10n locales |
| State management | Riverpod (primary) + Provider + GetIt (DI) |
| HTTP / API | Chopper (code-generated Jellyfin client) |
| Local persistence | Hive CE (settings) + Isar (users, downloads, item types) |
| Playback engine | `just_audio` (fork) + `just_audio_media_kit` → **media_kit / libmpv** |
| Background playback | `audio_service` (Android + iOS lock-screen) |
| Offline | `background_downloader` (per-location, transcode-on-download) |
| Platforms | Android (primary), **iOS**, Linux, macOS, Windows — **no `web/` target** |
| Tests | **Zero unit/widget tests** (`test/` does not exist); one `integration_test/test_cases.dart` |
| CI | GitHub Actions builds arm64 APK, creates draft release (can't sign; keystore is local) |
| Deployment | None (pure client app — no Docker, no server component) |

**Networking:** the app is a pure client. It connects **directly** to a user-configured
Jellyfin URL (public address + local address + `preferLocalNetwork` toggle). No
intermediary server, no JellyAmp backend, no Caddy hop. Phone → Tailscale → Jellyfin HTTPS.

**Jellyfin target (live env):** version **10.11.11** (linuxserver), HTTP `:8097` /
HTTPS `:8921` bound to `127.0.0.1` + Tailscale `100.105.81.82` + LAN; public domain
`https://watch.rumahadnan.online`. Music library at `/media/music` (mounted
`/mnt/transcend/media` → `/media`).

---

## CURRENT SCORE

**8.5 / 10** as a codebase. The foundation is sound, the API layer is clean, the
playback engine is the right choice, and the feature set is far ahead of the v1
mission. Deductions are for the absence of tests, the un-hardened token storage,
the 1316-line `main.dart` bootstrap, and the un-audited git dependency forks.

---

## ESTIMATED % COMPLETE (vs the JellyAmp v1 mission)

- **Feature completeness: ~90–95%.** Nearly every v1 requirement already exists and
  works in production (see feature map below). The mission reads like a spec this
  app already satisfies.
- **"Shipped to iPhone" completeness: ~40–50%.** The iOS target is configured in code
  (background modes `audio`/`fetch`/`remote-notification`, CarPlay scene, Siri intents,
  AirPlay) but has **never been built or signed** — this host is Linux and cannot
  compile iOS. This is the real gap, and it is a *delivery* gap, not a *feature* gap.

---

## Feature map vs v1 mission

| v1 requirement | Status | Notes |
|---|---|---|
| Home (recent/added/favorites/resume/quick actions) | ✅ Done | configurable home sections + quick actions |
| Library (Artists/Albums/Songs/Genres/Playlists/Favorites) | ✅ Done | tabbed, per-tab sort/filter memory |
| Search (artists/albums/tracks) | ✅ Exceeds | unified grouped search + query syntax (`codec:flac`, `bit:24`, `year:`, `favorite:`) |
| Artist view (artwork, albums, tracks, play/shuffle/queue) | ✅ Done | |
| Album view (artwork, meta, tracklist, play/shuffle/next/queue) | ✅ Done | |
| Now Playing (play/pause/seek/prev/next/shuffle/repeat/queue/progress) | ✅ Done | + track-info sheet, seek gestures, sleep timer |
| Mini player (persistent, tap → full) | ✅ Done | `now_playing_bar.dart` |
| Queue (reorder/remove/play-next/clear) | ✅ Exceeds | + undo, "clear after current", saved/restorable queues |
| Playlists (browse/open/play/shuffle) | ✅ Exceeds | full mutation via Jellyfin API (create/rename/add/remove) |
| Favorites | ✅ Done | Jellyfin-native (`/Users/{id}/FavoriteItems`) |
| Playback + direct-play + FLAC | ✅ Done | media_kit decodes FLAC natively → direct play |
| Audio quality / lossless preservation | ✅ Exceeds | playback-mode chip (Direct Play / Direct Stream / Transcode), codec/bit/sample-rate |
| Gapless / audio session / lock-screen | ✅ Done | `audio_service` + just_audio gapless |
| Offline | ✅ Exceeds | already v1.5 — downloads, per-location, transcode-on-download |
| Caching (artwork/metadata) | ✅ Done | octo_image + flutter_cache_manager |
| Auth | ✅ Done | Quick Connect + username/password |
| Data boundaries (API-only, no DB/fs) | ✅ Done | Chopper client only |
| Performance (pagination/lazy/thumbnails) | ✅ Done | infinite_scroll_pagination, fast-scroll index |
| Mobile UX (iPhone-first, dark, safe-area) | ✅ Done | Finamp is mobile-first |
| Observability (/health) | N/A | client app — has logs screen + verbose logging instead |
| PWA | N/A | native app (see PWA-OFFLINE-ASSESSMENT.md) |

---

## KEEP

1. **Flutter + Riverpod/Provider/GetIt** — coherent, idiomatic.
2. **Chopper Jellyfin API layer** (`jellyfin_api.dart` + codegen) — clean, complete.
3. **Playback engine: just_audio + media_kit/libmpv** — the single most important
   correct choice: libmpv decodes FLAC/ALAC/AAC/MP3/Opus natively, so direct-play of
   the FLAC library works without server transcoding.
4. **audio_service** — background + lock-screen + Bluetooth/headphone controls.
5. **Isar/Hive** local persistence (downloads, settings, users).
6. **Offline/download subsystem** (`background_downloader`).
7. **The iOS target as already configured** (background modes, CarPlay, Siri, AirPlay).
8. **The entire shipped feature set** (Home/library/search/queue/playlists/favorites/player).

## FIX

- *(No known active regressions.)* Roadmap P1 items that are small, bounded fixes:
  `main.dart` refactor (see REDESIGN), advanced-filtering UI, multi-select.

## HARDEN

1. **Token storage** — move `FinampUser.accessToken` out of Isar into
   `flutter_secure_storage` (iOS Keychain / Android Keystore). Currently plaintext in
   app-private DB. (P0 before shipping.)
2. **Tests** — there are zero. Add unit tests for models/search-syntax/aggregation
   and a widget smoke test for the player/queue. (P0 before freeze.)
3. **Dependency-fork audit** — many `git:` deps pinned to SHAs (just_audio fork,
   media_kit fork, isar fork, etc.). Complete `DEPENDENCIES.md` with reason + upstream
   issue + exit condition for each. (P1.)
4. **Self-updater** — already SHA-256 hardened (0.9.37); keep.

## REDESIGN

- **`main.dart` (1316 lines)** — collapse the bootstrap into a boring `bootstrap()` +
  `runApp`. Already on the roadmap (P1 #15). The only "redesign" candidate; not urgent.

## REMOVE

- **Desktop-only extras** (low priority, not blocking): Discord RPC
  (`flutter_discord_rpc`), Windows SMTC/MSIX, Linux MPRIS/DBus — irrelevant to iPhone,
  keep only if desktop remains a target.
- **~50 l10n locales** — harmless bloat; can trim later.

## MISSING (vs v1 mission)

1. **iOS build + signing + distribution pipeline.** THE gap. Requires macOS (Xcode) or
   a macOS CI runner + an Apple Developer account + a distribution method (TestFlight,
   or sideload). Cannot be produced on this Linux box. (P0.)
2. Nothing else feature-wise — the mission is ~90% present in code.

---

## P0 / P1 / P2

- **P0**
  1. iOS build/signing/distribution path (macOS CI + Apple account decision).
  2. Secure token storage (Keychain/Keystore).
  3. Baseline test suite.
- **P1**
  4. `main.dart` refactor.
  5. Dependency-fork audit + `DEPENDENCIES.md`.
  6. Advanced filtering UI (already planned).
- **P2**
  7. Desktop-extras cleanup.
  8. Settings search, multi-select, compact density (already planned).

---

## Shortest safe path (existing → v1 product)

1. **Keep the code.** No rewrite.
2. **Harden the three P0s** (token storage, tests, iOS delivery).
3. **Stand up iOS delivery** (macOS CI runner or a Mac, Apple account, TestFlight).
4. **Freeze** once iPhone build is proven end-to-end (login → browse → play FLAC →
   lock-screen control → offline download).

**Estimated % complete: ~90% (features) / ~45% (end-to-end iPhone delivery).**

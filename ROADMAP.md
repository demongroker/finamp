# Jellyamp — Roadmap

**Jellyamp is the power-user Jellyfin music client.** A fork of Finamp that wins on
playback transparency, library control, queue/session control, offline control,
lossless/audio-quality visibility, fast self-hosted workflows, and privacy.

Repo: https://github.com/demongroker/jellyamp · Branch: `features/share-seek-qol`
Upstream: [finamp-app/finamp](https://github.com/finamp-app/finamp) (`redesign`)

---

## Product principle

- Simple when you just want to play music.
- Powerful when you want control.
- Transparent when something technical happens.
- Private by default.
- Fast no matter how big the library gets.

## Positioning

| | |
|---|---|
| **Finamp** | excellent *general* Jellyfin music player |
| **Jellyamp** | excellent *power-user* Jellyfin music player |

Jellyamp should win on: (1) playback transparency, (2) library control,
(3) queue/session control, (4) offline control, (5) lossless/audio-quality
visibility, (6) fast self-hosted workflows, (7) privacy.

---

## Current phase — CORE HARDENING ✅ shipped in 1.0.0 (audit #3, 2026-08-16)

All P0 core-hardening items are done and released in **1.0.0**: secure
self-updater (SHA-256 + exact asset), `downloaded:` filter, search correctness
(debounce / stale-cancel / limits), album quality semantics, and transcoding
explanation. Remaining P1 work — advanced filtering UI, `main.dart` refactor,
dependency-fork audit — targets **1.1**.

## P0 — do next (this cycle)

1. **Secure APK update verification** — publish a SHA-256 checksum with each
   release; the updater downloads → verifies checksum → confirms it's a Jellyamp
   release APK → only then installs. On failure: "Delete / Open Release Page",
   never install.
2. **Exact APK asset selection** — no "first `*.apk`" matching; select by an
   explicit release contract (exact filename, or ABI-matched signed release APK).
   Human-readable update errors (Retry / Release Page; details behind a fold).
3. **Finish `downloaded:` search filter** — implement `downloaded:true/false`
   (needs the Isar download store), or return "not supported yet" instead of
   silently accepting a no-op filter.
4. **Search correctness** — debounce (~250–400 ms) + stale-request cancellation
   (a slow old query must never overwrite a newer one); limit grouped results
   with "View all N →"; define album quality semantics (an album matches
   `bit:24` / `codec:flac` only when **ALL** its tracks match).
5. **Advanced filtering** — Codec / Bitrate / Lossless / Hi-Res / Year /
   Downloaded / Favorite / Played (filtering > more sort options).
6. **Download manager reliability + polish** — trustworthy subsystem: storage/
   counts, Active / Downloaded / Failed, Pause/Resume All, Retry Failed; explicit
   **Downloaded vs Cached** distinction.
7. **Queue / listening sessions** — saved queues (name → restore / shuffle /
   rename / delete / save-as-Jellyfin-playlist) + session history.
8. **Transcoding explanation** — "why" + source→output chain (FLAC 24/96 → AAC 256).
9. **Performance on huge libraries** — 10k–100k tracks: cold launch, list load,
   search latency, scroll FPS, offline startup.

## P1

8. Multi-select (bulk download / favorite / queue / playlist)
9. Compact + ultra-compact library density modes
10. Remember view / filter / sort / scroll state everywhere
11. Offline-first search (search downloaded content while offline)
12. Smart Downloads (keep latest N albums, sync favorites, auto-download, expiry)
13. Settings search
14. Repo structure: rename active branch → `main`, track `upstream/redesign`; issues + labels
15. Refactor `main.dart` (55 KB → a boring `bootstrap()` + `runApp` entry point)
16. Audit git dependency forks — expand `DEPENDENCIES.md` (reason, pinned commit, upstream issue, exit condition)

## P2

16. Rediscover / Forgotten Music (not-played-in-a-year, favorites not played recently, never-played)
17. Audio-quality library views (Lossless / Hi-Res / 24-bit / 96 kHz+)
18. Expert Mode (progressive disclosure: technical info, codec badges, advanced filters, diagnostics)
19. Android Auto
20. Server profiles (multi-server)
21. Custom gesture timings
22. Library health (missing artwork / unknown year / duplicates)

## P3 — deliberately low priority

23. More animations · 24. More themes · 25. More sharing features · 26. More Home quick actions

---

## NOT planned (keeps the product clear)

- Spotify / YouTube Music integration
- Music discovery cloud backend / AI DJ / chat assistant
- Social accounts, followers, public profiles
- Server administration, Docker controls, DNS/VPN management
- Ads, cloud accounts

---

## Identity guardrails

- **Stay close to upstream on** the playback engine, download internals, and the
  Jellyfin API layer — deep divergence there means painful future merges.
  Fork-specific work stays at the UI / product layer.
- **Label every change** Upstreamable / Jellyamp-specific / Experimental.
- **Privacy is the brand:** no analytics, no telemetry, no cloud backup, no
  runtime permission prompts, app-private downloads.
  > *Your music. Your server. No tracking.*

## Merge discipline

- Kotlin namespace `com.unicornsonlsd.finamp` is tracked technical debt — do **not**
  half-rename it piecemeal. Either keep it intentionally, or do one controlled migration.

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

## P0 — do next (this cycle)

1. **Powerful unified search** — one box searches artists / albums / tracks /
   playlists / genres, results grouped by type, plus optional query syntax
   (`artist:metallica`, `album:master of puppets`, `year:1986` or `year:1983-1991`,
   `genre:metal`, `codec:flac`, `favorite:true`, `downloaded:true`).
2. **Advanced filtering** — Downloaded / Favorite / Played / Never Played /
   Genre / Year / Album Artist / Codec / Bitrate / Lossless / Hi-Res.
   *Filtering is more important than more sort options.*
3. **Download manager reliability + polish** — a trustworthy subsystem:
   storage used, track/album counts, Active / Downloaded / Failed sections,
   Pause All / Resume All / Retry Failed, per-item progress + quality + size +
   error reason. Explicit **Downloaded vs Cached** distinction.
4. **Transcoding explanation** — when the player says *Transcoding*, show **why**
   (mobile bitrate limit / unsupported codec / user-selected quality) and the
   source → output chain (e.g. `FLAC 24/96 → AAC 256 kbps`).
5. **Queue / listening sessions** — evolve the existing *Recent Queues* into
   restore-able sessions (restore / save as playlist / shuffle / delete).
   Save queue as playlist.
6. **Performance on huge libraries** — deliberately test 10k / 50k / 100k tracks:
   cold launch, list load, search latency, scroll FPS, artwork load, 1k-track
   queue, offline startup.
7. **Stabilize releases + regression testing** — slow the cadence; add regression
   checks before each release.

## P1

8. Multi-select (bulk download / favorite / queue / playlist)
9. Compact + ultra-compact library density modes
10. Remember view / filter / sort / scroll state everywhere
11. Offline-first search (search downloaded content while offline)
12. Smart Downloads (keep latest N albums, sync favorites, auto-download, expiry)
13. Settings search
14. Update integrity verification (SHA-256 checksum before install)
15. Repo structure: rename active branch → `main`, track `upstream/redesign`; issues + labels

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

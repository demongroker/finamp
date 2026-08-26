# JellyAmp — v1 Scope

**Baseline:** the existing `demongroker/jellyamp` codebase (v1.0.0+139). v1 = get this
app **shipped and proven on iPhone**, with the three P0 hardening items done. No new
feature work is required to meet the mission — the features already exist.

---

## In v1 (already built — verify + ship)

| Area | Content |
|---|---|
| Home | Recently played, newly added, favorite albums, recent queues, quick actions (shuffle / previous queue / surprise me) |
| Library | Artists, Albums, Tracks, Genres, Playlists, Favorites (tabs, per-tab sort/filter memory) |
| Search | Unified search across artists/albums/tracks/playlists/genres + query syntax |
| Artist view | Artwork, metadata, albums, tracks; Play / Shuffle / Add to queue |
| Album view | Artwork, title/artist/year, metadata, tracklist + durations; Play / Shuffle / Play next / Add to queue |
| Now Playing | Artwork-first; play/pause/seek/prev/next/shuffle/repeat/queue/volume/progress; elapsed + remaining |
| Mini player | Persistent; artwork/track/artist/play-pause/next; tap → full player |
| Queue | Reorder, remove (undo), play next, add to queue, clear, "clear after current", saved/restorable queues |
| Playlists | Browse/open/play/shuffle + create/rename/add/remove (Jellyfin-native) |
| Favorites | Jellyfin-native favorite toggle + favorite filters |
| Playback | Direct play (FLAC lossless), opt-in transcode, playback-mode chip, gapless |
| Offline | Downloads, per-location, transcode-on-download, offline mode (already exceeds v1) |
| Auth | Quick Connect + username/password |

## New in v1 (the actual work — hardening + delivery)

1. **Secure token storage** — Keychain (iOS) / Keystore (Android) via `flutter_secure_storage`.
2. **Baseline test suite** — unit tests (models, search syntax, queue aggregation) + a
   player/queue widget smoke test.
3. **iOS build + signing + distribution** — macOS build path, Apple Developer account,
   TestFlight (or sideload) — prove login → browse → play FLAC → lock-screen control →
   offline download on a real iPhone.
4. **`main.dart` refactor** (1316 → a clean `bootstrap()` + `runApp`) — optional for v1,
   can land in v1.1 if it risks the iOS milestone.

## Explicitly out of v1 (defer, do not build now)

- PWA / web target (see PWA-OFFLINE-ASSESSMENT.md — not recommended).
- Advanced filtering UI, multi-select, compact density, settings search (roadmap P1/P2).
- Android Auto, "Smart Downloads", audio-quality library views, Expert Mode (roadmap P2).
- Any new discovery/analytics/cloud/backend (explicitly NOT planned per ROADMAP.md).
- Desktop-extras cleanup (Discord RPC, Windows SMTC) — non-blocking.

## Definition of done (v1)

The app runs on the user's iPhone over Tailscale HTTPS against the live Jellyfin,
FLAC direct-plays losslessly, lock-screen controls work, offline download works, token
is in the Keychain, and the baseline test suite passes. JellyAmp is then frozen like
Requests — only bugs/security/maintenance thereafter.

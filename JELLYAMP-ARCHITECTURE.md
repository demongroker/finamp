# JellyAmp — Architecture

**Decision:** KEEP the existing `demongroker/jellyamp` Flutter codebase. Do not rewrite.
This document describes the architecture as it exists (verified) and the target v1 state.

---

## 1. Shape of the system

JellyAmp is a **pure client application**. There is no JellyAmp server, no database,
no cache daemon, no message queue. It is a native Flutter app that talks directly to
Jellyfin over HTTPS.

```
┌────────────┐   HTTPS (Tailscale)   ┌──────────────┐
│  iPhone    │ ──────────────────────▶│   Jellyfin   │
│  (Flutter  │                       │ 10.11.11     │
│   native)  │ ◀─────────────────────│  /media/music│
└────────────┘                       └──────────────┘
```

**Important implication vs the mission's network diagram:** the mission specified
`PHONE → TAILSCALE → HTTPS → CADDY → JELLYAMP → JELLYFIN`. That shape assumes a *web*
app with a server backend. A native app needs **no Caddy hop and no JellyAmp server** —
the phone reaches Jellyfin directly. This is simpler, lower-latency for audio, and
matches the "START SIMPLE / no microservices" rule. The existing Caddy gateway
(`adnan.tailcf4796.ts.net`) is unchanged and untouched; Jellyfin is already reachable
over Tailscale at `100.105.81.82:8921` (HTTPS) and via `watch.rumahadnan.online`.

## 2. Layering (in-code)

```
lib/
├── main.dart                      # bootstrap (to be refactored)
├── models/                        # jellyfin_models (DTOs), finamp_models (Isar/Hive), search_models
├── services/                      # the app's brain
│   ├── jellyfin_api.dart          # Chopper client — every Jellyfin endpoint the app calls
│   ├── jellyfin_api_helper.dart   # auth header, URL builders, higher-level API ops
│   ├── queue_service.dart         # queue state + playback orchestration
│   ├── music_player_background_task.dart  # audio_service handler (background/lock-screen)
│   ├── data_source_service.dart   # direct-play vs transcode vs offline switching
│   ├── downloads_service*.dart    # offline downloads (background_downloader)
│   ├── music_providers.dart       # search / library providers
│   ├── favorite_provider.dart     # favorites
│   ├── playback_history_service.dart  # play history + Jellyfin progress reporting
│   └── ...                        # settings, theme, update checker, etc.
├── components/                    # UI (screens + reusable widgets)
├── screens/                       # top-level routes
└── menus/                         # context menus (play/shuffle/queue/favorite/playlist…)
```

## 3. Data flow

- **Library browse/search** → Riverpod providers → `jellyfin_api_helper` → Chopper →
  Jellyfin. Results are paginated (`infinite_scroll_pagination`), artwork via
  `octo_image` + `flutter_cache_manager` (cached on-device).
- **Playback** → `queue_service` builds a playable slice → `music_player_background_task`
  (audio_service) → `just_audio` (media_kit/libmpv) fetches the stream URL → plays.
- **Direct play** (default): the media source's original URL (`/Items/{id}/File` or the
  PlaybackInfo-derived source URL) is handed to libmpv, which decodes FLAC/ALAC/AAC/MP3/
  Opus natively.
- **Transcode** (opt-in): `/Audio/{id}/Universal` with `audioCodec`/`container`/
  `audioBitRate`/`sampleRate`/`maxAudioChannels` query params.
- **Offline** (opt-in): `background_downloader` writes app-private files; the data source
  switches to local files in offline mode.
- **Playback reporting** → `Sessions/Playing` + `Sessions/Playing/Progress` +
  `Sessions/Playing/Stopped` (progress) and local `playback_history_service`.

## 4. State of truth

- **Jellyfin is the source of truth** for music/artists/albums/metadata/playlists/
  favorites/play-history. JellyAmp holds only *derived* local state: auth token,
  settings, download index (Isar), and cache.
- **No direct Jellyfin DB / filesystem / Flacky / Requests access** — API only. Verified:
  the client uses only Chopper HTTP calls; no `sqlite`, no media-path reads, no other
  container's API.

## 5. Auth

- Login via **Quick Connect** (`/QuickConnect/Initiate` → `/Users/AuthenticateWithQuickConnect`)
  or username/password (`/Users/AuthenticateByName`).
- Resulting `AccessToken` + `UserId` stored in a `FinampUser` Isar record; an
  `X-Emby-Authorization` header (`Client="Jellyamp", Device, DeviceId, Version, UserId, Token`)
  is attached to every request.
- See SECURITY-MODEL.md for the token-storage hardening recommendation.

## 6. Playback engine (why it's right)

media_kit/libmpv (MPV) is a native media framework that decodes **FLAC, ALAC, AAC, MP3,
Opus, WAV, DSD** and more in-process — so the FLAC library direct-plays with no server
transcode. This is the key reason the native app is superior to a browser/PWA for this
library: a browser `<audio>` cannot decode FLAC (see PLAYBACK-ARCHITECTURE.md).

## 7. What does NOT change

- No new server, no Caddy changes (Xerxes III's gateway untouched), no new ports, no
  Docker image, no Redis/queue/metadata-db, no transcoder, no streaming protocol.
- Jellyfin, Flacky, Telenovela, Requests, Command Center: untouched (read-only audit).

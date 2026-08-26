# JellyAmp — Jellyfin Capability Matrix

**Target:** live Jellyfin **10.11.11** (linuxserver) on the OptiPlex, reachable at
`127.0.0.1:8097` / Tailscale `100.105.81.82:8921` (HTTPS) / `watch.rumahadnan.online`.

**Evidence basis:** (1) the production `jellyfin_api.dart` in the Finamp fork — every
endpoint below is actually called by the app against this exact server version and
works in production; (2) `GET /System/Info/Public` confirmed `Version: 10.11.11`.

**Key:** ✅ SUPPORTED · 🟡 PARTIAL · ❌ UNSUPPORTED · ❓ UNKNOWN

---

| Capability | Status | Endpoint(s) / evidence |
|---|---|---|
| Public server info | ✅ | `GET /System/Info/Public` → `{Version:"10.11.11"}` (verified live) |
| Public user list | ✅ | `GET /Users/Public` |
| Username/password auth | ✅ | `POST /Users/AuthenticateByName` |
| Quick Connect | ✅ | `GET /QuickConnect/Enabled`, `POST /QuickConnect/Initiate`, `GET /QuickConnect/Connect`, `POST /Users/AuthenticateWithQuickConnect` |
| Library views / tabs | ✅ | `GET /Users/{id}/Views` |
| Item browse (artists/albums/tracks) | ✅ | `GET /Users/{userId}/Items` (IncludeItemTypes, Recursive, SortBy, Filters, searchTerm, Fields) |
| Recently added | ✅ | `GET /Users/{userId}/Items/Latest` |
| Item detail | ✅ | `GET /Users/{userId}/Items/{itemId}` |
| Artists | ✅ | `GET /Artists`, `GET /Artists/AlbumArtists` |
| Genres | ✅ | `GET /Genres` |
| Search | ✅ | via `GET /Users/{userId}/Items?searchTerm=` (the app's unified search) |
| Artwork | ✅ | `GET /Items/{id}/Images/Primary` (+ `MaxWidth`/`MaxHeight`/`quality`/`format`) |
| User image | ✅ | `GET /Users/{id}/Images/Primary` (URL builder) |
| Favorites (read + toggle) | ✅ | `POST`/`DELETE /Users/{userId}/FavoriteItems/{itemId}`; `filters=IsFavorite` |
| Playlists (list/open) | ✅ | `GET /Playlists/{id}`, `GET /Playlists/{id}/Items` |
| Playlists (create) | ✅ | `POST /Playlists` |
| Playlists (add/remove) | ✅ | `POST`/`DELETE /Playlists/{id}/Items` |
| Playlists (rename/update) | ✅ | `POST /Playlists/{id}` |
| Playlist permissions | ✅ | `GET /Playlists/{id}/Users`, `GET /Playlists/{id}/Users/{userId}` |
| Playback info / media sources | ✅ | `GET /Items/{id}/PlaybackInfo` (drives direct-play + codec visibility) |
| Direct-play stream | ✅ | media source URL / `GET /Items/{id}/File` (handed to libmpv) |
| Transcode stream | ✅ | `GET /Audio/{id}/Universal?audioCodec=&container=&audioBitRate=&sampleRate=&maxAudioChannels=` (URL builder in `jellyfin_api_helper.dart`) |
| Report capabilities | ✅ | `POST /Sessions/Capabilities`, `POST /Sessions/Capabilities/Full` |
| Playback progress reporting | ✅ | `POST /Sessions/Playing`, `POST /Sessions/Playing/Progress`, `POST /Sessions/Playing/Stopped` |
| Play history (played items) | ✅ | via `GET /Users/{id}/Items?Filters=IsPlayed` + local `playback_history_service` |
| Lyrics | ✅ | `GET /Audio/{itemId}/Lyrics` |
| Instant mix / radio | ✅ | `GET /Items/{id}/InstantMix` |
| Edit metadata / delete item (admin) | ✅ | `POST /Items/{itemId}`, `DELETE /Items/{id}` (present; admin-only, not core) |
| Server endpoint discovery | ✅ | `GET /System/Endpoint` |
| Logout | ✅ | `POST /Sessions/Logout` |
| HLS audio (`main.m3u8`) | 🟡 | available in 10.11 but the app does not use HLS for audio (uses direct file / Universal stream) |
| Gapless | ✅ | client-side (just_audio gapless); no special Jellyfin support needed for direct-play |
| Media Session API | ❌ | not a Jellyfin feature — browser concern; native app uses audio_service/MPRemoteCommandCenter instead |
| Offline storage API | ❌ | not a Jellyfin feature — handled by `background_downloader` on the client |

---

## Notes / version gotchas

- The app intentionally uses `GET /Users/{id}/Items?searchTerm=` for search (not
  `/Search/Hints`) — returns full typed results for grouped search; no separate hints call.
- `getItems` must pass an explicit `Fields=` string including `MediaSources` and
  `ProductionYear`, otherwise codec/bit/year filters silently match nothing (documented
  in the fork; fixed in 1.0.0).
- Media codec/bitDepth/sampleRate live in `mediaSources[].mediaStreams[]`
  (`type=="Audio"`), not on the top-level `BaseItemDto` — the app reads them there for
  the playback-mode chip and search filters.
- All mutation endpoints above (favorites, playlists) are already exercised by the
  production app — no workaround or adapter needed for v1.

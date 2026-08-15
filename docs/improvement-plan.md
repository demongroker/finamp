# JellyAmp — Product Improvement Plan

Source: power-user review (2026-08-15) + library-browsing review (2026-08-15)
Repo: https://github.com/demongroker/jellyamp · Branch: `features/share-seek-qol`

## Implemented now (this pass)

### 0. Fixed pre-existing build blockers (were breaking every release build)
- `lib/services/media_share_helper.dart` — `static` modifier on a top-level function (compile error) → removed
- `pubspec.yaml` — SDK constraint `>=3.6.0` pinned language level below the Dart 3.7+ wildcard `_` params used throughout upstream code → bumped to `>=3.7.0 <4.0.0`
- Verified: `flutter build apk --release` now succeeds (was failing on ~10 compile errors)

### 1. Track Info sheet + Direct Play / Direct Stream / Transcoding clarity (Review §4, §7, §17 — their P0 #3)
- **New:** `lib/components/PlayerScreen/track_info_sheet.dart` — tap the **Playback Mode chip** on Now Playing to open a technical sheet: playback mode, codec, bitrate, bit depth, sample rate, channels, container, file size, path, server name.
- **Fixed the upstream TODO** (`feature_chips.dart`): Now Playing chip now distinguishes **Direct Streaming** (container remux, no transcode) from **Direct Playing** using `MediaSourceInfo.supportsDirectPlay/supportsDirectStream`, instead of labeling everything "Direct Playing".
- 6 new l10n keys (`playbackModeDirectStreaming`, `channels`, `container`, `fileSize`, `path`, `server`).

### 2. Year + Rating sort options (Review 1 / §4)
- Exposed `SortBy.productionYear` (Year) and `SortBy.communityRating` (Rating) in the Albums and Tracks sort menus (`jellyfin_models.dart` `defaultsFor`). Sort logic + Jellyfin API mapping already existed — only the menu exposure was missing.
- Per-view sort memory already exists (tracking controllers persist `tabSortBy`/`tabSortOrder` per content type).

## Already satisfied by the fork (no work needed)
- Alphabetical fast-scroll bar ✓ (keep)
- Sort: Title/Artist/AlbumArtist/Date Added/Release Date/Play Count/Last Played/Duration/Random ✓
- Filter: Favorite, Downloaded, Unplayed, Genre, Artist ✓
- Ascending/Descending toggle + per-view persistence ✓
- Dark interface, Offline Mode, Previous Queue, Surprise Me, queue management basics ✓

## Future roadmap (noted, not built — from the review)

### P0 — next candidates
- **Queue management upgrade** (§8): drag-to-reorder, swipe-to-remove, Add Next/Play Next, Clear After Current, Shuffle Remaining, Remove Duplicates, Save Queue as Playlist, **UNDO after destructive actions**
- **Queue history expansion** (§9): Previous Queue → proper queue history with timestamps + restore
- **Search grouping** (§5): results grouped ARTISTS / ALBUMS / TRACKS / PLAYLISTS

### P1
- **Customizable Home** (§1): reorder/hide sections, density, "Edit Home" entry point — note: `HomeScreenConfiguration` + `_migrateHomescreen()` already exist in this fork
- **Download Manager** (§10): pause/resume/retry/failed, storage usage, Downloaded vs Cached distinction
- **Compact/Comfortable density modes** (§6)
- **Navigation cleanup** (§2, §3): drawer reorg (Logs → Settings → Advanced → Diagnostics), rename "Restore Now Playing" → "Restore Previous Session"
- **Multi-select** (§15) + richer context menus (§16)
- **Error states** (§19): Jellyfin unreachable / auth expired / download failed / playback failed

### P2
- Smart Downloads (§11), Command Palette (§14), Advanced search syntax (§5), Track info already done (§17), Surprise Me discovery (§13), Settings search (§21)

### P3
- Animations, micro-interactions, cosmetic polish (§23 progressive disclosure principle applies to all of the above)

## Design principle (from review)
Simple on the surface, extremely powerful underneath. Five core flows to perfect: LIBRARY → SEARCH → QUEUE → PLAYBACK → OFFLINE. Progressive disclosure: normal interface simple, power features behind long-press / More / Advanced.

## Files changed this pass
- [CREATED] `lib/components/PlayerScreen/track_info_sheet.dart`
- [MODIFIED] `lib/components/PlayerScreen/feature_chips.dart` (Direct Stream distinction + tappable chip)
- [MODIFIED] `lib/models/jellyfin_models.dart` (Year/Rating sort options)
- [MODIFIED] `lib/l10n/app_en.arb` (+6 keys)
- [MODIFIED] `lib/services/media_share_helper.dart` (build fix: stray `static`)
- [MODIFIED] `pubspec.yaml` (build fix: SDK floor 3.7.0)
- [CREATED] `docs/reviews-collected.md` (raw reviews)
- [CREATED] `docs/improvement-plan.md` (this plan)

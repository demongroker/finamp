# JellyAmp — Mobile UX

**Assessment:** the existing Finamp-based app is already iPhone-first. This document
maps the mission's UX requirements to what exists, and notes the (few) gaps.

---

## Navigation model

- **Bottom tab bar:** Home · Albums · Artists · Playlists · Tracks (Genres off by
  default, toggleable). One-hand reachable.
- **Push navigation** into Artist / Album / Player / Playlist / Settings screens.
- **Persistent mini player** (`now_playing_bar.dart`) sits above the tab bar on every
  tab; tap → full Now Playing.

## Screen-by-screen

- **Home** — quick-action row (Shuffle · Previous queue · Surprise me) + configurable
  sections (Recently played, Newly added albums, Favorite albums, Recent queues). Sparse
  by default, user-editable. ✅
- **Library** — tabbed, each tab with a **sort/filter row that remembers its own
  state** (Albums vs Artists vs Tracks keep separate sort/filter), alphabetical
  **fast-scroll** index, infinite-scroll pagination. ✅
- **Search** — unified grouped search (Artists/Albums/Tracks/Playlists/Genres) with a
  "View all N" expander, plus a query syntax (`codec:flac`, `bit:24`, `year:1986`,
  `favorite:true`). Debounced + stale-cancelled. ✅
- **Artist view** — artwork header, metadata, Albums + Tracks; Play / Shuffle /
  Add-to-queue. ✅
- **Album view** — large artwork flexible-space header, title/artist/year/metadata,
  tracklist with durations; Play / Shuffle / Play next / Add to queue. ✅
- **Now Playing** — artwork-first; play/pause/seek/prev/next/shuffle/repeat/queue/
  volume; elapsed + remaining; **feature chips** (playback mode: Direct Play / Direct
  Stream / Transcode, codec, bitrate, bit depth, sample rate); tap chip → **track info
  sheet** (codec, container, size, path, server); long-press/double-tap **seek gestures**;
  sleep timer. ✅ — feels like a real mobile music player.
- **Queue** — reorder, remove (with **undo**), "clear after current", add-next/add-to-
  queue, **saved/restorable queues**. ✅
- **Playlists** — browse/open/play/shuffle; edit (add/remove/reorder), create, rename. ✅

## iPhone-specific (already configured)

- **Background + lock-screen controls** — `UIBackgroundModes` = `audio` (+fetch,
  remote-notification) via audio_service → MPRemoteCommandCenter + MPNowPlayingInfoCenter.
- **CarPlay** — `flutter_carplay` scene delegate configured.
- **Siri** — `INPlayMediaIntent` + `INSearchForMediaIntent`.
- **AirPlay** — `flutter_to_airplay`.
- **Safe area / notch** — handled by Flutter natively.
- **Dark mode** — default dark + **AMOLED** + accent picker + dynamic color; ice-glass
  theme (charcoal base, ice-cyan accent).

## Mission UX rules vs reality

- Large touch targets ✅ (Material + CTA button variants).
- One-hand navigation ✅ (bottom tabs, bottom-sheet menus).
- Fast transitions ✅ (native Flutter).
- Minimal text / artwork-forward ✅.
- Persistent playback controls ✅ (mini player + lock-screen).
- Safe-area support ✅.
- Dark-mode friendly ✅ (default).
- Excellent scrolling ✅ (fast-scroll index, sticky headers, pagination).
- Avoids admin-dashboard look ✅ (it is a consumer music UI).

## Gaps (minor)

- **Volume on the Now Playing screen** — handled via OS hardware volume; no on-screen
  volume slider (matches native music-app convention; acceptable).
- **On-screen safe-area on desktop** — N/A for iPhone.

**Bottom line:** no UX redesign needed. The v1 UX requirement is already met; the only
work is iPhone *delivery* (build/sign/install), not UX construction.

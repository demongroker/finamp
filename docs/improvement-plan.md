# JellyAmp — Product Improvement Plan

Source: power-user reviews + repo audits (2026-08-15 first pass; 2026-08-16 corrected second audit).
Repo: https://github.com/demongroker/jellyamp · Branch: `features/share-seek-qol`
Canonical priorities now live in [ROADMAP.md](../ROADMAP.md) — this file records the
correction of the first audit and the current build focus.

## Audit correction (2026-08-16) — features already shipped, DO NOT re-propose

The first audit listed these as missing; the second audit confirmed they are **already implemented**:

- Direct Play / Direct Streaming / Transcoding visibility + technical track info sheet
- Queue: drag/reorder, swipe-to-remove, Play Next / Add Next, Undo, Clear After Current
- Sort by Year and Rating (with per-view memory)
- Clean default Home (intentionally sparse)
- In-app updates, update notification, in-app release notes
- Remember last Jellyfin server
- Share original FLAC, share/copy links, copy "Artist — Title"
- Long-press seek, double-tap album-art controls
- Share APK + Wi-Fi APK serving
- Offline downloads, gapless, ReplayGain/normalization, lyrics, dynamic colors,
  favorites, playlists, Radio/Instant Mix, playback reporting

## The actual problem (from the corrected audit)

Jellyamp is currently **Finamp + Jellyamp brand + QoL patches** — useful, but not yet a
separate identity. The strongest differentiators so far are sharing, seek gestures, the
clean Home, visual identity, and APK self-update.

**Direction change:** stop asking "what cool feature next?" — instead perfect the
**five workflows** that make Jellyamp worth choosing over Finamp:

1. Find music → 2. Start playback → 3. Manage queue → 4. Inspect playback quality → 5. Use music offline

## Current build focus (P0 — do next)

1. **Powerful unified search** — grouped results (artists/albums/tracks/playlists/genres) + query syntax
2. **Advanced filtering** — Downloaded/Favorite/Played/Genre/Year/Album Artist/Codec/Bitrate/Lossless/Hi-Res
3. **Download manager reliability + polish** — trustworthy subsystem, Downloaded vs Cached distinction
4. **Transcoding explanation** — "why" + source→output chain
5. **Queue / listening sessions** — restore-able sessions, save queue as playlist
6. **Performance on huge libraries** (10k–100k tracks)
7. **Stabilize releases + regression testing**

See ROADMAP.md for P1 / P2 / P3 and the NOT-planned list.

## Design principle (unchanged)

Simple on the surface, extremely powerful underneath. Five core flows:
LIBRARY → SEARCH → QUEUE → PLAYBACK → OFFLINE. Progressive disclosure:
normal interface simple; power features behind long-press / More / Advanced.

## Files changed this pass (2026-08-16 — governance, no code)

- [CREATED] `ROADMAP.md` — identity + P0–P3 priorities + NOT-planned guardrails
- [CREATED] `CHANGELOG.md` — release history grouped Added/Changed/Fixed/Security
- [MODIFIED] `docs/improvement-plan.md` — this corrected plan

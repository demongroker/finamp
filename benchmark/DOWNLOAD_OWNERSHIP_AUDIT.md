# JellyAmp — Download Ownership Audit (P0.2 step 5)

Status: AUDIT COMPLETE (step 5a) + minimal ownership guard implemented (step 5b).
Date: 2026-08-18 · Branch: features/jellyamp-1.1

This document maps the entire download/cache subsystem: every creation path,
every removal/eviction/cleanup path, the on-disk layout, and — the point of
step 5 — which automatic cleanup paths can **silently remove explicit user
downloads**. It records the DOWNLOADED-vs-CACHED gap and the minimal, migration-
safe guard added to close it.

---

## 1. Ownership model today (the gap)

The roadmap rule is `DOWNLOADED != CACHED`: an explicit user download is
persistent, user-owned, offline content that cache cleanup must NEVER silently
remove. The current subsystem has **no explicit persisted ownership flag**.
There is one *implicit* signal:

- `DownloadItem.userTranscodingProfile != null` is set **only** on the node the
  user explicitly downloaded (`addDownload`, `downloads_service.dart:454`) and
  cleared on explicit removal (`downloads_service.dart:484`). It is the app's
  only notion of "user downloaded this".
- All descendants (tracks, images, sub-collections) carry only
  `syncTranscodingProfile`, which is derived from parents during sync
  (`downloads_service.dart:1008`, `backend:1157-1161`).

Because the marker lives only on the top-level node, a track inside a
user-downloaded album has `userTranscodingProfile == null`, so the distinction
is not directly queryable per-file. Nothing currently gates any removal path on
ownership.

`userTranscodingProfile` survives for existing 1.0 installs (it is written by
`addDownload` and restored by hive migration at `downloads_service.dart:1246`),
so it is a safe, migration-free ownership signal to enforce against.

---

## 2. Creation paths (who writes DownloadItem rows / download state)

| # | Path | Location | Notes |
|---|------|----------|-------|
| C1 | `addDownload` (explicit user Download) | `downloads_service.dart:438-465` | `userTranscodingProfile = transcodeProfile` (454), upsert item (455), anchor link (459), then `resync`. This is the ONLY path that sets the ownership marker. |
| C2 | `addDefaultPlaylistInfoDownload` (auto metadata) | `downloads_service.dart:1280-1295` | Auto-downloads the `allPlaylistsMetadata` finampCollection via `addDownload` (1288). Technically auto, but goes through the user path (no files itself). |
| C3 | Hive→Isar migration | `migrateFromHive` 1067, `_migrateImages` 1105, `_migrateTracks` 1156, `_migrateParents` 1224 | Recreates DownloadItems for legacy 1.0 downloads; sets `userTranscodingProfile` on parents (1246). Then runs `repairAllDownloads` (1089). |
| C4 | `_syncDownload` → `_updateChildren` (graph expansion) | `backend:850-1179`, `_updateChildren` `1189-1227` | Inserts new track/image/collection nodes and links requires/info (putAndLink 1219, links.updateSync 1222). |
| C5 | `_initiateDownload` → `_downloadTrack`/`_downloadImage` | `backend:1537-1564`, `1606-1675`, `1679-1713` | Sets `path`, `fileTranscodingProfile`, marks `enqueued`. Real downloader task created in `downloadTaskQueue._advanceQueue` via `FileDownloader().enqueue` (`backend:333-375`). |
| C6 | `_backfillFinampCollectionLibraryIds` | `downloads_service.dart:1448-1501` | P0.1 one-time field backfill; updates rows, creates no new downloads. |

---

## 3. On-disk storage & how files are tracked

- `DownloadItem.file` getter (`finamp_models.dart:1695-1701`) = join of
  `fileTranscodingProfile.downloadLocationId` → `DownloadLocation.currentPath`
  and `path`.
- Track files: under `FINAMP_BASE_DOWNLOAD_DIRECTORY` subdir of each download
  location (`backend:1595`). Image files: `FINAMP_BASE_IMAGES_DIRECTORY`
  (`backend:1683`); internal images live in `internalTrackDir/images`
  (`downloads_service.dart:809`).
- Files are **tracked only** via the DownloadItem `path` +
  `fileTranscodingProfile` fields. There is no separate file registry and no
  cache-vs-own distinction on disk.

---

## 4. Removal / eviction / cleanup paths

| # | Path | Location | Ownership-aware? | Can silently remove explicit downloads? |
|---|------|----------|------------------|------------------------------------------|
| R1 | `deleteDownload` (user removes item) | `downloads_service.dart:470-505` | Yes (user action) | No — user-initiated, clears marker first (484). |
| R2 | `DownloadsDeleteService.syncDelete` | `backend:551-629` | Partial (keeps required nodes, 566) | Mostly no — only deletes unrequired nodes. Edge risk if a user download loses its anchor link (e.g. hierarchy repair). |
| R3 | `DownloadsDeleteService.deleteDownload` (file delete) | `backend:634-675` | **No** | Deletes the physical file at 641-648 for ANY node with state != notDownloaded. Guarded only by the caller. |
| R4 | `repairAllDownloads` step 2 — delete bad-state items | `downloads_service.dart:690-704` | **No** | **YES.** For every track/image with state enqueued/downloading/failed/syncFailed/needsRedownload*/… it calls `deleteBuffer.deleteDownload` (702). A user-downloaded track in `failed`/`needsRedownload` state (e.g. after an offline or flaky re-sync) gets its file deleted. |
| R5 | `repairAllDownloads` step 5 — syncDelete every node | `downloads_service.dart:795-802` | Via R2 | Mostly no; relies on graph integrity. |
| R6 | `repairAllDownloads` step 6 — orphan file cleanup | `downloads_service.dart:804-848` | **No** | **YES (HIGH).** The cache-cleanup path. Deletes every file in the download/image dirs that is not referenced by a node in `state == complete` (keep-set built at 828-840). A user's explicitly-downloaded track whose node is `failed`/`needsRedownload`/`enqueued` has its file treated as orphan and DELETED (841-848). |
| R7 | `_initiateDownload` cleanup-before-redownload | `backend:1548,1553` | **No** | Partial — deletes the file then re-downloads. Destructive when offline (no re-download possible): `_downloadTrack` marks failed (`backend:1610-1617`) after the file is gone. |
| R8 | `downloadTaskQueue.remove` | `backend:408-421` | n/a | Cancels task, resets state; does not delete the file. |
| R9 | `markOutdatedTranscodes` | `downloads_service.dart:1035-1057` | No | Re-download path (content re-established online); offline it can cascade to R7. |

`repairAllDownloads` is triggered automatically (not only by the manual Repair
button `repair_downloads_button.dart:31`): on startup when the internal download
location was missing and recreated (`main.dart:269`) and at the end of hive
migration (`downloads_service.dart:1089`). The automatic re-sync on startup /
focus / offline-exit (`restartDownloads` `downloads_service.dart:395-411`,
`startQueues` `371-391`) drives R7 through `_syncDownload`.

### Verdict
R4 (step 2), R6 (step 6) and R7-offline are the automatic removal paths that can
silently delete an explicit user download's file. The catastrophic scenario: a
user's offline library, tracks in `failed`/`needsRedownload` state with the file
present on disk, then any `repairAllDownloads` — step 2 deletes the file (R4),
step 6 would orphan it (R6), and an offline re-sync deletes it again (R7) — with
no re-download possible. The user loses the explicit download permanently.

---

## 5. The minimal fix (step 5b)

Three safe guards, one helper. No schema change (no build_runner, no Isar
migration). Ownership is derived from the existing, migration-safe
`userTranscodingProfile` marker + the `requiredBy` graph.

- **Helper `isExplicitUserDownload(item)`** (`downloads_service.dart`): true if
  the item itself has `userTranscodingProfile != null`, or any required
  ancestor does (covers every track/image in a user's download subtree).
- **Guard 1 (R6, step 6 orphan cleanup):** the file "keep" set now also keeps
  files of any still-existing node that `isExplicitUserDownload` — so cache
  cleanup can never orphan an explicit download, regardless of node state.
- **Guard 2 (R4, step 2):** skip `deleteDownload` for an explicit user download
  whose file currently exists, in the `failed`/`syncFailed`/`needsRedownload*`
  states, leaving it for the normal re-sync instead of deleting the content.
- **Guard 3 (R3 `deleteDownload`, offline):** do not delete the physical file
  of an explicit user download when the app is offline (no re-download is
  possible), across every deletion path including R7.

Online behavior is unchanged: explicit downloads are still deleted-then-
redownloaded during re-sync exactly as today, so the re-download queue
mechanics and `requireWifiForDownloads` are untouched. User-initiated removal
(R1) still works: the marker is cleared before unlink, so the node is no longer
`isExplicitUserDownload` and the file is deleted normally.

Known limitation (deferred to P0.2 step 6 state machine): online-but-server-
unreachable where `_initiateDownload` deletes the file and the re-download then
fails is still lossy; closing it would change the re-download queue mechanics,
which step 5 deliberately does not do.

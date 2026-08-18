# JellyAmp P0.2 step 6 — Authoritative Download State Machine

Date: 2026-08-18
Branch: features/jellyamp-1.1
Status: IMPLEMENTED (service API + state machine + R7 fix). Downloads-screen UI is P0.2 step 7 (out of scope).

## Roadmap state mapping

The roadmap (P0.2) specifies one authoritative state model. JellyAmp persists download
state as the Isar `DownloadItemState` enum, which is enumerated by Isar ("do not modify
order or delete existing entries; new entries appended at end"). Mapping:

| Roadmap state | Existing DownloadItemState | Notes |
|---|---|---|
| QUEUED | `enqueued` | awaiting/held by queue |
| DOWNLOADING | `downloading` | active transfer |
| PAUSED | `paused` (NEW, ordinal 8, appended at end) | no existing fit: app-level pause must be non-final, survive restart, and NOT auto-resume (background_downloader TaskStatus.paused currently maps to enqueued, which would auto-resume — an explicit pause must not) |
| VERIFYING | (transient, no stored state) | filesystem verification in `initializeQueue()` (backend:248-286) and `_verifyDownload()` (downloads_service.dart:872) |
| DOWNLOADED | `complete` | `needsRedownloadComplete` = complete-but-outdated |
| FAILED | `failed` / `syncFailed` | |
| STALE | `needsRedownload` / `needsRedownloadComplete` | |
| REMOVED | `notDownloaded` | |

Enum change: ADDITIVE only — `paused` appended at end, ordinals 0-7 of existing 1.0 data
unchanged. Isar regenerated (`finamp_models.g.dart` has `'paused': 8` + reverse map).
`copyWith` already copies state.

## R7 fix — close the delete-then-redownload data-loss path

- `_initiateDownload` (downloads_service_backend.dart:1546-1680) NO LONGER calls
  `deleteBuffer.deleteDownload` for any re-queue path. Both branches (enqueued/downloading-invalid,
  and failed/syncFailed/needsRedownload*) now call the new `resetForRedownload()` (backend:434):
  cancels the active task, marks the node `notDownloaded`, but NEVER deletes the file.
- Verified against background_downloader 9.5.6 native source (`DownloadTaskRunner.kt`): downloads
  go to a temp file and are only `Files.move/copyTo`'d to the destination on `TaskStatus.complete`
  (lines 256-287); on failure/pause/timeout only the TEMP file is deleted (cleanup ->
  `deleteTempFile`, 552-558). Therefore a failed re-download leaves the pre-existing file intact:
  the machine reaches FAILED-with-file-preserved instead of delete-then-fail. No silent file loss
  when the server is merely unreachable.
- `deleteBuffer.deleteDownload` (backend:634-684) untouched, so user-initiated delete (R1) and
  repair step 2 (R4) keep their step-5 guards; explicit removal still works.

## Download Manager service API (DownloadsService, downloads_service.dart ~1881+)

Queryable:
- `downloadStateCounts` (live Map<DownloadItemState,int> via existing stream)
- `activeDownloads`, `queuedDownloads`, `pausedDownloads`, `completedDownloads`,
  `failedDownloads`, `staleDownloads`

Actions:
- `pauseDownload(DownloadStub)`, `resumeDownload(DownloadStub)`, `pauseAllDownloads()`,
  `resumeAllDownloads()`, `retryFailedDownloads()`, `cancelDownload(DownloadStub)`
  (cancel in-progress without deleting files — distinct from `deleteDownload`, which removes
  explicit downloads), plus the existing `deleteDownload`.
- Backend (IsarTaskQueue, downloads_service_backend.dart ~421+): `pause`, `resume`,
  `pauseAllDownloads`, `resumeAllDownloads`, `retryFailedDownloads`, `resetForRedownload`.

Storage:
- `getStorageUsed()`, `getStorageUsedByLocation()`.
- Documented gaps (P1, need a dependency): `transferRateBytesPerSecond` => null (tasks run
  `Updates.status` only — no progress events); remaining-storage unknown (`dart:io` has no
  free-space stat). No new deps added.

## Restart / network resilience

- `paused` is persisted in Isar (enum ordinal), so pause survives restart/process death.
- `initializeQueue()` (backend:248) reconciles only enqueued/downloading — paused rows are left
  alone (do NOT auto-resume or get cancelled). `resume()` re-enqueues with a fresh
  Authorization header (avoids background_downloader's stale-header resume).
- R7 fix: network loss + re-sync no longer destroys files — a node whose re-download fails is
  left failed-with-file, re-verified by `_verifyDownload` on next access, re-syncable later.

## Pitfalls check

- `allTasks()`: untouched. No new `allTasks()`-based paused detection. Pause cancels the task
  outright (no lingering native paused task); `_advanceQueue`'s enqueued-only scan never picks
  up paused rows. The platform `TaskQueue.pauseAll/resumeAll` no-op overrides (backend:432-434)
  are UNTOUCHED — new API methods are named `pauseAllDownloads`/`resumeAllDownloads` to avoid
  collision with the queue hook used for WiFi-requirement changes.
- `requireWifiForDownloads`: untouched (`FileDownloader().requireWiFi` wiring at
  downloads_service.dart:322-336 and the `_advanceQueue` gate at backend:318 unchanged).

## Verification

- `flutter analyze` on all touched files: 0 errors.
- `flutter test benchmark/db_bench_test.dart`: PASS (schema intact, ~20x speedup still reported).
- Two tiny exhaustive-switch fixes for the new `paused` state: downloaded_indicator.dart and
  item_file_size.dart render paused like other in-progress items.

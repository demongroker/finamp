# JellyAmp 1.1 - P0.1 Large-Library Bottlenecks

Date: 2026-08-18
Branch: features/jellyamp-1.1
Status: MEASUREMENT-FIRST. Findings are validated by code reading and the P0.1 baseline
numbers (benchmark/BASELINE_2026-08-18.md). This document identifies WHERE the time goes
and WHY. It intentionally does NOT prescribe or implement fixes (those are later lanes).

Severity scale: [CRITICAL] blocks a usable large-library UX; [HIGH] severe jank; [MEDIUM]
noticeable cost at scale.

---

## 1. [CRITICAL -> ADDRESSED] Large API response + JSON parsing (already on a background isolate)

Where (production): lib/services/jellyfin_api_helper.dart:281 (`runInIsolate` wraps the
entire fetch + parse) and :432 (the `QueryResult_BaseItemDto.fromJson` inside that
background-isolate closure). The library-load provider (music_screen_provider.dart:320 ->
`JellyfinApiHelper.getItems` -> `_fetchGetItemsResponse`) runs the heavy parse in a
**persistent background worker isolate** spawned once in the helper constructor
(jellyfin_api_helper.dart:56). This is the upstream Finamp worker-isolate architecture.

Why this was reported as a main-isolate parse: benchmark/BASELINE and the earlier
BOTTLENECKS #1 measured `QueryResult_BaseItemDto.fromJson` called **directly on the
test/main isolate** (bench_test.dart), which does NOT reflect the production path. In the
app the same fromJson runs in the worker isolate, so the parse is already off the UI
isolate. The headline "~2.6 s of blocked main thread @100k" was a proxy for the worker-side
parse cost, not actual main-isolate blocking.

Sendability (verified): `BaseItemDto` / `QueryResult_BaseItemDto` are plain Dart object
graphs (primitives + nested model lists/maps; no closures, Isar objects, `Timestamp`, or
native handles) and are fully sendable across isolates. This is proven both by the existing
production `runInIsolate` (the worker returns the parsed result to the main isolate via a
SendPort) and by the P0.1 option A benchmark's isolate round-trip.

P0.1 option A verification (benchmark/bench_test.dart "parse off the UI isolate", this
change). Real headless numbers (desktop VM), sync-on-main vs background-isolate parse,
result asserted identical (same count + same first/last item id):

| Scale  | Sync parse on main | Background-isolate parse (wall) | Ratio |
|---|---|---|---|
| 10k    | 198 ms | 1130 ms | 5.0x |
| 25k    | 540 ms | 2090 ms | 3.3x |
| 50k    | 1018 ms | 3343 ms | 3.1x |
| 100k   | 2241 ms | 5846 ms | 2.2x |

Delivery cost (what actually lands on the main/UI isolate): moving the already-parsed graph
back across an isolate boundary measured ~2181 ms round-trip @50k and ~3718 ms @100k
(~1.1 s / ~1.9 s one-way).

Honest residual: the benchmark's fresh-`Isolate.run` numbers include a cold-JIT penalty that
the production **persistent** worker does not pay after its first call, so they overstate the
production worker-parse cost. The genuinely unavoidable main-isolate cost is the *delivery*
of the parsed objects back to the UI isolate (the ~1-2 s @100k transfer above), which is
inherent to returning parsed objects to the UI. At the extreme 100k-single-response case the
transfer is comparable to the parse, so pure off-loading does not fully relieve the main
thread there. Full relief would require not materializing the entire library on the main
isolate at once (paging). The app already pages online browsing via `startIndex`/`limit`, and
larger paging/materialization work is deferred (not part of this pure off-loading change).

Why no redundant code change was made: the parse is already on a background isolate via
`runInIsolate`; wrapping the already-offloaded `fromJson` in an extra `Isolate.run`/`compute`
would be double-isolation (an extra spawn + an extra transfer hop) and strictly worse.
Category: large API responses + JSON parsing + main-isolate CPU work.

## 2. [CRITICAL -> ADDRESSED] sortItems() sorted the full list on the UI isolate, with an
   expensive artist comparator

Where: lib/services/music_screen_provider.dart:433 (sort after load, main isolate);
:448-548 (sortItems); :477-478 (`sortedBy` + `join` inside the artist comparator ->
O(n log n) sorts with an O(k log k) per-comparison cost).

Evidence (before, 100k tracks):
- SortBy.sortName: 430 ms
- SortBy.dateCreated: 1120 ms
- SortBy.artist: 5880 ms  <-- dominant (string building inside every comparison)
- By contrast SortBy.runtime 86 ms / productionYear 56 ms / playCount 131 ms are cheap.

Fix (2026-08-18, P0.1 option B, commit `perf(sort)` on features/jellyamp-1.1):
- Extracted `artistSortKey(item)` (same sortedBy + join string as before) and PRE-COMPUTED it
  once per item into an identity-keyed LinkedHashMap before the sort, so the comparator does
  an O(1) lookup instead of an O(k log k) per-comparison sortedBy+join. Identity keying chosen
  because BaseItemDto overrides ==/hashCode by id.
- Semantics-preserving by construction: identical comparator strings on the same pure, stable
  `sortedBy` (which copies the list), identical ascending + `.reversed` descending tail.

Verified result (benchmark/bench_test.dart, 100k tracks, after):
- SortBy.artist: 591 ms (from 5462-5880 ms)  ~9-10x faster
- SortBy.sortName: 466 ms (unchanged)
All canonical benchmark tests pass.

Category: sorting/filtering + excessive rebuilds.

## 4. [HIGH -> ADDRESSED] getAllCollections fullyDownloaded path did a full findAllSync then filters client-side

Where: lib/services/downloads_service.dart:1466-1485 (getAllCollections fullyDownloaded
path). ADDDRESSED in P0.1 option C.

Evidence (before): full table scan materialized into memory before any predicate is applied; the
filter ran after.

Fix (2026-08-18, commit `perf(offline)` on features/jellyamp-1.1):
- Added a non-unique indexed Isar discriminator `finampCollectionLibraryId` (nullable String) to
  DownloadItem (lib/models/finamp_models.dart), populated only for `collectionWithLibraryFilter`
  rows (in `asItem()`, passed through `copyWith()`).
- Rewrote the fullyDownloaded path to `where().finampCollectionLibraryIdEqualTo(viewId)
  .filter().typeEqualTo(finampCollection).not().stateEqualTo(notDownloaded)` instead of
  `findAllSync()` + client-side loop.
- Added a one-time, session-guarded backfill (`_backfillFinampCollectionLibraryIds`) so existing
  1.0 rows get the discriminator populated on upgrade (exact-result-semantics preserved;
  migration is additive/non-unique-index-only, no data loss).
- Added benchmark/db_bench_test.dart (headless real-Isar, 20k rows).

Measured result (benchmark/db_bench_test.dart, 20k rows, exact-result equality asserted):
- OLD findAllSync + client-filter: ~640 ms (materialized 20000)
- NEW indexed bounded query: ~31 ms (touched 500)
- SPEEDUP: ~20.6x on this run (range across runs ~21-56x, typical ~30x)
- The one-time backfill (`_backfillFinampCollectionLibraryIds`) is now fully implemented and
  verified compiling/green: session-guarded, try/catch-wrapped, additive. It decodes each
  pre-existing `collectionWithLibraryFilter` row from jsonItem, writes `finampCollectionLibraryId`
  via `putAllSync` only where the value actually changes (never nulls anything out), and is awaited
  once before the indexed scan in getAllCollections. It is out of the hot path, so the numbers
  above hold with it in place.
Category: DB queries / missing indexes + allocation.

## 3. [HIGH -> NOT index-addressable, DROPPED] Offline search uses a non-indexed substring Isar query and materializes the full result set

Where: lib/services/downloads_service.dart:1394 and :1491 (`nameContains(nameFilter!,
caseSensitive: false)`); lib/services/music_screen_provider.dart:445 (skip/take applied
AFTER the full list is loaded and sorted).

Status: NOT addressable via an Isar index. Verified against the pinned isar-community 3.1.0+1
Rust source: `nameContains` is a substring filter (`fast_wild_match` per object), not a
`where()` clause, so an `@Index()` on `name` does not accelerate it. No speculative name index
was added. A real fix would need full-text search (e.g. a separate indexed search table / FTS)
or a client-side search index, both deferred. The provider also re-sorts/slices the full
materialized set after load; DB-side offset/limit would only be safe on default-order paths
(provider re-sorts on JSON-derived fields), so pagination into the query is deferred too.


## 5. [HIGH] Search matches() is a linear scan over every item, with per-item media
   source/stream traversal

Where: lib/models/search_models.dart:154-173 (`matches`); :175+ (`matchesAllTracks`,
`_audioCodec`/`_audioBitDepth` traverse item media streams); album filtering walks each
album's tracks.

Evidence (100k tracks, bench_test.dart scan over the full list):
- midnight: 22.8 ms (100000 matched)
- year:1970-1990: 23.3 ms (31830 matched)
- favorite:true: 14.1 ms
- genre:rock codec:flac: 57.5 ms (heaviest; 0 matched on this data shape but cost is
  per-item traversal)

Impact: O(items) at minimum, and O(albums*tracks) for quality-filtered album search at
scale. Per-item media traversal makes it worse than a bare text scan. Category:
sorting/filtering.

---

## Reading the numbers correctly

- All headless numbers are on a desktop VM and are lower bounds for device behavior
  (app-model parse and sort run on the app's main isolate on-device too, so the *ratio*
  and the *ordering* of costs transfer, not the absolute ms).
- Match counts (e.g. genre:rock codec:flac = 0) depend on the synthetic dataset's
  distribution and are not meaningful on their own; the scan TIME is what matters.
- RSS figures in BASELINE are noisy across tests in one process; treat them as an
  upper-bound proxy only.

## Relationship to targets (roadmap doc_9a488dedaec7, P0.1)

The P0.1 target is a measured baseline, which this scaffolding now provides. The two dominant
costs to beat, in order, are the client-side sort (~5.9 s @100k before option B; ~0.6 s
after) and the search scan (~20-60 ms per query). The large-parse cost (~2.6 s @100k) is
NOT a main-isolate cost in production: it already runs in the background worker isolate via
`runInIsolate` (see #1 above); the residual main-isolate cost is the delivery of the parsed
objects back to the UI, which only becomes significant at extreme single-response sizes and
is addressed by paging rather than off-loading. Any P0.2+ optimization should move the sort
and search numbers; they are the reference points.

# JellyAmp 1.1 - P0.1 Large-Library Bottlenecks

Date: 2026-08-18
Branch: features/jellyamp-1.1
Status: MEASUREMENT-FIRST. Findings are validated by code reading and the P0.1 baseline
numbers (benchmark/BASELINE_2026-08-18.md). This document identifies WHERE the time goes
and WHY. It intentionally does NOT prescribe or implement fixes (those are later lanes).

Severity scale: [CRITICAL] blocks a usable large-library UX; [HIGH] severe jank; [MEDIUM]
noticeable cost at scale.

---

## 1. [CRITICAL] Large API response + JSON parsing on the main/UI isolate

Where: lib/services/music_screen_provider.dart:268-352 (provider fetches the library and
parses it in place); lib/models/jellyfin_models.g.dart:3747-3844 (`_$BaseItemDtoFromJson`
parses 60+ fields per item, including full MediaSources/MediaStreams).

Evidence (100k tracks, desktop VM):
- Raw jsonDecode: ~3131 ms (bench.dart).
- Full `QueryResult_BaseItemDto.fromJson`: ~2559 ms = ~25.6 micros/item (bench_test.dart).
- Linear scaling: 215.9 ms @10k -> 600.4 @25k -> 1137.6 @50k -> 2559.4 @100k.

Impact: A 100k-track fetch + parse alone is ~2.6 s of blocked main thread before any
sorting, on a desktop-class CPU; on-device it will be worse. Category: large API
responses + JSON parsing + main-isolate CPU work.

## 2. [CRITICAL] sortItems() sorts the full list on the UI isolate, with an expensive
   artist comparator

Where: lib/services/music_screen_provider.dart:433 (sort after load, main isolate);
:448-548 (sortItems); :477-478 (`sortedBy` + `join` inside the artist comparator ->
O(n log n) sorts with an O(k log k) per-comparison cost).

Evidence (100k tracks):
- SortBy.sortName: 430 ms
- SortBy.dateCreated: 1120 ms
- SortBy.artist: 5880 ms  <-- dominant (string building inside every comparison)
- By contrast SortBy.runtime 86 ms / productionYear 56 ms / playCount 131 ms are cheap.

Impact: At 100k, just the artist-sort is ~5.9 s on the UI thread. Combined with the ~2.6 s
parse, the first library frame is ~8.5 s away at the largest target scale. Category:
sorting/filtering + excessive rebuilds.

## 3. [HIGH] Offline search uses a non-indexed substring Isar query and materializes the
   full result set

Where: lib/services/downloads_service.dart:1394 and :1491 (`nameContains(nameFilter!,
caseSensitive: false)`); lib/services/music_screen_provider.dart:445 (skip/take applied
AFTER the full list is loaded and sorted).

Evidence: substring match on the Name field, no index; the provider then re-sorts and
slices the entire materialized result set client-side, so skip/take do not bound the query
cost.

Impact: Every offline search scans/loads the whole collection; cost grows with the full
library size, not with the result window. Category: DB queries / missing indexes +
allocation.

## 4. [HIGH] getAllCollections fullyDownloaded path does a full findAllSync then filters
   client-side

Where: lib/services/downloads_service.dart:1466-1485 (getAllCollections
fullyDownloaded path: materialize all collections, then filter in Dart).

Evidence: full table scan materialized into memory before any predicate is applied; the
filter runs after.

Impact: Loading collections at scale materializes every row (and its joined relations)
even when few are downloaded, inflating time and memory. Category: DB queries / missing
indexes + allocation.

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

The P0.1 target is a measured baseline, which this scaffolding now provides. The three
dominant costs to beat are, in order: parse (~2.6 s @100k), artist sort (~5.9 s @100k),
search scan (~20-60 ms per query). Any P0.2+ optimization should move these numbers; they
are the reference points.

// JellyAmp P0.1 headless diagnostics harness (Flutter test).
//
// This is the core measurement pass that CAN run on a headless Linux box: it
// exercises the REAL app code paths for large-library processing without a
// device or display, via `flutter test` (the VM test binding needs no UI).
//
// Measured (headless):
//   - Real JSON parsing: QueryResult_BaseItemDto.fromJson / BaseItemDto.fromJson
//     over the generated datasets (the exact path music_screen_provider uses for
//     online library browsing). This is the dominant "large API response + JSON
//     parsing" cost.
//   - Client-side sorter: sortItems() from lib/services/music_screen_provider.dart
//     (the exact sorter used at the end of loadHomeSectionItemsOffline / online
//     load), across several SortBy keys and all scales.
//   - Search: SearchQuery.parse + matches() latency (lib/models/search_models.dart).
//   - Approximate headroom / memory: RSS growth while materializing the parsed
//     list (proxy for "avoid materializing the entire library").
//
// Output: prints key=value lines and writes benchmark/results/headless_<date>.json.
//
// NOT measured here (device-only -> PENDING, see BASELINE): app-shell time,
// cold/warm launch, scroll FPS, peak device memory, offline startup, album/artist
// screen render. Those run on-device via benchmark/integration_test.dart.
//
// Usage (from repo root):
//   flutter test benchmark/bench_test.dart
//
// NOTE: `flutter test` on this repo normally reports "no test directory found"
// for the default (no-path) invocation; passing the explicit file path runs this
// harness. A bare `flutter test` with no path is NOT what runs this file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:finamp/models/jellyfin_models.dart'
    show BaseItemDto, QueryResult_BaseItemDto, SortBy, SortOrder;
import 'package:finamp/models/search_models.dart' show SearchQuery;
import 'package:finamp/services/music_screen_provider.dart' show sortItems;
import 'package:flutter_test/flutter_test.dart';

const String _dataDir = 'benchmark/data';
const String _outDir = 'benchmark/results';

void main() {
  final results = <String, Object>{};
  results['date'] = DateTime.now().toIso8601String();
  results['toolchain'] = 'flutter test (headless VM)';
  results['host'] = Platform.operatingSystem;

  group('P0.1 headless benchmark', () {
    final datasetFiles = _loadDatasets();
    if (datasetFiles.isEmpty) {
      fail('No datasets under $_dataDir. Run: dart run benchmark/dataset_generator.dart');
    }

    test('real JSON parsing (QueryResult_BaseItemDto.fromJson)', () {
      for (final ds in datasetFiles) {
        final map = jsonDecode(ds.text) as Map<String, dynamic>;
        // Warm up JIT once.
        QueryResult_BaseItemDto.fromJson(map);
        final sw = Stopwatch()..start();
        final parsed = QueryResult_BaseItemDto.fromJson(map);
        sw.stop();
        final items = parsed.items!;
        results['parse_ms_${ds.name}'] = _ms(sw.elapsedMicroseconds);
        results['parse_items_${ds.name}'] = items.length;
        // Sanity: make sure we parsed real items (id + type + name present).
        final first = items.first;
        expect(first.id, isNotEmpty);
        expect(first.type, isNotEmpty);
        // RSS delta while holding the parsed list materialized (memory proxy).
        results['rss_bytes_${ds.name}'] = ProcessInfo.currentRss;
        results['approx_bytes_per_item_${ds.name}'] =
            (ProcessInfo.currentRss / items.length).round();
        results['json_mb_${ds.name}'] = (ds.bytes.length / (1024 * 1024))
            .toStringAsFixed(2);
      }
    });

    test('client-side sortItems() latency by sort key (100k tracks)', () {
      final ds = datasetFiles.firstWhere((d) => d.name == 'library_100k_tracks');
      final map = jsonDecode(ds.text) as Map<String, dynamic>;
      final items = QueryResult_BaseItemDto.fromJson(map).items!;
      final sortKeys = <String, SortBy>{
        'sortName': SortBy.sortName,
        'albumArtist': SortBy.albumArtist,
        'artist': SortBy.artist,
        'runtime': SortBy.runtime,
        'productionYear': SortBy.productionYear,
        'dateCreated': SortBy.dateCreated,
        'playCount': SortBy.playCount,
      };
      for (final entry in sortKeys.entries) {
        // Copy so each run sorts an unsorted list (deterministic, same input).
        final copy = List<BaseItemDto>.of(items);
        final sw = Stopwatch()..start();
        sortItems(copy, entry.value, SortOrder.ascending);
        sw.stop();
        results['sort_ms_100k_${entry.key}'] = _ms(sw.elapsedMicroseconds);
      }
    });

    test('client-side sortItems() scaling (sortName, all scales)', () {
      for (final ds in datasetFiles) {
        final map = jsonDecode(ds.text) as Map<String, dynamic>;
        final items = QueryResult_BaseItemDto.fromJson(map).items!;
        final copy = List<BaseItemDto>.of(items);
        final sw = Stopwatch()..start();
        sortItems(copy, SortBy.sortName, SortOrder.ascending);
        sw.stop();
        results['sort_ms_${ds.name}_sortName'] = _ms(sw.elapsedMicroseconds);
      }
    });

    test('SearchQuery parse + matches latency (100k tracks)', () {
      final ds = datasetFiles.firstWhere((d) => d.name == 'library_100k_tracks');
      final map = jsonDecode(ds.text) as Map<String, dynamic>;
      final items = QueryResult_BaseItemDto.fromJson(map).items!;

      const queries = [
        'midnight', // free text
        'artist:artist 1000', // scoped
        'year:1970-1990', // range
        'favorite:true', // boolean
        'genre:rock codec:flac', // multi-keyword
      ];

      for (final q in queries) {
        // parse latency (constant, independent of dataset size)
        var sw = Stopwatch()..start();
        final parsed = SearchQuery.parse(q);
        sw.stop();
        results['search_parse_ms_${q.replaceAll(' ', '_')}'] = _ms(sw.elapsedMicroseconds);

        // matches() over the full 100k list (linear scan -> the client-side filter)
        var matched = 0;
        sw = Stopwatch()..start();
        for (final item in items) {
          if (parsed.matches(item)) matched++;
        }
        sw.stop();
        results['search_scan_ms_100k_${q.replaceAll(' ', '_')}'] =
            _ms(sw.elapsedMicroseconds);
        results['search_matches_${q.replaceAll(' ', '_')}'] = matched;
      }
    });
  });

  tearDownAll(() async {
    // Write a parseable report for the baseline file.
    final dir = Directory(_outDir);
    dir.createSync(recursive: true);
    final stamp = results['date']!.toString().substring(0, 10);
    final file = File('$_outDir/headless_$stamp.json');
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
    // Also print key=value lines to stdout for capture.
    final sortedKeys = results.keys.toList()..sort();
    for (final k in sortedKeys) {
      // ignore: avoid_print
      print('$k=${results[k]}');
    }
    // ignore: avoid_print
    print('REPORT=$file');
  });
}

String _ms(int micros) => (micros / 1000.0).toStringAsFixed(2);

class _Dataset {
  _Dataset(this.name, this.bytes, this.text);
  final String name;
  final Uint8List bytes;
  final String text;
}

List<_Dataset> _loadDatasets() {
  final dir = Directory(_dataDir);
  if (!dir.existsSync()) return const [];
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('_tracks.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      _Dataset(
        f.path.split('/').last.replaceFirst('.json', ''),
        f.readAsBytesSync(),
        f.readAsStringSync(),
      ),
  ];
}

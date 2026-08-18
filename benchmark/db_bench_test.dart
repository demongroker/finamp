// JellyAmp P0.1 BOTTLENECK #4 headless Isar DB benchmark.
//
// Measures the getAllCollections fullyDownloaded/library-filter path BEFORE
// (full findAllSync over every finampCollection row + client-side filter that
// reparses each row's jsonItem) vs AFTER (indexed, bounded scan on the new
// non-unique `DownloadItem.finampCollectionLibraryId` discriminator).
//
// This is a REAL Isar DB test: it opens Isar on a temp directory with the real
// DownloadItemSchema, seeds real DownloadItem rows through the real app code
// (DownloadStub.fromFinampCollection(...).asItem(...)), and runs the exact
// old/new query shapes from downloads_service.dart. It requires the native
// Isar core (libisar.so) which is resolved from the pinned isar_flutter_libs
// git dependency via .dart_tool/package_config.json.
//
// Usage (from repo root):
//   flutter test benchmark/db_bench_test.dart
//
// The native core is required for this file; it is loaded explicitly with
// Isar.initializeIsarCore (pure-flutter-test Isar, no device/display needed).

import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

// Import the whole finamp_models library (not a `show` sublist) so the Isar
// where-builder extensions generated into finamp_models.g.dart (e.g.
// `typeEqualTo`, `finampCollectionLibraryIdEqualTo`) are in scope. With a
// `show` clause those extension members are hidden and the indexed queries
// below fail to compile.
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart' show BaseItemDto, BaseItemId;
import 'package:flutter_test/flutter_test.dart';
// Full import (no `show Isar`): the query-builder extension methods
// `filter`, `not`, `anyOf`, etc. live in the isar package and must be in
// scope, not just the `Isar` class.
import 'package:isar/isar.dart';

void main() {
  // DownloadStub.fromFinampCollection touches GlobalSnackbar (via
  // requireL10n -> GlobalKey.currentContext), which requires a widget binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Isar isar;
  // Number of finampCollection rows per library. 1 queried library + N-1
  // distractors make the pre-change scan materialize + reparse far more rows
  // than the post-change index scan touches.
  const int libraries = 40;
  const int rowsPerLibrary = 500;
  const int metadataCollections = 100;
  const String queryLibraryId = 'lib0';

  setUpAll(() async {
    // Load the pinned native Isar core (linuxX64).
    final isarLibPath = _resolveIsarCore();
    await Isar.initializeIsarCore(libraries: {Abi.current(): isarLibPath});

    tempDir = await Directory.systemTemp.createTemp('jellyamp_db_bench');
    isar = await Isar.open(
      [DownloadItemSchema],
      directory: tempDir.path,
      name: 'jellyamp_db_bench',
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('seed DownloadItem rows at scale', () async {
    final items = <DownloadItem>[];
    for (var lib = 0; lib < libraries; lib++) {
      final libId = 'lib$lib';
      for (var row = 0; row < rowsPerLibrary; row++) {
        final item = DownloadStub.fromFinampCollection(FinampCollection(
          type: FinampCollectionType.collectionWithLibraryFilter,
          library: _lib(libId),
          item: _item('item_${lib}_$row'),
        )).asItem(null);
        // A downloaded (synced) library-filtered collection: passes the
        // state != notDownloaded predicate in both query shapes.
        item.state = DownloadItemState.complete;
        items.add(item);
      }
    }
    for (var i = 0; i < metadataCollections; i++) {
      // Non-library-filtered finampCollections: discriminator stays null.
      items.add(DownloadStub.fromFinampCollection(
        FinampCollection(type: i.isEven ? FinampCollectionType.favorites : FinampCollectionType.allPlaylists),
      ).asItem(null));
    }
    // A handful of non-finampCollection rows (tracks/collections) for realism;
    // these never match the finampCollection query either way.
    for (var i = 0; i < 2000; i++) {
      items.add(DownloadStub.fromItem(
        type: DownloadItemType.track,
        item: _item('track_$i', type: 'Audio'),
      ).asItem(null));
    }

    const chunk = 1000;
    for (var i = 0; i < items.length; i += chunk) {
      await isar.writeTxn(() async {
        await isar.downloadItems.putAll(items.sublist(i, i + chunk > items.length ? items.length : i + chunk));
      });
    }
    final count = await isar.downloadItems.count();
    // putAll dedupes on the primary key (isarId). The metadata finampCollection
    // rows share constant ids ("Favorites"/"All Playlists" by design, one each
    // per app), so the persisted count equals the number of unique isarIds, not
    // items.length.
    final uniqueCount = items.map((e) => e.isarId).toSet().length;
    expect(count, uniqueCount);
  });

  test('BOTTLENECK #4: old findAllSync+client filter vs new indexed bounded query',
      () {
    final totalRows = libraries * rowsPerLibrary + metadataCollections + 2000;
    final results = <String, Object>{};
    results['host'] = Platform.operatingSystem;
    results['total_download_items'] = totalRows;
    results['finampcollection_rows'] = libraries * rowsPerLibrary + metadataCollections;
    results['matched_rows'] = rowsPerLibrary; // only lib0 rows
    results['library_id'] = queryLibraryId;

    final oldLibraryId = BaseItemId(queryLibraryId);

    // ---- OLD (downloads_service.dart pre-change): type index + findAllSync
    // ---- then a client-side filter that reparses every row's jsonItem.
    final oldSw = Stopwatch()..start();
    final oldResult = isar.downloadItems
        .where()
        .typeEqualTo(DownloadItemType.finampCollection)
        .filter()
        .not()
        .stateEqualTo(DownloadItemState.notDownloaded)
        .findAllSync()
        .where(
          (collection) =>
              collection.finampCollection!.type == FinampCollectionType.collectionWithLibraryFilter &&
              collection.finampCollection!.library?.id == oldLibraryId,
        )
        .map(
          (collection) => DownloadStub.getHash(
              collection.finampCollection!.item!.id.raw, DownloadItemType.collection),
        )
        .toList();
    oldSw.stop();
    results['old_ms'] = _ms(oldSw.elapsedMicroseconds);
    results['old_rows_materialized'] = libraries * rowsPerLibrary;
    results['old_matched'] = oldResult.length;

    // ---- NEW (downloads_service.dart post-change): indexed discriminator scan.
    final newSw = Stopwatch()..start();
    final newResult = isar.downloadItems
        .where()
        .finampCollectionLibraryIdEqualTo(queryLibraryId)
        .filter()
        .typeEqualTo(DownloadItemType.finampCollection)
        .not()
        .stateEqualTo(DownloadItemState.notDownloaded)
        .findAllSync()
        .map(
          (collection) => DownloadStub.getHash(
              collection.finampCollection!.item!.id.raw, DownloadItemType.collection),
        )
        .toList();
    newSw.stop();
    results['new_ms'] = _ms(newSw.elapsedMicroseconds);
    results['new_rows_touched'] = rowsPerLibrary;
    results['new_matched'] = newResult.length;

    // Exact result-semantics equivalence.
    expect(newResult.toSet(), oldResult.toSet(), reason: 'query result set must match');

    // Speedup.
    final oldMs = oldSw.elapsedMicroseconds / 1000.0;
    final newMs = newSw.elapsedMicroseconds / 1000.0;
    results['speedup_x'] = oldMs / newMs;

    // ignore: avoid_print
    print('OLD findAllSync+client-filter=${results['old_ms']}ms '
        'matched=${results['old_matched']} materialized=${results['old_rows_materialized']}');
    // ignore: avoid_print
    print('NEW indexed-bounded=${results['new_ms']}ms '
        'matched=${results['new_matched']} touched=${results['new_rows_touched']}');
    // ignore: avoid_print
    print('SPEEDUP=${results['speedup_x']}x');

    _writeReport(results);
  });
}

BaseItemDto _lib(String id) => BaseItemDto(id: BaseItemId(id), name: 'Library $id', type: 'CollectionFolder');

BaseItemDto _item(String id, {String type = 'MusicAlbum'}) =>
    BaseItemDto(id: BaseItemId(id), name: 'Item $id', type: type);

/// Resolve the pinned native Isar core (libisar.so) for the current host ABI
/// from the isar_flutter_libs package in .dart_tool/package_config.json.
String _resolveIsarCore() {
  final pkgConfig = File('.dart_tool/package_config.json');
  if (!pkgConfig.existsSync()) {
    throw StateError('.dart_tool/package_config.json not found');
  }
  final map = jsonDecode(pkgConfig.readAsStringSync()) as Map<String, dynamic>;
  for (final p in (map['packages'] as List).cast<Map<String, dynamic>>()) {
    if (p['name'] == 'isar_flutter_libs') {
      final root = Uri.parse(p['rootUri'] as String);
      final pkgPath = File.fromUri(root).path;
      final so = File('$pkgPath/linux/libisar.so');
      if (so.existsSync()) {
        return so.path;
      }
      throw StateError('libisar.so not found under $pkgPath/linux');
    }
  }
  throw StateError('isar_flutter_libs package not found in package_config');
}

void _writeReport(Map<String, Object> results) {
  final dir = Directory('benchmark/results');
  dir.createSync(recursive: true);
  final file = File('${dir.path}/db_bench_${DateTime.now().toIso8601String().substring(0, 10)}.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  // ignore: avoid_print
  print('REPORT=$file');
}

String _ms(int micros) => (micros / 1000.0).toStringAsFixed(2);

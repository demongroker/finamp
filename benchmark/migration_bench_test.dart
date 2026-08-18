// JellyAmp P0.5 step 10 — migration fixture benchmark/test.
//
// Verifies the versioned, transactional, recoverable migration system
// (lib/bootstrap/migrations.dart) against a synthetic PREVIOUS-VERSION (1.0)
// install, using REAL app models + REAL Isar on a temp directory (headless,
// exactly like db_bench_test.dart). It asserts:
//
//   (a) NO DATA LOSS      — the 7 legacy settings migrations produce the same
//                           post-migration state they always did, and no
//                           download row is dropped by opening/reading the DB.
//   (b) DOWNLOADS PROTECTED — explicit downloads (userTranscodingProfile
//                           ownership marker) survive and remain recognized,
//                           indexed, playable (state complete + path) and
//                           protected from cache cleanup (marker intact).
//   (c) NEW SCHEMA READABLE  — the P0.1 `finampCollectionLibraryId` indexed
//                           field and the P0.2 `paused` DownloadItemState enum
//                           (ordinal 8, appended) round-trip correctly on an
//                           install opened with the current schema.
//   (d) IDEMPOTENT        — re-running runMigrations() is a no-op (version
//                           already at currentDataVersion; no double-apply).
//
// Usage (from repo root):
//   flutter test benchmark/migration_bench_test.dart
//
// Requires the native Isar core (libisar.so), resolved from the pinned
// isar_flutter_libs git dependency via .dart_tool/package_config.json.

import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:finamp/bootstrap/migrations.dart';
import 'package:finamp/hive_registrar.g.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart' show BaseItemDto, BaseItemId, SortBy, SortOrder;
import 'package:finamp/models/locale_adapter.dart';
import 'package:finamp/models/theme_mode_adapter.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_test/flutter_test.dart';
// Full import (no `show Isar`): the query-builder extension methods live in
// the isar package and must be in scope.
import 'package:hive_ce_flutter/adapters.dart';
import 'package:isar/isar.dart';

void main() {
  // DownloadStub.fromFinampCollection touches GlobalSnackbar (via
  // requireL10n -> GlobalKey.currentContext), which requires a widget binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  Isar? isar;

  setUpAll(() async {
    final isarLibPath = _resolveIsarCore();
    await Isar.initializeIsarCore(libraries: {Abi.current(): isarLibPath});

    tempDir = await Directory.systemTemp.createTemp('jellyamp_migration_bench');
    Hive.init(tempDir.path);
    // Register every generated Finamp Hive adapter, plus the manual ThemeMode /
    // Locale adapters that the theme/locale migration reads.
    Hive.registerAdapters();
    Hive.registerAdapter(ThemeModeAdapter());
    Hive.registerAdapter(LocaleAdapter());
    Hive.registerAdapter(ColorAdapter());
  });

  test('migrates a synthetic 1.0 install safely (versioned + no data loss + downloads protected)',
      () async {
    // ---------------------------------------------------------------- settings
    // A 1.0 FinampSettings: legacy downloadLocations list (no map yet), legacy
    // sortBy/sortOrder (no per-tab maps), legacy fixed grid size, legacy
    // cluttered home layout, unmigrated feature chips, unset device id, and an
    // incomplete theme/locale migration.
    final legacyDownloadLocation = DownloadLocation(
      name: 'Old Music',
      relativePath: null,
      baseDirectory: DownloadLocationType.cache,
      id: 'dl-legacy',
    );
    final settings = FinampSettings(
      downloadLocations: [legacyDownloadLocation],
      downloadLocationsMap: {},
      tabSortBy: {},
      tabSortOrder: {},
      homeScreenConfiguration: DefaultSettings.homeScreenConfigurationLegacyCluttered,
      gridImageSize: 0,
      homeScreenImageSize: 0,
      deviceId: 'unset',
    );
    // ignore: deprecated_member_use
    settings.sortBy = SortBy.album;
    // ignore: deprecated_member_use
    settings.sortOrder = SortOrder.ascending;
    settings.useFixedSizeGridTiles = true;
    settings.fixedGridTileSize = 220;
    settings.tabOrder = [ContentType.albums];
    settings.showTabs = {ContentType.albums: true}; // mutable, like a Hive-loaded 1.0 install
    settings.featureChipsConfiguration = const FinampFeatureChipsConfiguration(
      enabled: true,
      features: <FinampFeatureChipType>[],
      migrated: false,
    );
    settings.hasCompletedThemeModeLocaleMigration = false;

    final settingsBox = await Hive.openBox<FinampSettings>('FinampSettings');
    await settingsBox.put('FinampSettings', settings);

    // Legacy (1.0) ThemeMode / Locale Hive boxes that the theme/locale
    // migration consumes and then deletes.
    final themeModeBox = await Hive.openBox<ThemeMode>('ThemeMode');
    await themeModeBox.put('ThemeMode', ThemeMode.dark);
    final localeBox = await Hive.openBox<Locale?>('Locale');
    await localeBox.put('Locale', const Locale('fr'));

    // ------------------------------------------------------------------ isar
    // A synthetic 1.0 download DB: an explicit track download, an explicitly
    // downloaded artwork image, a library-filter collection row, and a paused
    // download. Opened with the CURRENT schema (the migration boundary).
    isar = await Isar.open(
      [DownloadItemSchema],
      directory: tempDir.path,
      name: 'jellyamp_migration',
    );

    // 1) Explicit track download — user pressed Download (ownership marker).
    final explicitTrack = DownloadStub.fromItem(
      type: DownloadItemType.track,
      item: _audioItem('track_explicit', 'Track One'),
    ).asItem(null);
    explicitTrack.state = DownloadItemState.complete;
    explicitTrack.path = 'subfolder/track_one.mp3';
    explicitTrack.userTranscodingProfile =
        DownloadProfile(transcodeCodec: FinampTranscodingCodec.opus, bitrate: 128000);

    // 2) Explicitly downloaded artwork image — also protected (has a marker).
    final artwork = DownloadStub.fromItem(
      type: DownloadItemType.image,
      item: BaseItemDto(
        id: BaseItemId('art'),
        name: 'Artwork',
        type: 'Audio',
        imageTags: const {'Primary': 'artimg'},
      ),
    ).asItem(null);
    artwork.state = DownloadItemState.complete;
    artwork.path = 'images/art.jpg';
    artwork.userTranscodingProfile =
        DownloadProfile(transcodeCodec: FinampTranscodingCodec.opus, bitrate: 128000);

    // 3) Library-filter collection row — P0.1 indexed discriminator.
    final libFilter = DownloadStub.fromFinampCollection(FinampCollection(
      type: FinampCollectionType.collectionWithLibraryFilter,
      library: _lib('lib0'),
      item: _item('coll_item_0', type: 'MusicAlbum'),
    )).asItem(null);
    libFilter.state = DownloadItemState.complete;

    // 4) A paused download — P0.2 appended enum state (ordinal 8).
    final paused = DownloadStub.fromItem(
      type: DownloadItemType.track,
      item: _audioItem('track_paused', 'Paused Track'),
    ).asItem(null);
    paused.state = DownloadItemState.paused;

    await isar!.writeTxn(() async {
      await isar!.downloadItems.putAll([explicitTrack, artwork, libFilter, paused]);
    });
    expect(await isar!.downloadItems.count(), 4, reason: 'fixture seeded');

    // ---------------------------------------------------------------- migrate
    await runMigrations();

    // Version is checkpointed to the current version.
    final versionBox = await Hive.openBox<int>('MigrationVersion');
    expect(versionBox.get('version'), currentDataVersion, reason: 'version persisted');

    // ------------------------------------------------------------- assertions
    final migrated = FinampSettingsHelper.finampSettings;

    // (a1) No settings data loss: every legacy value transformed in place.
    expect(migrated.downloadLocations, isEmpty, reason: 'legacy list emptied');
    expect(migrated.downloadLocationsMap.length, 1, reason: 'list migrated to map');
    final locEntry = migrated.downloadLocationsMap.entries.single;
    expect(locEntry.key, locEntry.value.id, reason: 'map keyed by generated id');
    expect(locEntry.value.name, 'Old Music', reason: 'download location preserved');

    expect(migrated.tabSortBy[ContentType.albums], SortBy.album, reason: 'sort migrated');
    expect(migrated.tabSortOrder[ContentType.albums], SortOrder.ascending, reason: 'sort order migrated');

    expect(migrated.gridImageSize, 220, reason: 'fixed grid size migrated');
    // ignore: deprecated_member_use
    expect(migrated.useFixedSizeGridTiles, isNull, reason: 'legacy flag cleared');

    expect(migrated.tabOrder, contains(ContentType.home), reason: 'home tab added');
    expect(migrated.tabOrder, contains(ContentType.albumArtists), reason: 'albumArtists tab added');
    expect(migrated.tabOrder, contains(ContentType.performingArtists), reason: 'performingArtists tab added');

    expect(migrated.featureChipsConfiguration.migrated, isTrue, reason: 'feature chips migrated');
    expect(migrated.deviceId, isNot('unset'), reason: 'device id generated');
    expect(migrated.themeMode, ThemeMode.dark, reason: 'legacy theme migrated');
    expect(migrated.locale, const Locale('fr'), reason: 'legacy locale migrated');
    expect(migrated.hasCompletedThemeModeLocaleMigration, isTrue, reason: 'theme/locale flag set');
    // Legacy Hive boxes consumed + deleted: re-opening yields empty.
    final reopenedTheme = await Hive.openBox<ThemeMode>('ThemeMode');
    expect(reopenedTheme.get('ThemeMode'), isNull, reason: 'legacy ThemeMode box deleted');
    final reopenedLocale = await Hive.openBox<Locale?>('Locale');
    expect(reopenedLocale.get('Locale'), isNull, reason: 'legacy Locale box deleted');

    // (b) Downloads protected: no row dropped, explicit downloads preserved.
    final rows = await isar!.downloadItems.where().findAll();
    expect(rows.length, 4, reason: 'no download row lost through migration');

    // Recognized + playable + protected (ownership marker is exactly what
    // isExplicitUserDownload checks first and what cache cleanup consults).
    final explicit = rows.singleWhere((r) => r.id == 'track_explicit');
    expect(explicit.state, DownloadItemState.complete, reason: 'explicit track still complete (playable)');
    expect(explicit.path, 'subfolder/track_one.mp3', reason: 'file path intact');
    expect(explicit.userTranscodingProfile, isNotNull, reason: 'ownership marker intact (protected)');

    final imageRow = rows.singleWhere((r) => r.id == 'art');
    expect(imageRow.state, DownloadItemState.complete, reason: 'downloaded artwork preserved');
    expect(imageRow.userTranscodingProfile, isNotNull, reason: 'artwork ownership marker intact');

    // (c) New schema readable post-migration.
    final pausedRow = rows.singleWhere((r) => r.id == 'track_paused');
    expect(pausedRow.state, DownloadItemState.paused, reason: 'paused state round-trips');
    expect(DownloadItemState.paused.index, 8, reason: 'paused is appended ordinal 8');

    // finampCollectionLibraryId indexed + readable via the bounded query the
    // P0.1 getAllCollections path uses.
    final libFiltered = await isar!.downloadItems
        .where()
        .finampCollectionLibraryIdEqualTo('lib0')
        .findAll();
    expect(libFiltered.length, 1, reason: 'library-filter collection indexed');
    expect(libFiltered.single.finampCollectionLibraryId, 'lib0', reason: 'discriminator readable');
    expect(libFiltered.single.type, DownloadItemType.finampCollection);

    // (d) Idempotency: re-running the migration is a no-op.
    await runMigrations();
    expect((await Hive.openBox<int>('MigrationVersion')).get('version'), currentDataVersion);
    expect(FinampSettingsHelper.finampSettings.downloadLocationsMap.length, 1, reason: 'no re-migration');
    expect(FinampSettingsHelper.finampSettings.deviceId, migrated.deviceId, reason: 'device id stable');
    expect(await isar!.downloadItems.count(), 4, reason: 'downloads stable across re-run');
  });

  tearDownAll(() async {
    if (isar != null) {
      await isar!.close(deleteFromDisk: true);
    }
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });
}

BaseItemDto _lib(String id) => BaseItemDto(id: BaseItemId(id), name: 'Library $id', type: 'CollectionFolder');

BaseItemDto _item(String id, {String type = 'MusicAlbum'}) =>
    BaseItemDto(id: BaseItemId(id), name: 'Item $id', type: type);

BaseItemDto _audioItem(String id, String name) => BaseItemDto(id: BaseItemId(id), name: name, type: 'Audio');

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

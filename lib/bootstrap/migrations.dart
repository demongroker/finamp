import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

final _log = Logger("Migrations");

/// The current data/schema migration version.
///
/// Version 1 = the batch of seven settings migrations that shipped in
/// JellyAmp 1.0 (extracted verbatim into this file during P0.4). Each of those
/// seven is represented as its own ordered [MigrationStep] advancing the
/// version by one (target versions 1..7), so a mid-batch failure recovers
/// precisely to the last fully-applied step instead of re-running the whole
/// batch.
///
/// Future migrations that change persisted state APPEND a new step (or a new
/// version's worth of steps) and bump [currentDataVersion] accordingly. Never
/// reorder, edit, or remove an existing step — existing installs would re-run
/// or skip steps differently.
const int currentDataVersion = 7;

/// Hive box/key that persist the highest fully-applied migration version.
/// Written only after a step has fully succeeded, so the runner is both
/// idempotent across launches and recoverable after a mid-batch failure.
const String _migrationVersionBox = "MigrationVersion";
const String _migrationVersionKey = "version";

/// One ordered, versioned migration step.
///
/// [targetVersion] is the version the store reaches once this step has fully
/// applied. [migrate] MUST be idempotent (safe to re-run at any point,
/// including after an earlier partial failure) and MUST NOT be destructive to
/// existing user data.
class MigrationStep {
  const MigrationStep({required this.targetVersion, required this.name, required this.migrate});

  final int targetVersion;
  final String name;
  final Future<void> Function() migrate;
}

/// Ordered list of every migration ever shipped. APPEND ONLY.
///
/// The seven P0.4 settings migrations map to versions 1..7 in their original
/// order (downloadLocations → sortOptions → gridSize → homescreen →
/// featureChips → deviceId → themeModeLocale). Each step's body is unchanged
/// from the pre-versioning code; only the surrounding runner is new.
final List<MigrationStep> _migrationSteps = [
  MigrationStep(targetVersion: 1, name: 'downloadLocations', migrate: () async => _migrateDownloadLocations()),
  MigrationStep(targetVersion: 2, name: 'sortOptions', migrate: () async => _migrateSortOptions()),
  MigrationStep(targetVersion: 3, name: 'gridSize', migrate: () async => _migrateGridSize()),
  MigrationStep(targetVersion: 4, name: 'homescreen', migrate: () async => _migrateHomescreen()),
  MigrationStep(targetVersion: 5, name: 'featureChips', migrate: () async => _migrateFeatureChips()),
  MigrationStep(targetVersion: 6, name: 'deviceId', migrate: () async => _migrateDeviceId()),
  MigrationStep(targetVersion: 7, name: 'themeModeLocale', migrate: _migrateThemeModeLocale),
];

/// Applies every applicable migration in order, exactly once, in a
/// failure-safe way.
///
/// Versioned   — a persistent Hive box records the highest fully-applied
///               version; steps at or below it are skipped on later launches.
/// Ordered     — steps run in [_migrationSteps] order.
/// Idempotent  — every step is individually guarded/safe to re-run, so a crash
///               mid-batch cannot double-apply or lose data on the next launch.
/// Recoverable — the version is persisted only after a step fully succeeds.
///               If any step throws, the error is rethrown so the caller
///               surfaces the fatal startup error (FinampErrorApp) instead of
///               silently continuing with half-migrated state; the next launch
///               resumes from the last fully-applied step.
Future<void> runMigrations() async {
  var storedVersion = await _readStoredVersion();
  if (storedVersion >= currentDataVersion) {
    _log.fine("Migrations already at version $storedVersion; nothing to do");
    return;
  }

  for (final step in _migrationSteps) {
    if (step.targetVersion <= storedVersion) continue;
    _log.info("Applying migration '${step.name}' (target v${step.targetVersion})");
    try {
      await step.migrate();
    } catch (e, st) {
      // Never swallow a failed migration and never continue as if it
      // succeeded: block startup so the user is not left on half-migrated
      // data. On the next launch, only the failed (un-checkpointed) step and
      // later steps re-run, safely (each step is idempotent).
      _log.severe("Migration '${step.name}' (v${step.targetVersion}) FAILED", e, st);
      rethrow;
    }
    // Checkpoint only after the step fully applied.
    storedVersion = step.targetVersion;
    await _writeStoredVersion(storedVersion);
    _log.info("Migration '${step.name}' complete (v$storedVersion)");
  }
}

Future<int> _readStoredVersion() async {
  final box = await Hive.openBox<int>(_migrationVersionBox);
  return box.get(_migrationVersionKey, defaultValue: 0) ?? 0;
}

Future<void> _writeStoredVersion(int version) async {
  final box = await Hive.openBox<int>(_migrationVersionBox);
  await box.put(_migrationVersionKey, version);
}

/// Migrates the old DownloadLocations list to a map
void _migrateDownloadLocations() {
  final finampSettings = FinampSettingsHelper.finampSettings;

  // ignore: deprecated_member_use_from_same_package
  if (finampSettings.downloadLocations.isNotEmpty) {
    final Map<String, DownloadLocation> newMap = {};

    // ignore: deprecated_member_use_from_same_package
    for (var element in finampSettings.downloadLocations) {
      // Generate a UUID and set the ID field for the DownloadsLocation
      final id = const Uuid().v4();
      element.id = id;
      newMap[id] = element;
    }

    finampSettings.downloadLocationsMap = newMap;

    // ignore: deprecated_member_use_from_same_package
    finampSettings.downloadLocations = List.empty();

    FinampSettingsHelper.overwriteFinampSettings(finampSettings);
  }
}

/// True when home layout matches the previous cluttered Jellyamp/stock default
/// (4 actions + 7 sections). Used for one-shot upgrade to the clean layout.
bool _isLegacyClutteredHomeLayout(FinampHomeScreenConfiguration config) {
  final legacy = DefaultSettings.homeScreenConfigurationLegacyCluttered;
  if (config.sections.length != legacy.sections.length) return false;
  if (config.actions.length != legacy.actions.length) return false;
  for (var i = 0; i < legacy.sections.length; i++) {
    if (config.sections[i].presetType != legacy.sections[i].presetType) return false;
  }
  for (var i = 0; i < legacy.actions.length; i++) {
    if (config.actions[i].action != legacy.actions[i].action) return false;
  }
  return true;
}

/// Migrates defaults for the home screen (e.g. add home screen tab)
void _migrateHomescreen() {
  final finampSettings = FinampSettingsHelper.finampSettings;

  var changed = false;

  // Jellyamp UI polish: auto-upgrade cluttered stock home → clean 3-action / 4-section layout.
  // Only when the user still has the exact legacy default (customized homes are left alone).
  if (_isLegacyClutteredHomeLayout(finampSettings.homeScreenConfiguration)) {
    finampSettings.homeScreenConfiguration = DefaultSettings.homeScreenConfiguration;
    changed = true;
  }

  if (!finampSettings.tabOrder.contains(ContentType.home)) {
    finampSettings.tabOrder = [ContentType.home, ...finampSettings.tabOrder.whereNot((e) => e == ContentType.home)];
    finampSettings.showTabs[ContentType.home] = true;

    // we set this here because it's a non-constant value
    finampSettings.homeScreenConfiguration = DefaultSettings.homeScreenConfiguration;

    changed = true;
  }

  if (!finampSettings.tabOrder.contains(ContentType.albumArtists)) {
    finampSettings.tabOrder.add(ContentType.albumArtists);

    changed = true;
  }

  if (!finampSettings.tabOrder.contains(ContentType.performingArtists)) {
    finampSettings.tabOrder.add(ContentType.performingArtists);

    changed = true;
  }

  if (!finampSettings.tabSortBy.keys.contains(ContentType.performingArtists)) {
    finampSettings.tabSortBy[ContentType.performingArtists] =
        finampSettings.tabSortBy[ContentType.genericArtists] ?? SortAndFilterConfiguration.defaultSort.sortBy;
    finampSettings.tabSortOrder[ContentType.performingArtists] =
        finampSettings.tabSortOrder[ContentType.genericArtists] ?? SortAndFilterConfiguration.defaultSort.sortOrder;
    finampSettings.tabSortBy[ContentType.albumArtists] =
        finampSettings.tabSortBy[ContentType.genericArtists] ?? SortAndFilterConfiguration.defaultSort.sortBy;
    finampSettings.tabSortOrder[ContentType.albumArtists] =
        finampSettings.tabSortOrder[ContentType.genericArtists] ?? SortAndFilterConfiguration.defaultSort.sortOrder;
    changed = true;
  }

  if (!finampSettings.tabSortBy.keys.contains(ContentType.inPlaylist)) {
    finampSettings.tabSortBy[ContentType.inPlaylist] =
        finampSettings.playlistTracksSortBy ?? SortAndFilterConfiguration.defaultInAlbumSort.sortBy;
    finampSettings.tabSortOrder[ContentType.inPlaylist] =
        finampSettings.playlistTracksSortOrder ?? SortAndFilterConfiguration.defaultInAlbumSort.sortOrder;
    changed = true;
  }

  for (int i = 0; i < finampSettings.homeScreenConfiguration.sections.length; i++) {
    final section = finampSettings.homeScreenConfiguration.sections[i];
    if (section.presetType == HomeScreenSectionPresetType.recentlyAddedAlbums) {
      if (section.base case TabsHomeSection base when base.libraryId == allLibraryPlaceholder) {
        // We do not preserve the preset value on modified configs, so this section is still default and can be reset.
        finampSettings.homeScreenConfiguration.sections[i] = HomeScreenSectionConfiguration.fromPreset(
          HomeScreenSectionPresetType.recentlyAddedAlbums,
        );
        changed = true;
      }
    }
    if (section.presetType == HomeScreenSectionPresetType.frequentlyPlayedAlbums) {
      finampSettings.homeScreenConfiguration.sections[i] = HomeScreenSectionConfiguration.fromPreset(
        HomeScreenSectionPresetType.favoriteAlbums,
      );
      changed = true;
    } else if (section.presetType == HomeScreenSectionPresetType.frequentlyPlayedArtists) {
      finampSettings.homeScreenConfiguration.sections[i] = HomeScreenSectionConfiguration.fromPreset(
        HomeScreenSectionPresetType.randomAlbumArtists,
      );
      changed = true;
    } else if (section.presetType == HomeScreenSectionPresetType.neverPlayedAlbums) {
      finampSettings.homeScreenConfiguration.sections[i] = HomeScreenSectionConfiguration.fromPreset(
        HomeScreenSectionPresetType.randomAlbums,
      );
      changed = true;
    }
  }

  for (int i = 0; i < finampSettings.homeScreenConfiguration.actions.length; i++) {
    final action = finampSettings.homeScreenConfiguration.actions[i];
    if (action.action == FinampQuickActions.playRandomAlbum) {
      finampSettings.homeScreenConfiguration.actions[i] = QuickActionConfig(
        action: FinampQuickActions.playRandomItem,
        itemTypes: {ContentType.albums},
      );
      changed = true;
    } else if (action.action == FinampQuickActions.playRandomTrack) {
      finampSettings.homeScreenConfiguration.actions[i] = QuickActionConfig(
        action: FinampQuickActions.playRandomItem,
        itemTypes: {ContentType.tracks},
      );
      changed = true;
    } else if (action.action == FinampQuickActions.playRandomFavoriteItem) {
      if (action.itemTypes?.isEmpty ?? true) {
        finampSettings.homeScreenConfiguration.actions[i] = QuickActionConfig(
          action: FinampQuickActions.playRandomFavoriteItem,
          itemTypes: {
            ContentType.tracks,
            ContentType.albums,
            ContentType.performingArtists,
            ContentType.albumArtists,
            ContentType.playlists,
            ContentType.genres,
          },
        );
        changed = true;
      }
    }
  }

  if (changed) {
    FinampSettingsHelper.overwriteFinampSettings(finampSettings);
  }
}

void _migrateFeatureChips() {
  if (!FinampSettingsHelper.finampSettings.featureChipsConfiguration.migrated) {
    FinampSetters.setFeatureChipsConfiguration(
      FinampFeatureChipsConfiguration(
        enabled: FinampSettingsHelper.finampSettings.featureChipsConfiguration.enabled,
        features: DefaultSettings.featureChipsConfiguration.features,
        migrated: true,
      ),
    );
  }
}

/// Migrates the old SortBy/SortOrder to a map indexed by tab content type
// ignore: deprecated_member_use_from_same_package
void _migrateSortOptions() {
  final finampSettings = FinampSettingsHelper.finampSettings;

  var changed = false;

  if (finampSettings.tabSortBy.isEmpty && finampSettings.sortBy != null) {
    for (var type in ContentType.values.where((x) => x.isTab)) {
      finampSettings.tabSortBy[type] = finampSettings.sortBy!;
    }
    changed = true;
  }

  if (finampSettings.tabSortOrder.isEmpty && finampSettings.sortOrder != null) {
    for (var type in ContentType.values.where((x) => x.isTab)) {
      finampSettings.tabSortOrder[type] = finampSettings.sortOrder!;
    }
    changed = true;
  }

  if (changed) {
    FinampSettingsHelper.overwriteFinampSettings(finampSettings);
  }
}

/// Migrates old grid size options to FinampSettings.gridImageSize
// ignore: deprecated_member_use_from_same_package
void _migrateGridSize() {
  final finampSettings = FinampSettingsHelper.finampSettings;
  // Use this bool being null as a flag to skip migration
  if (finampSettings.useFixedSizeGridTiles == null) return;
  if (finampSettings.useFixedSizeGridTiles!) {
    finampSettings.gridImageSize = finampSettings.fixedGridTileSize!;
  } else {
    finampSettings.gridImageSize = _calculateGridImageSize(finampSettings);
  }
  finampSettings.useFixedSizeGridTiles = null;
  FinampSettingsHelper.overwriteFinampSettings(finampSettings);
}

/// Predicts the grid item size based off legacy settings and current device screen size
int _calculateGridImageSize(FinampSettings settings) {
  Size? screenSize;
  if (Platform.isAndroid || Platform.isIOS) {
    final view = PlatformDispatcher.instance.implicitView!;
    final physicalSize = view.physicalSize;
    // If we are in landscape, this padding might not necessarily match what it would be in portrait.  But whatever.
    final padding = view.viewPadding;
    screenSize = Size(
      physicalSize.width - padding.left - padding.right,
      physicalSize.height - padding.top - padding.bottom,
    );
    screenSize = screenSize / view.devicePixelRatio;
  } else {
    final fullScreenSize = settings.screenSize?.size;
    // screenSize setting is external bounds of window.  We need the internal view size, but that isn't available yet,
    // so we just subtract off the window decorations.  These values are for windows, but hopefully mac/linux are relatively similar.
    screenSize = fullScreenSize == null ? null : Size(fullScreenSize.width - 16, fullScreenSize.height - 39);
  }

  if (screenSize == null || screenSize.width <= 0 || screenSize.height <= 0) {
    // Screen size failed to load for some reason, just reset to default
    return DefaultSettings.gridImageSize;
  } else {
    int targetCount;
    double totalSize;
    // Making the migration hinge on the devices current orientation seems questionable, so we attempt to guess the primary layout here.
    // If this device would go into splitscreen in landscape, we will assume that is the primary orientation.
    // Otherwise, we assume the primary orientation is portrait.

    // Normalize to landscape for easier tablet calculations
    screenSize = Size(max(screenSize.height, screenSize.width), min(screenSize.height, screenSize.width));
    if (screenSize.width >= 800 && screenSize.height >= 500 && settings.allowSplitScreen) {
      totalSize = screenSize.width - settings.splitScreenPlayerWidth - 10;
      if (totalSize > screenSize.height) {
        targetCount = settings.contentGridViewCrossAxisCountLandscape!;
      } else {
        targetCount = settings.contentGridViewCrossAxisCountPortrait!;
      }
    } else {
      // This will always be the devices smallest side
      totalSize = screenSize.height;
      targetCount = settings.contentGridViewCrossAxisCountPortrait!;
    }
    if (targetCount < 1 || totalSize < 200) {
      // Something fishy is going on in the sizing calculations.  Reset to default.
      return DefaultSettings.gridImageSize;
    }
    if (settings.showFastScroller) {
      totalSize -= 22;
    }
    // Account for xtra padding added to left of grid.  This could theoretically be smaller, but that shouldn't matter much.
    totalSize -= 10;
    return (totalSize / targetCount).round().clamp(50, 1000);
  }
}

/// Migrates the old ThemeMode and Locale Hive box values to FinampSettings fields
Future<void> _migrateThemeModeLocale() async {
  if (!FinampSettingsHelper.finampSettings.hasCompletedThemeModeLocaleMigration) {
    Box<ThemeMode> oldThemeModeBox = await Hive.openBox<ThemeMode>("ThemeMode");
    Box<Locale?> oldLocaleBox = await Hive.openBox<Locale?>("Locale");

    var oldThemeMode = oldThemeModeBox.get("ThemeMode");
    var oldLocale = oldLocaleBox.get("Locale");

    FinampSetters.setThemeMode(oldThemeMode ?? ThemeMode.system);
    FinampSetters.setLocale(oldLocale);

    await oldThemeModeBox.deleteFromDisk();
    await oldLocaleBox.deleteFromDisk();

    FinampSetters.setHasCompletedThemeModeLocaleMigration(true);
  }
}

/// Migrates to the new randomly-generated device ID and stores it
void _migrateDeviceId() {
  if (FinampSettingsHelper.finampSettings.deviceId == "unset") {
    FinampSetters.setDeviceId(const Uuid().v4());
  }
}

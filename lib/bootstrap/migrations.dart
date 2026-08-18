import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:uuid/uuid.dart';

/// Runs every applicable settings migration in the exact order the original
/// `main.dart` ran them.
///
/// P0.4: extracted from `main.dart` (was the sequence of `_migrate*` calls).
/// Order and behavior are unchanged.
Future<void> runMigrations() async {
  _migrateDownloadLocations();
  _migrateSortOptions();
  _migrateGridSize();
  _migrateHomescreen();
  _migrateFeatureChips();
  _migrateDeviceId();
  await _migrateThemeModeLocale();
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

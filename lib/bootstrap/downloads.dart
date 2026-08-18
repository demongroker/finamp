import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/downloads_service_backend.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../components/global_snackbar.dart';

final _downloadsLog = Logger("Main()");

/// Sets up the download locations, the [DownloadsService] (including the Hive
/// migration and file-owner repair), the background downloader, and starts the
/// download queues.
///
/// P0.4: extracted from `main.dart` (was `_setupDownloadsHelper`).
Future<void> setupDownloadsHelper() async {
  await Future.wait(
    FinampSettingsHelper.finampSettings.downloadLocationsMap.values.map((element) => element.updateCurrentPath()),
  );
  final fileDownloader = FileDownloader(persistentStorage: IsarPersistentStorage());
  await fileDownloader.ready;
  WidgetsFlutterBinding.ensureInitialized();
  // There is additional FileDownloader setup inside downloadsService constructor
  GetIt.instance.registerSingleton(DownloadsService());
  final downloadsService = GetIt.instance<DownloadsService>();

  if (!FinampSettingsHelper.finampSettings.hasCompletedDownloadsServiceMigration) {
    await downloadsService.migrateFromHive();
    FinampSetters.setHasCompletedDownloadsServiceMigration(true);
  } else {
    // Some users may have missed migration due to a bug in the flag setting and
    // are therefore missing an internal directory
    if (FinampSettingsHelper.finampSettings.downloadLocationsMap.values
        .where((element) => element.baseDirectory == DownloadLocationType.platformDefaultDirectory)
        .isEmpty) {
      _downloadsLog.info("Internal Storage download location is missing.  Recreating.");
      final downloadLocation = await DownloadLocation.create(
        name: DownloadLocation.internalStorageName,
        baseDirectory: DownloadLocationType.platformDefaultDirectory,
      );
      FinampSettingsHelper.addDownloadLocation(downloadLocation);
      // There may be old downloads present due to skipping the migration
      // Run a repair to make sure they all get cleaned up.
      unawaited(downloadsService.repairAllDownloads().then((value) => null, onError: GlobalSnackbar.error));
    }
  }

  await migrateDownloadsFileOwner();

  await fileDownloader.configure(globalConfig: (Config.checkAvailableSpace, 1024));
  await fileDownloader.resumeFromBackground();
  await downloadsService.startQueues();

  if (!FinampSettingsHelper.finampSettings.hasDownloadedPlaylistInfo) {
    GetIt.instance<FinampUserHelper>().runUserHook(() async {
      await downloadsService.addDefaultPlaylistInfoDownload().catchError((Object e) {
        // log error without snackbar, we don't want users to be greeted with errors on first launch
        _downloadsLog.severe("Failed to download playlist metadata: $e");
      });
      FinampSetters.setHasDownloadedPlaylistInfo(true);
    });
  }
}

/// Runs the Android-only download file-owner migration.
///
/// P0.4: extracted from `main.dart` (was `_migrateDownloadsFileOwner`).
Future<void> migrateDownloadsFileOwner() async {
  if (!Platform.isAndroid) {
    // Only Android needs this migration
    return;
  }
  if (!FinampSettingsHelper.finampSettings.hasCompletedDownloadsFileOwnerMigration) {
    var downloadsServiceChannel = MethodChannel("com.unicornsonlsd.finamp/downloads_service");
    var downloadLocations = FinampSettingsHelper.finampSettings.downloadLocationsMap;
    var downloadPaths = downloadLocations.values.map((e) => e.currentPath).toList();
    await downloadsServiceChannel.invokeMethod("fixDownloadsFileOwner", <String, dynamic>{
      'download_locations': downloadPaths,
    });
    FinampSetters.setHasCompletedDownloadsFileOwnerMigration(true);
  }
}

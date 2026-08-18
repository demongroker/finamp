import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/offline_listen_helper.dart';
import 'package:get_it/get_it.dart';

/// Registers the [JellyfinApiHelper] singleton.
///
/// P0.4: extracted from `main.dart` (was `_setupJellyfinApiData`).
Future<void> setupJellyfinApiData() async {
  GetIt.instance.registerSingleton(JellyfinApiHelper());
}

/// Registers the [FinampUserHelper] and performs the Isar user migration,
/// auth-token hydration and auth-header setup.
///
/// P0.4: extracted from `main.dart` (was `_setupFinampUserHelper`).
Future<void> setupFinampUserHelper() async {
  GetIt.instance.registerSingleton(FinampUserHelper(deviceId: FinampSettingsHelper.finampSettings.deviceId));
  if (!FinampSettingsHelper.finampSettings.hasCompletedIsarUserMigration) {
    await GetIt.instance<FinampUserHelper>().migrateFromHive();
    FinampSetters.setHasCompletedIsarUserMigration(true);
  }
  await GetIt.instance<FinampUserHelper>().hydrateAccessTokens();
  await GetIt.instance<FinampUserHelper>().setAuthHeader();
}

/// Registers the [OfflineListenLogHelper] singleton.
///
/// P0.4: extracted from `main.dart` (was `_setupOfflineListenLogHelper`).
void setupOfflineListenLogHelper() {
  GetIt.instance.registerSingleton(OfflineListenLogHelper());
}

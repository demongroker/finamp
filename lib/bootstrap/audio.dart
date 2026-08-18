import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/android_auto_helper.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:finamp/services/audio_service_smtc.dart';
import 'package:finamp/services/carplay_helper.dart';
import 'package:finamp/services/discord_rpc.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/playback_history_service.dart';
import 'package:finamp/services/playon_service.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:get_it/get_it.dart';

import '../components/global_snackbar.dart';

/// Initialises the audio service (audio_handler, queue, playback history),
/// CarPlay (iOS), Windows SMTC, and begins restoring the queue.
///
/// P0.4: extracted from `main.dart` (was `_setupPlaybackServices`).
Future<void> setupPlaybackServices() async {
  if (Platform.isWindows) {
    AudioServiceSMTC.registerWith();
  }

  await MusicPlayerBackgroundTask.configureAudioSession();

  GetIt.instance.registerSingleton<AndroidAutoHelper>(AndroidAutoHelper());

  final audioHandler = await AudioService.init(
    builder: () => MusicPlayerBackgroundTask(),
    config: AudioServiceConfig(
      androidStopForegroundOnPause: FinampSettingsHelper.finampSettings.androidStopForegroundOnPause,
      androidNotificationChannelName: "Jellyamp",
      androidNotificationIcon: "mipmap/white",
      androidNotificationChannelId: "com.demongroker.jellyamp.audio",
      // notificationColor: TODO use the theme color for older versions of Android,
      // We will handle preloading artwork ourselves
      preloadArtwork: false,
      androidBrowsableRootExtras: <String, dynamic>{
        // support showing search button on Android Auto as well as alternative search results on the player screen after voice search
        "android.media.browse.SEARCH_SUPPORTED": true,
        // see https://developer.android.com/reference/androidx/media/utils/MediaConstants#DESCRIPTION_EXTRAS_VALUE_CONTENT_STYLE_GRID_ITEM()
        "android.media.browse.CONTENT_STYLE_BROWSABLE_HINT":
            FinampSettingsHelper.finampSettings.contentViewType == ContentViewType.list ? 1 : 2,
        "android.media.browse.CONTENT_STYLE_PLAYABLE_HINT":
            FinampSettingsHelper.finampSettings.contentViewType == ContentViewType.list ? 1 : 2,
      },
    ),
    cacheManager: StubImageCache(),
  );

  GetIt.instance.registerSingleton<MusicPlayerBackgroundTask>(audioHandler);
  var queueService = QueueService();
  GetIt.instance.registerSingleton(queueService);
  audioHandler.onQueueServiceAvailable(); // breaking circular dependency
  GetIt.instance.registerSingleton(PlaybackHistoryService());
  GetIt.instance.registerSingleton(AudioServiceHelper());

  if (Platform.isIOS) {
    GetIt.instance.registerSingleton<CarPlayHelper>(CarPlayHelper());
  }

  // Begin to restore queue
  unawaited(queueService.performInitialQueueLoad().catchError((dynamic x) => GlobalSnackbar.error(x)));
}

/// Registers the [PlayOnService] and initialises it once the user helper is
/// available.
///
/// P0.4: extracted from `main.dart` (was `_setupPlayOnService`).
Future<void> setupPlayOnService() async {
  final playOnService = PlayOnService();
  GetIt.instance.registerSingleton(playOnService);
  GetIt.instance<FinampUserHelper>().runUserHook(playOnService.initialize);
}

/// Initialises Discord rich presence.
///
/// P0.4: extracted from `main.dart` (was `_setupDiscordRpc`).
Future<void> setupDiscordRpc() async {
  DiscordRpc.initialize();
}

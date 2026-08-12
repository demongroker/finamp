import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:get_it/get_it.dart';

/// Small seek helpers used by player gestures (long-press skip, album-art zones).
///
/// Intervals match desktop keyboard shortcuts:
/// - forward: +30s
/// - backward: -10s (or to start if near the beginning)
class PlaybackSeekHelper {
  PlaybackSeekHelper._();

  static const Duration forwardInterval = Duration(seconds: 30);
  static const Duration backwardInterval = Duration(seconds: 10);

  static MusicPlayerBackgroundTask get _audio => GetIt.instance<MusicPlayerBackgroundTask>();

  static Future<void> seekForward({Duration interval = forwardInterval}) async {
    final audio = _audio;
    final current = audio.playbackPosition;
    final duration = audio.mediaItem.valueOrNull?.duration;
    var target = current + interval;
    if (duration != null && target > duration) {
      target = duration;
    }
    FeedbackHelper.feedback(FeedbackType.selection);
    await audio.seek(target);
  }

  static Future<void> seekBackward({Duration interval = backwardInterval}) async {
    final audio = _audio;
    final current = audio.playbackPosition;
    final target = current <= interval ? Duration.zero : current - interval;
    FeedbackHelper.feedback(FeedbackType.selection);
    await audio.seek(target);
  }
}

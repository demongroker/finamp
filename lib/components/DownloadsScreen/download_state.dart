import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../models/finamp_models.dart';

/// Renders the real per-download state as a small localized label.
///
/// P0.2 step 7: replaces the generic "Downloading…" placeholder with the actual
/// state machine state (queued/downloading/paused/failed/stale/complete) so users
/// can see what each download is really doing.  Pure display helper — the state
/// comes from the authoritative [DownloadItemState] via `stateProvider`.
class DownloadStateLabel extends StatelessWidget {
  const DownloadStateLabel({super.key, required this.state, this.style});

  final DownloadItemState? state;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = downloadStateLabel(context, state);
    if (text == null) {
      return const SizedBox.shrink();
    }
    return Text(text, style: style ?? TextStyle(color: downloadStateColor(state)));
  }
}

/// Localized short label for a download state.  Returns null for states that
/// should render nothing (not downloaded / unknown).
String? downloadStateLabel(BuildContext context, DownloadItemState? state) {
  final l10n = AppLocalizations.of(context)!;
  return switch (state) {
    DownloadItemState.enqueued => l10n.downloadStateQueued,
    DownloadItemState.downloading => l10n.downloadStateDownloading,
    DownloadItemState.paused => l10n.downloadStatePaused,
    DownloadItemState.failed || DownloadItemState.syncFailed => l10n.downloadStateFailed,
    DownloadItemState.needsRedownload || DownloadItemState.needsRedownloadComplete => l10n.downloadStateStale,
    DownloadItemState.complete => l10n.downloadStateComplete,
    DownloadItemState.notDownloaded || null => null,
  };
}

/// Accent color used to distinguish a download state in the list.
Color? downloadStateColor(DownloadItemState? state) {
  return switch (state) {
    DownloadItemState.downloading => Colors.blue,
    DownloadItemState.enqueued => Colors.grey,
    DownloadItemState.paused => Colors.orange,
    DownloadItemState.failed || DownloadItemState.syncFailed => Colors.red,
    DownloadItemState.needsRedownload || DownloadItemState.needsRedownloadComplete => Colors.orange,
    DownloadItemState.complete => Colors.green,
    DownloadItemState.notDownloaded || null => null,
  };
}

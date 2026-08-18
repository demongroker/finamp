import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../services/downloads_service.dart';

/// Per-download state controls wired to the step-6 download manager service API.
///
/// Shows only the actions that make sense for the item's current authoritative
/// state (from [DownloadsService.stateProvider]):
///   - downloading -> Pause, Cancel (cancel keeps any already-downloaded file)
///   - enqueued    -> Cancel
///   - paused      -> Resume, Cancel
/// Remove (deleteDownload) is intentionally NOT here — that is the user's explicit
/// "remove download" intent and lives with the existing delete affordance so the
/// DOWNLOADED != CACHED ownership contract stays explicit.
class DownloadActions extends ConsumerWidget {
  const DownloadActions({super.key, required this.stub});

  final DownloadStub stub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsService = GetIt.instance<DownloadsService>();
    final state = ref.watch(downloadsService.stateProvider(stub)).value;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state == DownloadItemState.downloading)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: l10n.pauseDownload,
            icon: const Icon(Icons.pause, size: 20),
            onPressed: () => downloadsService.pauseDownload(stub),
          ),
        if (state == DownloadItemState.paused)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: l10n.resumeDownload,
            icon: const Icon(Icons.play_arrow, size: 20),
            onPressed: () => downloadsService.resumeDownload(stub),
          ),
        if (state == DownloadItemState.downloading ||
            state == DownloadItemState.enqueued ||
            state == DownloadItemState.paused)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: l10n.cancelDownload,
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => downloadsService.cancelDownload(stub),
          ),
      ],
    );
  }
}

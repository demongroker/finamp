import 'package:file_sizes/file_sizes.dart';
import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../services/downloads_service.dart';
import '../../services/process_artist.dart';
import '../album_image.dart';

class DownloadErrorListTile extends ConsumerWidget {
  const DownloadErrorListTile({super.key, required this.downloadTask, required this.showType});

  final DownloadStub downloadTask;
  final bool showType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsService = GetIt.instance<DownloadsService>();
    final progress = ref.watch(downloadsService.progressProvider(downloadTask)).valueOrNull;
    final l10n = AppLocalizations.of(context)!;
    final artist = showType
        ? l10n.itemTypeSubtitle(downloadTask.baseItemType.name, "")
        : processArtist(downloadTask.baseItem?.albumArtist, context);
    String? progressLabel;
    double? fraction;
    if (progress?.percent != null && progress!.hasSize) {
      progressLabel = l10n.downloadProgressBytes(
        progress.percent!,
        FileSize.getSize(progress.receivedBytes),
        FileSize.getSize(progress.expectedFileSize),
      );
      fraction = progress.progress.clamp(0.0, 1.0);
    } else if (progress?.percent != null) {
      progressLabel = l10n.downloadProgressPercent(progress!.percent!);
      fraction = progress.progress.clamp(0.0, 1.0);
    }

    return ListTile(
      leading: AlbumImage(item: downloadTask.baseItem),
      title: Text(downloadTask.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(artist),
          if (progressLabel != null) ...[
            const SizedBox(height: 4),
            Text(progressLabel),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: fraction),
          ],
        ],
      ),
    );
  }
}

import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/radio_service_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

class ClearAfterCurrentMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  const ClearAfterCurrentMenuEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return MenuEntry(
      icon: TablerIcons.arrow_bar_to_down,
      title: AppLocalizations.of(context)!.clearAfterCurrent,
      onTap: () async {
        if (context.mounted) Navigator.pop(context);
        await withRadioLock(() async {
          await queueService.clearAfterCurrent();
        });
      },
    );
  }

  @override
  bool get isVisible => true;
}

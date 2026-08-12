import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/media_share_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// Copy a human-readable line (e.g. `Artist — Title`) for the item.
class CopyItemInfoMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final BaseItemDto baseItem;

  const CopyItemInfoMenuEntry({super.key, required this.baseItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuEntry(
      icon: TablerIcons.copy,
      title: AppLocalizations.of(context)!.copyItemInfo,
      tooltip: AppLocalizations.of(context)!.copyItemInfoTooltip,
      onTap: () async {
        await MediaShareHelper.copyItemInfo(baseItem);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  @override
  bool get isVisible => true;
}

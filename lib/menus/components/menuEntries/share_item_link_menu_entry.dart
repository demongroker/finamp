import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/media_share_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// Share a Jellyfin library item (system share sheet with name + web link).
class ShareItemLinkMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final BaseItemDto baseItem;

  const ShareItemLinkMenuEntry({super.key, required this.baseItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(finampSettingsProvider.isOffline);

    return Visibility(
      visible: !offline,
      child: MenuEntry(
        icon: TablerIcons.share_2,
        title: AppLocalizations.of(context)!.shareItemLink,
        tooltip: AppLocalizations.of(context)!.shareItemLinkTooltip,
        onTap: () async {
          await MediaShareHelper.shareItem(baseItem);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  bool get isVisible => !FinampSettingsHelper.finampSettings.isOffline;
}

/// Copy the Jellyfin web details URL for an item.
class CopyItemLinkMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final BaseItemDto baseItem;

  const CopyItemLinkMenuEntry({super.key, required this.baseItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(finampSettingsProvider.isOffline);

    return Visibility(
      visible: !offline,
      child: MenuEntry(
        icon: TablerIcons.link,
        title: AppLocalizations.of(context)!.copyItemLink,
        tooltip: AppLocalizations.of(context)!.copyItemLinkTooltip,
        onTap: () async {
          await MediaShareHelper.copyItemLink(baseItem);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  bool get isVisible => !FinampSettingsHelper.finampSettings.isOffline;
}

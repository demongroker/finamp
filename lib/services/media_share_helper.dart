import 'package:clipboard/clipboard.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';

/// Helpers for sharing Jellyfin library items (web deep links + plain-text metadata).
class MediaShareHelper {
  MediaShareHelper._();

  /// Build a Jellyfin web UI details URL for [item].
  ///
  /// Uses the modern hash route (`/web/#/details?id=...`) supported by Jellyfin 10.8+.
  static String? jellyfinDetailsUrl(BaseItemDto item) {
    final user = GetIt.instance<FinampUserHelper>().currentUser;
    if (user == null) return null;

    final base = user.baseURL.replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return null;

    return '$base/web/#/details?id=${item.id.raw}';
  }

  /// Human-readable one-liner: `Artist — Title` for tracks, otherwise the item name.
  static String itemDisplayLine(BaseItemDto item) {
    final name = item.name?.trim();
    final artists = item.artists?.where((a) => a.trim().isNotEmpty).toList();
    if (artists != null && artists.isNotEmpty && name != null && name.isNotEmpty) {
      return '${artists.join(', ')} — $name';
    }
    if (name != null && name.isNotEmpty) return name;
    if (item.albumArtist != null && item.albumArtist!.trim().isNotEmpty) {
      return item.albumArtist!.trim();
    }
    return item.id.raw;
  }

  /// Share sheet with name + optional Jellyfin web link.
  static Future<void> shareItem(BaseItemDto item) async {
    final line = itemDisplayLine(item);
    final url = jellyfinDetailsUrl(item);
    final text = url == null ? line : '$line\n$url';

    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: line));
    } catch (e) {
      GlobalSnackbar.error(e);
    }
  }

  /// Copy Jellyfin web details URL to the clipboard.
  static Future<void> copyItemLink(BaseItemDto item) async {
    final url = jellyfinDetailsUrl(item);
    if (url == null) {
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareItemNoServer);
      return;
    }

    try {
      await FlutterClipboard.copy(url);
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareItemLinkCopied);
    } catch (e) {
      GlobalSnackbar.error(e);
    }
  }

  /// Copy `Artist — Title` (or name) to the clipboard.
  static Future<void> copyItemInfo(BaseItemDto item) async {
    final line = itemDisplayLine(item);
    try {
      await FlutterClipboard.copy(line);
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.copyItemInfoCopied);
    } catch (e) {
      GlobalSnackbar.error(e);
    }
  }
}

import 'dart:async';
import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final _log = Logger("AppShareHelper");

/// Share the Jellyamp APK via the system share sheet, or serve it on the LAN.
class AppShareHelper {
  AppShareHelper._();

  static const _channel = MethodChannel('com.unicornsonlsd.finamp/app_share');
  static const defaultPort = 8765;

  static HttpServer? _server;
  static String? _servingPath;
  static int? _servingPort;

  static bool get isServerRunning => _server != null;
  static int? get serverPort => _servingPort;

  /// Absolute path to the installed APK on Android (`ApplicationInfo.sourceDir`).
  static Future<String?> getInstalledApkPath() async {
    if (!Platform.isAndroid) return null;
    try {
      final path = await _channel.invokeMethod<String>('getInstalledApkPath');
      if (path != null && path.isNotEmpty && await File(path).exists()) {
        return path;
      }
    } catch (e, st) {
      _log.warning("getInstalledApkPath failed", e, st);
    }
    return null;
  }

  /// Copy the installed APK to a cache file with a friendly name for sharing.
  static Future<File?> prepareShareableApkFile() async {
    final sourcePath = await getInstalledApkPath();
    if (sourcePath == null) return null;

    final cache = await getTemporaryDirectory();
    final out = File(path_helper.join(cache.path, 'jellyamp_share', 'Jellyamp.apk'));
    await out.parent.create(recursive: true);

    final source = File(sourcePath);
    // Always refresh copy so updates are reflected
    await source.copy(out.path);
    return out;
  }

  /// Open the system share sheet with the Jellyamp APK.
  static Future<void> shareApkFile() async {
    try {
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkPreparing);
      final file = await prepareShareableApkFile();
      if (file == null) {
        GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkUnavailable);
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/vnd.android.package-archive', name: 'Jellyamp.apk')],
          text: 'Jellyamp — Jellyfin music player',
          subject: 'Jellyamp.apk',
        ),
      );
    } catch (e, st) {
      _log.severe("shareApkFile failed", e, st);
      GlobalSnackbar.error(e);
    }
  }

  /// Start (or restart) a tiny HTTP server serving the APK on [port].
  ///
  /// Returns a multi-line string of download URLs (one per local IPv4), or null on failure.
  static Future<String?> startLocalApkServer({int port = defaultPort}) async {
    await stopLocalApkServer();

    final file = await prepareShareableApkFile();
    if (file == null) {
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkUnavailable);
      return null;
    }

    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server = server;
      _servingPath = file.path;
      _servingPort = port;

      unawaited(
        server.forEach((request) async {
          try {
            if (request.method != 'GET') {
              request.response.statusCode = HttpStatus.methodNotAllowed;
              await request.response.close();
              return;
            }

            final path = request.uri.path;
            if (path == '/' || path == '/Jellyamp.apk' || path.endsWith('.apk')) {
              final apk = File(_servingPath!);
              final length = await apk.length();
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.contentType = ContentType(
                'application',
                'vnd.android.package-archive',
              );
              request.response.headers.set('Content-Length', length);
              request.response.headers.set(
                'Content-Disposition',
                'attachment; filename="Jellyamp.apk"',
              );
              await request.response.addStream(apk.openRead());
            } else {
              // Simple landing page
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.contentType = ContentType.html;
              request.response.write(
                '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width">'
                '<title>Jellyamp</title></head><body style="font-family:sans-serif;padding:2rem">'
                '<h1>Jellyamp</h1>'
                '<p><a href="/Jellyamp.apk">Download Jellyamp.apk</a></p>'
                '</body></html>',
              );
            }
          } catch (e, st) {
            _log.warning("APK server request error", e, st);
          } finally {
            try {
              await request.response.close();
            } catch (_) {}
          }
        }),
      );

      final urls = await _localHttpUrls(port);
      final message = urls.join('\n');
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkServerStarted(port.toString()));
      return message;
    } catch (e, st) {
      _log.severe("startLocalApkServer failed", e, st);
      GlobalSnackbar.error(e);
      return null;
    }
  }

  static Future<void> stopLocalApkServer() async {
    final s = _server;
    _server = null;
    _servingPath = null;
    _servingPort = null;
    if (s != null) {
      await s.close(force: true);
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkServerStopped);
    }
  }

  /// Copy LAN download URLs to clipboard (starts server if needed).
  static Future<void> copyLocalApkUrls({int port = defaultPort}) async {
    if (!isServerRunning) {
      final urls = await startLocalApkServer(port: port);
      if (urls == null) return;
      await FlutterClipboard.copy(urls);
    } else {
      final urls = (await _localHttpUrls(_servingPort ?? port)).join('\n');
      await FlutterClipboard.copy(urls);
    }
    GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkUrlsCopied);
  }

  static Future<List<String>> _localHttpUrls(int port) async {
    final ips = <String>[];
    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      )) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          // Skip common docker/bridge ranges for cleaner UX
          final ip = addr.address;
          if (ip.startsWith('172.') && !ip.startsWith('172.16.') && !ip.startsWith('172.17.')) {
            // keep private 172.16/12 is complex — just list all non-loopback
          }
          ips.add(ip);
        }
      }
    } catch (e) {
      _log.warning("list interfaces failed", e);
    }

    if (ips.isEmpty) {
      ips.add('127.0.0.1');
    }

    return ips.map((ip) => 'http://$ip:$port/Jellyamp.apk').toList();
  }
}

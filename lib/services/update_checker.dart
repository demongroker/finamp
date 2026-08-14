import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _log = Logger('UpdateChecker');

/// Simple update information returned by the checker.
class UpdateInfo {
  final String latestVersion;
  final String htmlUrl;
  final String? body;

  const UpdateInfo({
    required this.latestVersion,
    required this.htmlUrl,
    this.body,
  });
}

/// Checks for newer Jellyamp releases on GitHub.
class UpdateChecker {
  UpdateChecker._();

  static const String _repo = 'demongroker/jellyamp';
  static const Duration _cacheDuration = Duration(hours: 24);

  static DateTime? _lastCheck;
  static UpdateInfo? _cachedResult;

  /// Returns update info if a newer version is available, otherwise null.
  static Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!force &&
        _cachedResult != null &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < _cacheDuration) {
      return _cachedResult;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url = Uri.parse('https://api.github.com/repos/$_repo/releases/latest');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _log.warning('GitHub API returned ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestTag = (data['tag_name'] as String?)?.replaceAll('v', '') ?? '';
      final htmlUrl = data['html_url'] as String? ?? 'https://github.com/$_repo/releases';

      if (latestTag.isEmpty) return null;

      if (_isNewerVersion(latestTag, currentVersion)) {
        final info = UpdateInfo(
          latestVersion: latestTag,
          htmlUrl: htmlUrl,
          body: data['body'] as String?,
        );

        _cachedResult = info;
        _lastCheck = DateTime.now();
        return info;
      }

      _lastCheck = DateTime.now();
      return null;
    } catch (e, st) {
      _log.warning('Update check failed', e, st);
      return null;
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      return latest.compareTo(current) > 0;
    }
  }
}
import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateInfo {
  final String version;
  final int? build;
  final String tag;
  final String url;
  final String notes;
  final Map<String, String> assets;

  const AppUpdateInfo({
    required this.version,
    required this.build,
    required this.tag,
    required this.url,
    required this.notes,
    required this.assets,
  });
}

abstract class UpdateChecker {
  static const String _owner = 'KometTeam';
  static const String _repo = 'Komet';
  static const String _userAgent = 'KometUpdateChecker';

  static const String _lastCheckKey = 'update_last_check_ms';
  static const String _skippedTagKey = 'update_skipped_tag';
  static const Duration _checkInterval = Duration(hours: 6);
  static const Duration _timeout = Duration(seconds: 15);

  static Future<AppUpdateInfo?> fetchLatest() async {
    final info = await PackageInfo.fromPlatform();
    final currentBase = info.version;
    final currentBuild = _normalizeBuild(int.tryParse(info.buildNumber));

    final release = await _fetchLatestRelease();
    if (release == null) return null;

    final tag = (release['tag_name'] as String?)?.trim();
    if (tag == null || tag.isEmpty) return null;

    final remoteBase = _baseVersion(tag);
    final remoteBuild = _buildNumber(tag);

    if (!_isNewer(
      currentBase: currentBase,
      currentBuild: currentBuild,
      remoteBase: remoteBase,
      remoteBuild: remoteBuild,
    )) {
      return null;
    }

    return AppUpdateInfo(
      version: remoteBase,
      build: remoteBuild,
      tag: tag,
      url: (release['html_url'] as String?) ?? _releasesPage,
      notes: (release['body'] as String?)?.trim() ?? '',
      assets: _parseAssets(release['assets']),
    );
  }

  static Future<AppUpdateInfo?> check({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!force) {
      final last = prefs.getInt(_lastCheckKey);
      if (last != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - last;
        if (elapsed >= 0 && elapsed < _checkInterval.inMilliseconds) {
          return null;
        }
      }
    }

    AppUpdateInfo? update;
    try {
      update = await fetchLatest();
    } catch (_) {
      return null;
    }

    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

    if (update == null) return null;

    if (!force && prefs.getString(_skippedTagKey) == update.tag) {
      return null;
    }

    return update;
  }

  static Future<void> skip(String tag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedTagKey, tag);
  }

  static String get _releasesPage =>
      'https://github.com/$_owner/$_repo/releases';

  static Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$_owner/$_repo/releases?per_page=10',
    );
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(uri);
      req.headers
        ..set(HttpHeaders.userAgentHeader, _userAgent)
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final resp = await req.close().timeout(_timeout);
      if (resp.statusCode != HttpStatus.ok) {
        await resp.drain<void>();
        return null;
      }
      final body = await resp
          .transform(const Utf8Decoder())
          .join()
          .timeout(_timeout);
      final decoded = jsonDecode(body);
      if (decoded is! List) return null;
      for (final entry in decoded) {
        if (entry is! Map) continue;
        if (entry['draft'] == true) continue;
        return entry.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, String> _parseAssets(dynamic raw) {
    final result = <String, String>{};
    if (raw is! List) return result;
    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = entry['name'] as String?;
      final url = entry['browser_download_url'] as String?;
      if (name != null && url != null) result[name] = url;
    }
    return result;
  }

  static String _baseVersion(String tag) {
    var s = tag.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    final dash = s.indexOf('-');
    if (dash >= 0) s = s.substring(0, dash);
    final plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    return s;
  }

  static const int _abiVersionCodeMultiplier = 1000;

  static int? _normalizeBuild(int? build) {
    if (build == null) return null;
    if (build >= _abiVersionCodeMultiplier) {
      return build % _abiVersionCodeMultiplier;
    }
    return build;
  }

  static int? _buildNumber(String tag) {
    final matches = RegExp(r'\d+').allMatches(tag).toList();
    if (matches.isEmpty) return null;
    return int.tryParse(matches.last.group(0)!);
  }

  static bool _isNewer({
    required String currentBase,
    required int? currentBuild,
    required String remoteBase,
    required int? remoteBuild,
  }) {
    final cmp = _compareSemver(remoteBase, currentBase);
    if (cmp > 0) return true;
    if (cmp < 0) return false;
    if (remoteBuild != null && currentBuild != null) {
      return remoteBuild > currentBuild;
    }
    return false;
  }

  static int _compareSemver(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va > vb ? 1 : -1;
    }
    return 0;
  }

  static List<int> _parts(String v) =>
      v.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
}

import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/update_config.dart';

class UpdateAsset {
  final String name;
  final String url;
  final int size;
  final String sha256;

  const UpdateAsset({
    required this.name,
    required this.url,
    required this.size,
    required this.sha256,
  });

  static UpdateAsset? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final url = raw['url'];
    if (name is! String || url is! String) return null;
    if (name.isEmpty || url.isEmpty) return null;
    final size = raw['size'];
    final digest = raw['sha256'];
    return UpdateAsset(
      name: name,
      url: url,
      size: size is int ? size : 0,
      sha256: digest is String ? digest.trim().toLowerCase() : '',
    );
  }
}

class AppUpdateInfo {
  final String version;
  final int? build;
  final String tag;
  final String url;
  final String notes;
  final List<UpdateAsset> assets;

  const AppUpdateInfo({
    required this.version,
    required this.build,
    required this.tag,
    required this.url,
    required this.notes,
    required this.assets,
  });

  UpdateAsset? assetWithSuffix(String suffix) {
    for (final asset in assets) {
      if (asset.name.endsWith(suffix)) return asset;
    }
    return null;
  }

  static AppUpdateInfo? tryParse(Map<String, dynamic> manifest) {
    final version = (manifest['version'] as String?)?.trim();
    if (version == null || version.isEmpty) return null;

    final rawBuild = manifest['build'];
    final build = rawBuild is int ? rawBuild : int.tryParse('${rawBuild ?? ''}');

    final tag = (manifest['tag'] as String?)?.trim();
    final url = (manifest['url'] as String?)?.trim();

    final rawAssets = manifest['assets'];
    final assets = <UpdateAsset>[];
    if (rawAssets is List) {
      for (final entry in rawAssets) {
        final asset = UpdateAsset.tryParse(entry);
        if (asset != null) assets.add(asset);
      }
    }

    return AppUpdateInfo(
      version: version,
      build: build,
      tag: tag == null || tag.isEmpty ? 'v$version' : tag,
      url: url == null || url.isEmpty ? UpdateConfig.downloadsPage : url,
      notes: (manifest['notes'] as String?)?.trim() ?? '',
      assets: assets,
    );
  }
}

enum UpdateCheckStatus { updateAvailable, upToDate, failed }

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final AppUpdateInfo? update;

  const UpdateCheckResult._(this.status, [this.update]);

  const UpdateCheckResult.updateAvailable(AppUpdateInfo update)
    : this._(UpdateCheckStatus.updateAvailable, update);

  const UpdateCheckResult.upToDate() : this._(UpdateCheckStatus.upToDate);

  const UpdateCheckResult.failed() : this._(UpdateCheckStatus.failed);
}

abstract class UpdateChecker {
  static const String _userAgent = 'KometUpdateChecker';

  static const String _lastCheckKey = 'update_last_check_ms';
  static const String _skippedTagKey = 'update_skipped_tag';
  static const Duration _checkInterval = Duration(hours: 6);
  static const Duration _timeout = Duration(seconds: 15);

  static Future<AppUpdateInfo?> fetchLatest() async {
    if (!UpdateConfig.isConfigured) return null;

    final info = await PackageInfo.fromPlatform();
    final currentBase = info.version;
    final currentBuild = _normalizeBuild(int.tryParse(info.buildNumber));

    final manifest = await _fetchManifest();
    if (manifest == null) return null;

    final remote = AppUpdateInfo.tryParse(manifest);
    if (remote == null) return null;

    if (!_isNewer(
      currentBase: currentBase,
      currentBuild: currentBuild,
      remoteBase: remote.version,
      remoteBuild: _normalizeBuild(remote.build),
    )) {
      return null;
    }

    return remote;
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

  /// Runs a user-initiated check without applying the automatic-check interval
  /// or the "skip this version" preference.
  static Future<UpdateCheckResult> checkNow() async {
    if (!UpdateConfig.isConfigured) {
      return const UpdateCheckResult.failed();
    }
    try {
      final update = await fetchLatest();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
      return update == null
          ? const UpdateCheckResult.upToDate()
          : UpdateCheckResult.updateAvailable(update);
    } catch (_) {
      return const UpdateCheckResult.failed();
    }
  }

  static Future<void> skip(String tag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedTagKey, tag);
  }

  static Future<Map<String, dynamic>?> _fetchManifest() async {
    final uri = UpdateConfig.manifestUri;
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(uri);
      req.headers
        ..set(HttpHeaders.userAgentHeader, _userAgent)
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache');
      final resp = await req.close().timeout(_timeout);
      if (resp.statusCode != HttpStatus.ok) {
        await resp.drain<void>();
        throw HttpException('Update manifest returned HTTP ${resp.statusCode}', uri: uri);
      }
      final body = await resp
          .transform(const Utf8Decoder())
          .join()
          .timeout(_timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException('Invalid update manifest');
      }
      return decoded.cast<String, dynamic>();
    } finally {
      client.close(force: true);
    }
  }

  static const int _abiVersionCodeMultiplier = 1000;

  static int? _normalizeBuild(int? build) {
    if (build == null) return null;
    if (build >= _abiVersionCodeMultiplier) {
      return build % _abiVersionCodeMultiplier;
    }
    return build;
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

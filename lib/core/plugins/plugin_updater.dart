import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'plugin_installer.dart';
import 'plugin_models.dart';
import 'plugin_store.dart';

class PluginUpdater {
  PluginUpdater({
    PluginInstaller installer = const PluginInstaller(),
    PluginStore? store,
  }) : _installer = installer,
       _store = store ?? PluginStore.instance;

  final PluginInstaller _installer;
  final PluginStore _store;

  Future<PluginUpdateInfo?> check(PluginDescriptor plugin) async {
    final manifestUrl = plugin.manifest.updateUrl;
    if (manifestUrl == null) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(manifestUrl);
      request.headers.set(HttpHeaders.userAgentHeader, 'KometPluginUpdater/1');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('HTTP ${response.statusCode}', uri: manifestUrl);
      }
      final decoded = jsonDecode(
        await response.transform(const Utf8Decoder()).join(),
      );
      if (decoded is! Map) {
        throw const FormatException('Некорректный update manifest');
      }
      final version = decoded['version'];
      final packageUrl = decoded['packageUrl'];
      final size = decoded['size'];
      final digest = decoded['sha256'];
      if (version is! String ||
          packageUrl is! String ||
          size is! int ||
          digest is! String) {
        throw const FormatException('Некорректный update manifest');
      }
      if (_compareVersions(version, plugin.manifest.version) <= 0) return null;
      final uri = manifestUrl.resolve(packageUrl);
      if (uri.scheme != 'https') {
        throw const FormatException('packageUrl должен использовать HTTPS');
      }
      return PluginUpdateInfo(
        plugin: plugin,
        version: version,
        packageUrl: uri,
        size: size,
        sha256: digest.toLowerCase(),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<PluginDescriptor> apply(PluginUpdateInfo update) async {
    final preview = await _installer.download(update.packageUrl);
    if (preview.manifest.id != update.plugin.manifest.id ||
        preview.manifest.version != update.version) {
      throw const FormatException('Обновление принадлежит другому плагину');
    }
    if (update.size > 0 && preview.bytes.length != update.size) {
      throw const FormatException('Размер обновления не совпадает');
    }
    if (update.sha256.isNotEmpty &&
        sha256.convert(preview.bytes).toString() != update.sha256) {
      throw const FormatException('SHA-256 обновления не совпадает');
    }
    final missing = preview.manifest.permissions.difference(
      update.plugin.grantedPermissions,
    );
    if (missing.isNotEmpty) {
      throw FormatException(
        'Обновление запрашивает новые разрешения: ${missing.map((item) => item.label).join(', ')}',
      );
    }
    return _store.install(
      preview.bytes,
      grantedPermissions: update.plugin.grantedPermissions.intersection(
        preview.manifest.permissions,
      ),
      sourceUrl: _store.sourceUrl(update.plugin.manifest.id),
    );
  }
}

int _compareVersions(String a, String b) {
  final left = _ParsedVersion.parse(a);
  final right = _ParsedVersion.parse(b);
  for (var i = 0; i < 3; i++) {
    final comparison = left.core[i].compareTo(right.core[i]);
    if (comparison != 0) return comparison;
  }
  if (left.preRelease.isEmpty && right.preRelease.isNotEmpty) return 1;
  if (left.preRelease.isNotEmpty && right.preRelease.isEmpty) return -1;
  final length = left.preRelease.length > right.preRelease.length
      ? left.preRelease.length
      : right.preRelease.length;
  for (var i = 0; i < length; i++) {
    if (i >= left.preRelease.length) return -1;
    if (i >= right.preRelease.length) return 1;
    final leftPart = left.preRelease[i];
    final rightPart = right.preRelease[i];
    final leftNumber = int.tryParse(leftPart);
    final rightNumber = int.tryParse(rightPart);
    if (leftNumber != null && rightNumber != null) {
      final comparison = leftNumber.compareTo(rightNumber);
      if (comparison != 0) return comparison;
      continue;
    }
    if (leftNumber != null) return -1;
    if (rightNumber != null) return 1;
    final comparison = leftPart.compareTo(rightPart);
    if (comparison != 0) return comparison;
  }
  return 0;
}

class _ParsedVersion {
  const _ParsedVersion(this.core, this.preRelease);

  final List<int> core;
  final List<String> preRelease;

  factory _ParsedVersion.parse(String value) {
    final withoutBuild = value.split('+').first;
    final separator = withoutBuild.indexOf('-');
    final coreSource = separator == -1
        ? withoutBuild
        : withoutBuild.substring(0, separator);
    final preRelease = separator == -1
        ? const <String>[]
        : withoutBuild.substring(separator + 1).split('.');
    final core = coreSource.split('.').map(int.parse).toList();
    if (core.length != 3) throw const FormatException('Некорректная версия');
    return _ParsedVersion(core, preRelease);
  }
}

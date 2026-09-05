import 'dart:async';
import 'dart:io';

import 'plugin_models.dart';
import 'plugin_package.dart';

class PluginInstaller {
  const PluginInstaller();

  static const _timeout = Duration(seconds: 20);
  static const _maxBytes = 5 * 1024 * 1024;

  Future<PluginPackagePreview> preview(List<int> bytes) =>
      PluginPackage.preview(bytes);

  Future<PluginPackagePreview> download(Uri uri) async {
    if (uri.scheme != 'https') {
      throw const FormatException('Плагин можно загрузить только по HTTPS');
    }
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'KometPluginInstaller/1',
      );
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(_timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBytes) {
          throw const FormatException('.kinet слишком большой');
        }
      }
      return await preview(bytes);
    } finally {
      client.close(force: true);
    }
  }
}

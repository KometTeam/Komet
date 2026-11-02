import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'plugin_network_policy.dart';

class PluginMediaDownloader {
  PluginMediaDownloader._();

  static const int _attempts = 3;
  static const int _maxRedirects = 5;
  static const Duration _responseTimeout = Duration(seconds: 20);

  static Future<Uint8List> download(
    Uri uri, {
    required int maxBytes,
    bool allowHttpForTesting = false,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < _attempts; attempt++) {
      try {
        return await _downloadOnce(
          uri,
          maxBytes: maxBytes,
          allowHttpForTesting: allowHttpForTesting,
        );
      } on FormatException {
        rethrow;
      } on HttpException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on TimeoutException catch (error) {
        lastError = error;
      }
      if (attempt + 1 < _attempts) {
        await Future.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
    throw HttpException(
      'Не удалось полностью загрузить файл после $_attempts попыток: $lastError',
      uri: uri,
    );
  }

  static Future<Uint8List> _downloadOnce(
    Uri initialUri, {
    required int maxBytes,
    required bool allowHttpForTesting,
  }) async {
    final client = PluginNetworkPolicy.createClient(
      allowHttpForTesting: allowHttpForTesting,
    );
    try {
      var uri = initialUri;
      for (var redirect = 0; redirect <= _maxRedirects; redirect++) {
        _validateUri(uri, allowHttpForTesting: allowHttpForTesting);
        final request = await client.getUrl(uri).timeout(_responseTimeout);
        request
          ..followRedirects = false
          ..persistentConnection = false;
        request.headers
          ..set(HttpHeaders.userAgentHeader, 'KometPluginMedia/1')
          ..set(
            HttpHeaders.acceptHeader,
            'image/*, application/octet-stream;q=0.9, */*;q=0.1',
          )
          ..set(HttpHeaders.cacheControlHeader, 'no-cache');
        final response = await request.close().timeout(_responseTimeout);
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>().timeout(_responseTimeout);
          if (location == null || redirect == _maxRedirects) {
            throw HttpException('Некорректный HTTP redirect', uri: uri);
          }
          uri = uri.resolve(location);
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.drain<void>().timeout(_responseTimeout);
          throw HttpException('HTTP ${response.statusCode}', uri: uri);
        }
        final contentLength = response.contentLength;
        if (contentLength > maxBytes) {
          await response.drain<void>().timeout(_responseTimeout);
          throw const FormatException('Файл слишком большой');
        }
        final bytes = <int>[];
        await for (final chunk in response.timeout(_responseTimeout)) {
          if (bytes.length + chunk.length > maxBytes) {
            throw const FormatException('Файл слишком большой');
          }
          bytes.addAll(chunk);
        }
        if (contentLength >= 0 && bytes.length != contentLength) {
          throw HttpException(
            'Получено ${bytes.length} из $contentLength байт',
            uri: uri,
          );
        }
        return Uint8List.fromList(bytes);
      }
      throw HttpException('Слишком много HTTP redirect', uri: initialUri);
    } finally {
      client.close(force: true);
    }
  }

  static void _validateUri(Uri uri, {required bool allowHttpForTesting}) =>
      PluginNetworkPolicy.validateUri(
        uri,
        allowHttpForTesting: allowHttpForTesting,
      );
}

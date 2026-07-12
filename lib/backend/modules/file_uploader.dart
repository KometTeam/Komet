import 'dart:async';
import 'dart:convert' show jsonDecode, utf8;
import 'dart:io';
import 'dart:typed_data';

import '../api.dart';
import '../../core/config/proxy_config.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/transport/proxy_connector.dart';
import '../../core/transport/tls_config.dart';
import '../../core/utils/logger.dart';
import 'messages.dart';

sealed class UploadEvent {
  const UploadEvent();
}

class UploadProgress extends UploadEvent {
  final int sent;
  final int total;
  const UploadProgress({required this.sent, required this.total});
}

class UploadDone extends UploadEvent {
  final int fileId;
  final String? token;
  final String? url;
  final String filename;
  final int size;
  const UploadDone({
    required this.fileId,
    required this.filename,
    required this.size,
    this.token,
    this.url,
  });
}

class UploadError extends UploadEvent {
  final String message;
  const UploadError(this.message);
}

class FileUploader {
  static const String _userAgentHeader =
      'OKMessages/26.14.1 (Android 11; TECNO MOBILE LIMITED TECNO LE7n; xxhdpi 480dpi 1080x2208)';

  final Api api;
  final MessagesModule messages;

  FileUploader({required this.api, required this.messages});

  Stream<UploadEvent> upload({
    required int chatId,
    required File file,
    required String filename,
    required int totalSize,
    int? scheduledTime,
    Duration autoForceAfter = const Duration(seconds: 1),
    Duration overallTimeout = const Duration(minutes: 5),
    Duration progressThrottle = const Duration(milliseconds: 16),
  }) {
    final ctrl = StreamController<UploadEvent>();
    var cancelled = false;
    Socket? socket;

    ctrl.onCancel = () {
      cancelled = true;
      try {
        socket?.destroy();
      } catch (_) {}
    };

    Future<void> run() async {
      try {
        final info = await messages.requestUploadUrl();
        if (cancelled) return;
        if (info == null) {
          ctrl.add(const UploadError('no_upload_url'));
          return;
        }

        unawaited(() async {
          try {
            await api.sendRequest(Opcode.msgTyping, {
              'chatId': chatId,
              'type': 'FILE',
            });
          } catch (_) {}
        }());

        final uri = Uri.parse(info.url);
        final result = await _sendHttpRequest(
          uri,
          method: 'POST',
          headers: _buildUploadHeaders(uri, filename, totalSize),
          bodyStream: file.openRead(),
          progressTotal: totalSize,
          onProgress: (sent, total) {
            if (!cancelled) ctrl.add(UploadProgress(sent: sent, total: total));
          },
          progressThrottle: progressThrottle,
          autoForceAfter: autoForceAfter,
          timeout: overallTimeout,
          onSocketReady: (s) => socket = s,
          shouldAbort: () => cancelled,
        );
        if (cancelled) return;

        final statusCode = result?.$1 ?? 0;
        if (statusCode != 200 && statusCode != 0) {
          ctrl.add(UploadError('http_$statusCode'));
          return;
        }

        final ok = await messages.sendFileMessage(
          chatId,
          info.fileId,
          token: info.token,
          scheduledTime: scheduledTime,
        );
        if (cancelled) return;
        if (!ok) {
          ctrl.add(const UploadError('send_failed'));
          return;
        }

        ctrl.add(
          UploadDone(
            fileId: info.fileId,
            token: info.token,
            url: info.url,
            filename: filename,
            size: totalSize,
          ),
        );
      } catch (e) {
        if (!cancelled) ctrl.add(UploadError(e.toString()));
      } finally {
        try {
          socket?.destroy();
        } catch (_) {}
        await ctrl.close();
      }
    }

    unawaited(run());
    return ctrl.stream;
  }

  Future<bool> uploadMediaFile(
    Uri uri,
    File file, {
    void Function(int sent, int total)? onProgress,
    Duration overallTimeout = const Duration(minutes: 5),
    Duration progressThrottle = const Duration(milliseconds: 16),
  }) async {
    try {
      final total = await file.length();
      if (total <= 0) return false;
      final filename = _syntheticFilename();

      final result = await _sendHttpRequest(
        uri,
        method: 'POST',
        headers: _buildUploadHeaders(
          uri,
          filename,
          total,
          contentType: 'application/octet-stream',
          connection: 'close',
        ),
        bodyStream: file.openRead(),
        progressTotal: total,
        onProgress: onProgress,
        progressThrottle: progressThrottle,
        timeout: overallTimeout,
      );

      final statusCode = result?.$1 ?? 0;
      final respBody = result?.$2 ?? '';
      logger.w(
        'uploadMediaFile: status=$statusCode total=$total '
        'host=${uri.host} body=${respBody.length > 200 ? respBody.substring(0, 200) : respBody}',
      );
      final hasError =
          respBody.contains('error_msg') || respBody.contains('error_code');
      return statusCode == 200 && !hasError;
    } catch (e) {
      logger.w('uploadMediaFile: $e');
      return false;
    }
  }

  Future<Socket> _openSocket(Uri uri) async {
    final proxySettings = await ProxyConfig.load();
    final base = proxySettings.isEnabled
        ? await ProxyConnector(proxySettings).connect(uri.host, uri.port)
        : await Socket.connect(uri.host, uri.port);
    if (uri.scheme != 'https') return base;
    final allowInsecure = await TlsConfig.isInsecureAllowed();
    if (allowInsecure) {
      logger.w(
        'TLS: проверка сертификата отключена (дебаг) — загрузка уязвима к MitM',
      );
      return SecureSocket.secure(
        base,
        host: uri.host,
        onBadCertificate: (_) => true,
      );
    }
    return SecureSocket.secure(base, host: uri.host);
  }

  String _syntheticFilename() =>
      (DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF).toString();

  String _multipartBoundary() =>
      '----KometBoundary${DateTime.now().microsecondsSinceEpoch}';

  Map<String, String> _buildUploadHeaders(
    Uri uri,
    String filename,
    int total, {
    String contentType = 'application/x-binary; charset=x-user-defined',
    String connection = 'keep-alive',
  }) {
    return {
      'Host': uri.host,
      'Content-Type': contentType,
      'Content-Disposition': 'attachment; filename=$filename',
      'Connection': connection,
      'User-Agent': Uri.encodeComponent(_userAgentHeader),
      'Content-Range': 'bytes 0-${total - 1}/$total',
      'Content-Length': '$total',
    };
  }

  Future<String?> uploadImage(
    Uri uri,
    Uint8List bytes, {
    String filename = 'avatar.jpg',
  }) async {
    try {
      final boundary = _multipartBoundary();
      final preamble = utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="$filename"\r\n'
        'Content-Type: ${_contentTypeForFilename(filename)}\r\n'
        '\r\n',
      );
      final epilogue = utf8.encode('\r\n--$boundary--\r\n');

      final response = await _sendHttpRequest(
        uri,
        method: 'POST',
        headers: _buildMultipartHeaders(
          uri,
          preamble.length + bytes.length + epilogue.length,
          boundary: boundary,
        ),
        prefixBytes: preamble,
        bodyStream: Stream.value(bytes),
        suffixBytes: epilogue,
        timeout: const Duration(minutes: 2),
      );

      if (response == null) {
        return null;
      }
      final (status, body) = response;
      if (status != 200) {
        logger.w(
          'uploadImage: status=$status body=${body.length > 200 ? '${body.substring(0, 200)}…' : body}',
        );
        return null;
      }
      final token = _parsePhotoToken(body);
      if (token == null) {
        logger.w(
          'uploadImage: photoToken not found in body=${body.length > 200 ? '${body.substring(0, 200)}…' : body}',
        );
      }
      return token;
    } catch (e) {
      logger.w('uploadImage: $e');
      return null;
    }
  }

  Future<String?> uploadPhoto(
    Uri uri,
    File file, {
    String filename = 'photo.jpg',
    void Function(int sent, int total)? onProgress,
    Duration progressThrottle = const Duration(milliseconds: 16),
  }) async {
    try {
      final fileLength = await file.length();
      final boundary = _multipartBoundary();
      final preamble = utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="$filename"\r\n'
        'Content-Type: ${_contentTypeForFilename(filename)}\r\n'
        '\r\n',
      );
      final epilogue = utf8.encode('\r\n--$boundary--\r\n');

      final response = await _sendHttpRequest(
        uri,
        method: 'POST',
        headers: _buildMultipartHeaders(
          uri,
          preamble.length + fileLength + epilogue.length,
          boundary: boundary,
        ),
        prefixBytes: preamble,
        bodyStream: file.openRead(),
        suffixBytes: epilogue,
        progressTotal: fileLength,
        onProgress: onProgress,
        progressThrottle: progressThrottle,
        timeout: const Duration(minutes: 2),
      );

      if (response == null) return null;
      final (status, responseBody) = response;
      if (status != 200) {
        logger.w('uploadPhoto: status=$status');
        return null;
      }
      return _parsePhotoToken(responseBody);
    } catch (e) {
      logger.w('uploadPhoto: $e');
      return null;
    }
  }

  Future<bool> uploadVideoFile(
    Uri uri,
    File file, {
    void Function(int sent, int total)? onProgress,
    int chunkSize = 2 * 1024 * 1024,
    int concurrency = 4,
    Duration overallTimeout = const Duration(minutes: 30),
  }) async {
    final total = await file.length();
    if (total <= 0) return false;

    final fileName = _syntheticFilename();

    final handshake = await _okCdnRequest(
      uri,
      method: 'GET',
      fileName: fileName,
      timeout: const Duration(seconds: 30),
    );
    if (handshake == null || handshake.$1 != 200) return false;

    var startOffset = 0;
    final resumed = int.tryParse(handshake.$2.trim());
    if (resumed != null && resumed > 0 && resumed <= total) {
      startOffset = resumed;
    }

    final ranges = <(int, int)>[];
    for (var o = startOffset; o < total; o += chunkSize) {
      ranges.add((o, o + chunkSize < total ? o + chunkSize : total));
    }
    if (ranges.isEmpty) return true;

    var nextIndex = 0;
    var sent = startOffset;
    var failed = false;

    Future<void> worker() async {
      while (!failed) {
        final i = nextIndex++;
        if (i >= ranges.length) return;
        final (start, end) = ranges[i];
        final bytes = await _readRange(file, start, end);

        final resp = await _okCdnRequest(
          uri,
          method: 'POST',
          fileName: fileName,
          body: bytes,
          contentRange: 'bytes $start-${end - 1}/$total',
          timeout: overallTimeout,
        );
        if (resp == null || (resp.$1 != 200 && resp.$1 != 201)) {
          logger.w('uploadVideoFile: chunk status=${resp?.$1}');
          failed = true;
          return;
        }

        sent += end - start;
        onProgress?.call(sent, total);
      }
    }

    final workerCount = concurrency < ranges.length
        ? concurrency
        : ranges.length;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return !failed;
  }

  Future<Uint8List> _readRange(File file, int start, int end) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(start, end)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<(int, String)?> _okCdnRequest(
    Uri uri, {
    required String method,
    required String fileName,
    Uint8List? body,
    String? contentRange,
    required Duration timeout,
  }) async {
    try {
      final headers = {
        'Host': uri.host,
        'Content-Type': 'application/x-binary; charset=x-user-defined',
        'Content-Disposition': 'attachment; fileName="$fileName"',
        'Content-Range': ?contentRange,
        'Content-Length': '${body?.length ?? 0}',
        'X-Uploading-Mode': 'parallel',
        'Connection': 'close',
      };
      return await _sendHttpRequest(
        uri,
        method: method,
        headers: headers,
        prefixBytes: body,
        timeout: timeout,
      );
    } catch (e) {
      logger.w('_okCdnRequest($method): $e');
      return null;
    }
  }

  Map<String, String> _buildMultipartHeaders(
    Uri uri,
    int total, {
    required String boundary,
  }) {
    return {
      'Host': uri.host,
      'Content-Type': 'multipart/form-data; boundary=$boundary',
      'Content-Length': '$total',
      'Connection': 'keep-alive',
      'User-Agent': Uri.encodeComponent(_userAgentHeader),
    };
  }

  Future<(int, String)?> _sendHttpRequest(
    Uri uri, {
    required String method,
    required Map<String, String> headers,
    List<int>? prefixBytes,
    Stream<List<int>>? bodyStream,
    List<int>? suffixBytes,
    int? progressTotal,
    void Function(int sent, int total)? onProgress,
    Duration progressThrottle = const Duration(milliseconds: 16),
    Duration? autoForceAfter,
    required Duration timeout,
    void Function(Socket socket)? onSocketReady,
    bool Function()? shouldAbort,
  }) async {
    final socket = await _openSocket(uri);
    onSocketReady?.call(socket);
    try {
      if (shouldAbort?.call() ?? false) return null;

      _writeRequestHeaders(socket, uri, method, headers);
      if (prefixBytes != null && prefixBytes.isNotEmpty) {
        socket.add(prefixBytes);
      }
      if (bodyStream != null) {
        final stream = (onProgress != null && progressTotal != null)
            ? _withProgress(
                bodyStream,
                progressTotal,
                onProgress,
                throttle: progressThrottle,
              )
            : bodyStream;
        await socket.addStream(stream);
      }
      if (suffixBytes != null && suffixBytes.isNotEmpty) {
        socket.add(suffixBytes);
      }
      await socket.flush();
      if (onProgress != null && progressTotal != null) {
        onProgress(progressTotal, progressTotal);
      }
      if (shouldAbort?.call() ?? false) return null;

      if (autoForceAfter != null) {
        final status = await _readResponse(
          socket,
          autoForceAfter: autoForceAfter,
          overallTimeout: timeout,
        );
        return (status, '');
      }
      return await _readFullResponse(socket, timeout: timeout);
    } finally {
      try {
        socket.destroy();
      } catch (_) {}
    }
  }

  void _writeRequestHeaders(
    Socket socket,
    Uri uri,
    String method,
    Map<String, String> headers,
  ) {
    final path = '${uri.path}${uri.hasQuery ? "?${uri.query}" : ""}';
    final buffer = StringBuffer()..write('$method $path HTTP/1.1\r\n');
    for (final entry in headers.entries) {
      buffer.write('${entry.key}: ${entry.value}\r\n');
    }
    buffer.write('\r\n');
    socket.add(utf8.encode(buffer.toString()));
  }

  Stream<List<int>> _withProgress(
    Stream<List<int>> src,
    int total,
    void Function(int sent, int total) onProgress, {
    Duration throttle = const Duration(milliseconds: 16),
  }) {
    final stopwatch = Stopwatch()..start();
    var sent = 0;
    return src.map((chunk) {
      sent += chunk.length;
      if (stopwatch.elapsed >= throttle) {
        onProgress(sent, total);
        stopwatch.reset();
      }
      return chunk;
    });
  }

  String _contentTypeForFilename(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'bmp':
        return 'image/bmp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<(int, String)?> _readFullResponse(
    Socket socket, {
    required Duration timeout,
  }) {
    final bytes = <int>[];
    final completer = Completer<(int, String)?>();
    Timer? timer;
    StreamSubscription<List<int>>? sub;

    void finishWith((int, String)? value) {
      timer?.cancel();
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(value);
    }

    (int, String)? tryParse({required bool atClose}) {
      final headerEnd = _findHeaderEnd(bytes);
      if (headerEnd == -1) return null;
      final headerStr = utf8.decode(
        bytes.sublist(0, headerEnd),
        allowMalformed: true,
      );
      final lines = headerStr.split('\r\n');
      final parts = lines.first.split(' ');
      final status = parts.length >= 2 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final headerLines = lines.skip(1);
      final chunked = headerLines.any(
        (l) =>
            l.toLowerCase().startsWith('transfer-encoding:') &&
            l.toLowerCase().contains('chunked'),
      );
      int? contentLength;
      for (final l in headerLines) {
        if (l.toLowerCase().startsWith('content-length:')) {
          contentLength = int.tryParse(l.split(':').last.trim());
        }
      }
      final rawBody = utf8.decode(
        bytes.sublist(headerEnd),
        allowMalformed: true,
      );
      if (chunked) {
        if (!atClose && !rawBody.contains('\r\n0\r\n')) return null;
        return (status, _decodeChunked(rawBody));
      }
      if (contentLength != null &&
          !atClose &&
          bytes.length - headerEnd < contentLength) {
        return null;
      }
      return (status, rawBody);
    }

    sub = socket.listen(
      (chunk) {
        bytes.addAll(chunk);
        final parsed = tryParse(atClose: false);
        if (parsed != null) finishWith(parsed);
      },
      onError: (e) {
        logger.w('uploadImage: socket error after ${bytes.length} bytes: $e');
        finishWith(tryParse(atClose: true));
      },
      onDone: () {
        final parsed = tryParse(atClose: true);
        if (parsed == null) {
          logger.w(
            'uploadImage: connection closed without HTTP response (${bytes.length} bytes)',
          );
        }
        finishWith(parsed);
      },
    );
    timer = Timer(timeout, () {
      logger.w('uploadImage: response timeout after ${bytes.length} bytes');
      finishWith(tryParse(atClose: true));
    });
    return completer.future;
  }

  String _decodeChunked(String body) {
    final out = StringBuffer();
    var i = 0;
    while (i < body.length) {
      final lineEnd = body.indexOf('\r\n', i);
      if (lineEnd < 0) break;
      final sizeStr = body.substring(i, lineEnd).split(';').first.trim();
      if (sizeStr.isEmpty) {
        i = lineEnd + 2;
        continue;
      }
      final size = int.tryParse(sizeStr, radix: 16);
      if (size == null) break;
      if (size == 0) break;
      final dataStart = lineEnd + 2;
      if (dataStart + size > body.length) break;
      out.write(body.substring(dataStart, dataStart + size));
      i = dataStart + size;
      if (i + 2 <= body.length && body.substring(i, i + 2) == '\r\n') {
        i += 2;
      }
    }
    return out.toString();
  }

  String? _parsePhotoToken(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final photos = json['photos'];
        if (photos is Map) {
          for (final v in photos.values) {
            if (v is Map) {
              final token = v['token'];
              if (token is String && token.isNotEmpty) return token;
            }
          }
        }
        final pt = json['photoToken'];
        if (pt is String && pt.isNotEmpty) return pt;
      }
    } catch (e) {
      logger.w('parsePhotoToken: $e');
    }
    return null;
  }

  Future<int> _readResponse(
    Socket socket, {
    required Duration autoForceAfter,
    required Duration overallTimeout,
  }) {
    final responseBytes = <int>[];
    final completer = Completer<int>();
    Timer? force;
    Timer? overall;
    StreamSubscription<List<int>>? sub;

    void finish(int code) {
      if (completer.isCompleted) return;
      force?.cancel();
      overall?.cancel();
      sub?.cancel();
      completer.complete(code);
    }

    void fail(Object e) {
      if (completer.isCompleted) return;
      force?.cancel();
      overall?.cancel();
      sub?.cancel();
      completer.completeError(e);
    }

    force = Timer(autoForceAfter, () => finish(0));

    sub = socket.listen(
      responseBytes.addAll,
      onError: fail,
      onDone: () {
        final code = _parseHttpStatus(responseBytes);
        if (code == null) {
          fail(const SocketException('Не удалось прочитать заголовок ответа'));
        } else {
          finish(code);
        }
      },
    );

    overall = Timer(
      overallTimeout,
      () => fail(TimeoutException('Тайм-аут загрузки')),
    );

    return completer.future;
  }

  int? _parseHttpStatus(List<int> bytes) {
    final headerEnd = _findHeaderEnd(bytes);
    if (headerEnd == -1) return null;
    final headerStr = utf8.decode(
      bytes.sublist(0, headerEnd),
      allowMalformed: true,
    );
    final statusLine = headerStr.split('\r\n').first;
    final parts = statusLine.split(' ');
    if (parts.length < 2) return null;
    return int.tryParse(parts[1]);
  }

  int _findHeaderEnd(List<int> bytes) {
    for (var i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] == 0x0D &&
          bytes[i + 1] == 0x0A &&
          bytes[i + 2] == 0x0D &&
          bytes[i + 3] == 0x0A) {
        return i + 4;
      }
    }
    return -1;
  }
}

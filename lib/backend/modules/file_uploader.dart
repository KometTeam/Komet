import 'dart:async';
import 'dart:convert' show jsonDecode, utf8;
import 'dart:io';
import 'dart:typed_data';

import '../api.dart';
import '../../core/config/proxy_config.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/transport/proxy_connector.dart';
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
  final Api api;
  final MessagesModule messages;

  FileUploader({required this.api, required this.messages});

  Stream<UploadEvent> upload({
    required int chatId,
    required File file,
    required String filename,
    required int totalSize,
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
        socket = await _openSocket(uri);
        if (cancelled) return;

        _writeHeaders(socket!, uri, filename, totalSize);

        final stopwatch = Stopwatch()..start();
        var sent = 0;
        final body = file.openRead().map((chunk) {
          sent += chunk.length;
          if (stopwatch.elapsed >= progressThrottle) {
            ctrl.add(UploadProgress(sent: sent, total: totalSize));
            stopwatch.reset();
          }
          return chunk;
        });
        await socket!.addStream(body);
        await socket!.flush();
        if (cancelled) return;
        ctrl.add(UploadProgress(sent: totalSize, total: totalSize));

        final statusCode = await _readResponse(
          socket!,
          autoForceAfter: autoForceAfter,
          overallTimeout: overallTimeout,
        );
        try {
          socket!.destroy();
        } catch (_) {}
        if (cancelled) return;

        if (statusCode != 200 && statusCode != 0) {
          ctrl.add(UploadError('http_$statusCode'));
          return;
        }

        final ok = await messages.sendFileMessage(
          chatId,
          info.fileId,
          token: info.token,
        );
        if (cancelled) return;
        if (!ok) {
          ctrl.add(const UploadError('send_failed'));
          return;
        }

        ctrl.add(UploadDone(
          fileId: info.fileId,
          token: info.token,
          url: info.url,
          filename: filename,
          size: totalSize,
        ));
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

  Future<Socket> _openSocket(Uri uri) async {
    final proxySettings = await ProxyConfig.load();
    final base = proxySettings.isEnabled
        ? await ProxyConnector(proxySettings).connect(uri.host, uri.port)
        : await Socket.connect(uri.host, uri.port);
    if (uri.scheme != 'https') return base;
    return SecureSocket.secure(
      base,
      host: uri.host,
      onBadCertificate: (_) => true,
    );
  }

  void _writeHeaders(
    Socket socket,
    Uri uri,
    String filename,
    int total, {
    String contentType = 'application/x-binary; charset=x-user-defined',
  }) {
    final path = '${uri.path}${uri.hasQuery ? "?${uri.query}" : ""}';
    final headers = StringBuffer()
      ..write('POST $path HTTP/1.1\r\n')
      ..write('Host: ${uri.host}\r\n')
      ..write('Content-Type: $contentType\r\n')
      ..write('Content-Disposition: attachment; filename=$filename\r\n')
      ..write('Connection: keep-alive\r\n')
      ..write('User-Agent: ${Uri.encodeComponent('OKMessages/26.14.1 (Android 11; TECNO MOBILE LIMITED TECNO LE7n; xxhdpi 480dpi 1080x2208)')}\r\n')
      ..write('Content-Range: bytes 0-${total - 1}/$total\r\n')
      ..write('Content-Length: $total\r\n')
      ..write('\r\n');
    socket.add(utf8.encode(headers.toString()));
  }

  Future<String?> uploadImage(Uri uri, Uint8List bytes, {String filename = 'avatar.jpg'}) async {
    Socket? socket;
    try {
      socket = await _openSocket(uri);
      final boundary = '----KometBoundary${DateTime.now().microsecondsSinceEpoch}';
      final preamble = utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="$filename"\r\n'
        'Content-Type: ${_contentTypeForFilename(filename)}\r\n'
        '\r\n',
      );
      final epilogue = utf8.encode('\r\n--$boundary--\r\n');
      _writeImageHeaders(
        socket,
        uri,
        preamble.length + bytes.length + epilogue.length,
        boundary: boundary,
      );
      socket.add(preamble);
      socket.add(bytes);
      socket.add(epilogue);
      await socket.flush();

      final response = await _readFullResponse(
        socket,
        timeout: const Duration(minutes: 2),
      );
      try {
        socket.destroy();
      } catch (_) {}

      if (response == null) {
        return null;
      }
      final (status, body) = response;
      if (status != 200) {
        logger.w('uploadImage: status=$status body=${body.length > 200 ? '${body.substring(0, 200)}…' : body}');
        return null;
      }
      final token = _parsePhotoToken(body);
      if (token == null) {
        logger.w('uploadImage: photoToken not found in body=${body.length > 200 ? '${body.substring(0, 200)}…' : body}');
      }
      return token;
    } catch (e) {
      logger.w('uploadImage: $e');
      try {
        socket?.destroy();
      } catch (_) {}
      return null;
    }
  }

  void _writeImageHeaders(Socket socket, Uri uri, int total, {required String boundary}) {
    final path = '${uri.path}${uri.hasQuery ? "?${uri.query}" : ""}';
    final headers = StringBuffer()
      ..write('POST $path HTTP/1.1\r\n')
      ..write('Host: ${uri.host}\r\n')
      ..write('Content-Type: multipart/form-data; boundary=$boundary\r\n')
      ..write('Content-Length: $total\r\n')
      ..write('Connection: keep-alive\r\n')
      ..write('User-Agent: ${Uri.encodeComponent('OKMessages/26.14.1 (Android 11; TECNO MOBILE LIMITED TECNO LE7n; xxhdpi 480dpi 1080x2208)')}\r\n')
      ..write('\r\n');
    socket.add(utf8.encode(headers.toString()));
  }

  String _contentTypeForFilename(String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
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
      final headerStr = utf8.decode(bytes.sublist(0, headerEnd), allowMalformed: true);
      final lines = headerStr.split('\r\n');
      final parts = lines.first.split(' ');
      final status = parts.length >= 2 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final headerLines = lines.skip(1);
      final chunked = headerLines.any(
        (l) => l.toLowerCase().startsWith('transfer-encoding:') &&
            l.toLowerCase().contains('chunked'),
      );
      int? contentLength;
      for (final l in headerLines) {
        if (l.toLowerCase().startsWith('content-length:')) {
          contentLength = int.tryParse(l.split(':').last.trim());
        }
      }
      final rawBody = utf8.decode(bytes.sublist(headerEnd), allowMalformed: true);
      if (chunked) {
        if (!atClose && !rawBody.contains('\r\n0\r\n')) return null;
        return (status, _decodeChunked(rawBody));
      }
      if (contentLength != null && !atClose && bytes.length - headerEnd < contentLength) {
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
          logger.w('uploadImage: connection closed without HTTP response (${bytes.length} bytes)');
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

    overall = Timer(overallTimeout, () => fail(TimeoutException('Тайм-аут загрузки')));

    return completer.future;
  }

  int? _parseHttpStatus(List<int> bytes) {
    final headerEnd = _findHeaderEnd(bytes);
    if (headerEnd == -1) return null;
    final headerStr = utf8.decode(bytes.sublist(0, headerEnd), allowMalformed: true);
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

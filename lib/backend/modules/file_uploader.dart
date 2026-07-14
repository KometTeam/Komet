import 'dart:async';
import 'dart:convert' show jsonDecode, utf8;
import 'dart:io';
import 'dart:typed_data';

import 'package:kolibri/kolibri.dart' as kb;

import '../api.dart';
import '../../core/protocol/opcode_map.dart';
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

/// Оркестратор медиа-загрузок: control-plane (URL, отправка сообщения) идёт
/// обычными опкодами, data-plane (заливка на CDN) — через Rust-ядро kolibri,
/// которое стримит файл с диска (не держит его целиком в памяти).
class FileUploader {
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
    StreamSubscription<kb.UploadEvent>? sub;

    ctrl.onCancel = () {
      cancelled = true;
      sub?.cancel();
    };

    Future<void> run() async {
      try {
        final info = await messages.requestUploadUrl();
        if (cancelled) return;
        if (info == null) {
          ctrl.add(const UploadError('no_upload_url'));
          return;
        }

        final session = api.session;
        if (session == null) {
          ctrl.add(const UploadError('no_session'));
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

        var status = 0;
        String? error;
        final done = Completer<void>();
        sub =
            session
                .uploadFilePath(
                  url: info.url,
                  path: file.path,
                  filename: filename,
                  connection: 'close',
                )
                .listen(
                  (e) {
                    switch (e) {
                      case kb.UploadEvent_Progress(:final sent, :final total):
                        ctrl.add(
                          UploadProgress(
                            sent: sent.toInt(),
                            total: total.toInt(),
                          ),
                        );
                      case kb.UploadEvent_Done(status: final s):
                        status = s;
                      case kb.UploadEvent_Error(:final message):
                        error = message;
                    }
                  },
                  onError: (Object err) {
                    error = err.toString();
                    if (!done.isCompleted) done.complete();
                  },
                  onDone: () {
                    if (!done.isCompleted) done.complete();
                  },
                  cancelOnError: true,
                );
        await done.future;
        if (cancelled) return;
        if (error != null) {
          ctrl.add(UploadError(error!));
          return;
        }
        if (status != 200 && status != 0) {
          ctrl.add(UploadError('http_$status'));
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
    final session = api.session;
    if (session == null) return false;
    try {
      final result = await _consume(
        session.uploadFilePath(
          url: uri.toString(),
          path: file.path,
          filename: _syntheticFilename(),
          contentType: 'application/octet-stream',
          connection: 'close',
        ),
        onProgress: onProgress,
      );
      if (result.error != null) {
        logger.w('uploadMediaFile: ${result.error}');
        return false;
      }
      final respBody = utf8.decode(result.body, allowMalformed: true);
      final hasError =
          respBody.contains('error_msg') || respBody.contains('error_code');
      return result.status == 200 && !hasError;
    } catch (e) {
      logger.w('uploadMediaFile: $e');
      return false;
    }
  }

  Future<String?> uploadImage(
    Uri uri,
    Uint8List bytes, {
    String filename = 'avatar.jpg',
  }) async {
    final session = api.session;
    if (session == null) return null;
    try {
      final result = await _consume(
        session.uploadPhoto(
          url: uri.toString(),
          data: bytes,
          filename: filename,
        ),
      );
      if (result.error != null || result.status != 200) {
        logger.w('uploadImage: status=${result.status} error=${result.error}');
        return null;
      }
      return _parsePhotoToken(utf8.decode(result.body, allowMalformed: true));
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
    final session = api.session;
    if (session == null) return null;
    try {
      final result = await _consume(
        session.uploadPhotoPath(
          url: uri.toString(),
          path: file.path,
          filename: filename,
        ),
        onProgress: onProgress,
      );
      if (result.error != null || result.status != 200) {
        logger.w('uploadPhoto: status=${result.status} error=${result.error}');
        return null;
      }
      return _parsePhotoToken(utf8.decode(result.body, allowMalformed: true));
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
    final session = api.session;
    if (session == null) return false;
    try {
      final result = await _consume(
        session.uploadVideoPath(
          url: uri.toString(),
          path: file.path,
          chunkSize: chunkSize,
          concurrency: concurrency,
        ),
        onProgress: onProgress,
      );
      if (result.error != null || result.status != 200) {
        logger.w(
          'uploadVideoFile: status=${result.status} error=${result.error}',
        );
      }
      return result.error == null && result.status == 200;
    } catch (e) {
      logger.w('uploadVideoFile: $e');
      return false;
    }
  }

  /// Прогоняет стрим ядра до конца, форвардит прогресс, отдаёт итог.
  Future<({int status, Uint8List body, String? error})> _consume(
    Stream<kb.UploadEvent> stream, {
    void Function(int sent, int total)? onProgress,
  }) async {
    var status = 0;
    var body = Uint8List(0);
    String? error;
    await for (final event in stream) {
      switch (event) {
        case kb.UploadEvent_Progress(:final sent, :final total):
          onProgress?.call(sent.toInt(), total.toInt());
        case kb.UploadEvent_Done(status: final s, body: final b):
          status = s;
          body = b;
        case kb.UploadEvent_Error(:final message):
          error = message;
      }
    }
    return (status: status, body: body, error: error);
  }

  String _syntheticFilename() =>
      (DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF).toString();

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
}

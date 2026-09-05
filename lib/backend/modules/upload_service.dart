import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/cache/message_session_cache.dart';
import '../../core/media/gallery_source.dart';
import '../../core/media/image_optimizer.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/logger.dart';
import '../../main.dart' show fileUploader, messagesModule;
import '../../models/attachment.dart';
import 'file_uploader.dart';
import 'messages.dart';
import 'upload_notification_service.dart';

export 'upload_notification_service.dart' show UploadKind;

// #***! события очереди наружу
sealed class UploadJobEvent {
  const UploadJobEvent({
    required this.chatId,
    required this.tempId,
    required this.kind,
    required this.scheduled,
  });

  final int chatId;
  final String tempId;
  final UploadKind kind;
  final bool scheduled;
}

class UploadJobDone extends UploadJobEvent {
  const UploadJobDone({
    required super.chatId,
    required super.tempId,
    required super.kind,
    required super.scheduled,
    this.message,
    this.scheduledTime,
    this.fileId,
    this.fileToken,
  });

  final CachedMessage? message;
  final int? scheduledTime;
  final int? fileId;
  final String? fileToken;
}

class UploadJobFailed extends UploadJobEvent {
  const UploadJobFailed({
    required super.chatId,
    required super.tempId,
    required super.kind,
    required super.scheduled,
    required this.reason,
  });

  final String reason;
}

// #***! ошибка загрузки с кодом причины
class UploadFailure implements Exception {
  const UploadFailure(this.message);

  final String message;

  @override
  String toString() => 'UploadFailure($message)';
}

class UploadBytes {
  const UploadBytes(this.sent, this.total);

  final int sent;
  final int total;
}

// #***! одна задача, slots это сколько файлов внутри
class UploadJob {
  UploadJob._({
    required this.id,
    required this.accountId,
    required this.chatId,
    required this.kind,
    required int slots,
    this.filename,
    this.totalBytes = 0,
    this.placeholder,
    this.scheduledTime,
  }) : _slots = slots < 1 ? 1 : slots,
       _sent = List<int>.filled(slots < 1 ? 1 : slots, 0),
       _total = List<int>.filled(slots < 1 ? 1 : slots, 0),
       progress = ValueNotifier<List<double>>(
         List<double>.filled(slots < 1 ? 1 : slots, 0),
       ),
       bytes = ValueNotifier<UploadBytes>(UploadBytes(0, totalBytes)) {
    if (_slots == 1 && totalBytes > 0) _total[0] = totalBytes;
  }

  final String id;
  final int accountId;
  final int chatId;
  final UploadKind kind;
  final String? filename;
  final int totalBytes;
  final CachedMessage? placeholder;
  final int? scheduledTime;

  final ValueNotifier<List<double>> progress;
  final ValueNotifier<UploadBytes> bytes;

  int? resultFileId;
  String? resultFileToken;

  final int _slots;
  final List<int> _sent;
  final List<int> _total;

  bool get scheduled => scheduledTime != null;
  int get slots => _slots;

  // #***! прогресс по слоту, дальше считаем общий
  void report(int slot, int sent, int total) {
    if (slot < 0 || slot >= _slots) return;
    _sent[slot] = sent;
    if (total > 0) _total[slot] = total;
    _publish();
  }

  void resetSlot(int slot) {
    if (slot < 0 || slot >= _slots) return;
    _sent[slot] = 0;
    _publish();
  }

  // #***! залилось, добиваем до 100% чтоб полоска не висла на 99
  void markUploaded() {
    for (var i = 0; i < _slots; i++) {
      if (_total[i] <= 0) _total[i] = _sent[i] > 0 ? _sent[i] : 1;
      _sent[i] = _total[i];
    }
    _publish();
  }

  // #***! общий прогресс по байтам, размеров нет усредняем доли
  void _publish() {
    final fractions = List<double>.generate(_slots, (i) {
      if (_total[i] <= 0) return 0.0;
      return (_sent[i] / _total[i]).clamp(0.0, 1.0);
    });
    var sumSent = 0;
    var sumTotal = 0;
    var fractionSum = 0.0;
    for (var i = 0; i < _slots; i++) {
      sumSent += _sent[i];
      sumTotal += _total[i];
      fractionSum += fractions[i];
    }
    progress.value = fractions;
    bytes.value = UploadBytes(sumSent, sumTotal);
    UploadNotificationService.report(
      id,
      sent: sumSent,
      total: sumTotal,
      fraction: fractionSum / _slots,
    );
  }
}

// #***! фасад загрузок для юишки
class UploadService {
  UploadService._();

  static final UploadService instance = UploadService._();

  // #***! история завершённых чистится чтоб не росла вечно
  static const int _historyLimit = 60;
  // #***! фото по три параллельно, каждое до трёх попыток
  static const int _photoConcurrency = 3;
  static const int _photoAttempts = 3;

  final StreamController<UploadJobEvent> _events =
      StreamController<UploadJobEvent>.broadcast();

  final Map<String, UploadJob> _jobs = {};
  final Map<String, CachedMessage> _completed = {};
  final Set<String> _failed = {};

  int _tempIdCounter = 0;

  Stream<UploadJobEvent> get events => _events.stream;

  // #***! временный id до ответа сервера
  String newTempId() =>
      'temp_${++_tempIdCounter}_${DateTime.now().microsecondsSinceEpoch}';

  UploadJob? job(String tempId) => _jobs[tempId];

  ValueListenable<List<double>>? progressFor(String tempId) =>
      _jobs[tempId]?.progress;

  UploadJob? activeFileJob(int chatId) {
    for (final job in _jobs.values) {
      if (job.chatId == chatId && job.kind == UploadKind.file) return job;
    }
    return null;
  }

  // #***! плейсхолдеры открытого чата, рисуются вместе с настоящими
  List<CachedMessage> pendingFor(int chatId) {
    final pending = <CachedMessage>[];
    for (final job in _jobs.values) {
      final placeholder = job.placeholder;
      if (job.chatId == chatId && placeholder != null) pending.add(placeholder);
    }
    return List<CachedMessage>.unmodifiable(pending);
  }

  CachedMessage? completedFor(String tempId) => _completed[tempId];

  bool didFail(String tempId) => _failed.contains(tempId);

  // #***! альбом фото, собираем токены потом одно сообщение
  Future<void> sendPhotos({
    required int accountId,
    required int chatId,
    required String tempId,
    required List<({File file, GalleryItem? item})> jobs,
    required String caption,
    CachedMessage? placeholder,
    int? scheduledTime,
  }) {
    return _run(
      UploadJob._(
        id: tempId,
        accountId: accountId,
        chatId: chatId,
        kind: UploadKind.photo,
        slots: jobs.length,
        placeholder: placeholder,
        scheduledTime: scheduledTime,
      ),
      (job) async {
        final tokens = await _uploadPhotos(jobs, job);
        if (tokens.any((token) => token == null)) {
          throw const UploadFailure('upload_failed');
        }
        final sent = await messagesModule.sendPhotoMessage(
          chatId,
          tokens.cast<String>(),
          caption: caption.isEmpty ? null : caption,
          scheduledTime: scheduledTime,
        );
        if (sent == null) return null;
        return CachedMessage.fromPushPayload(accountId, chatId, sent);
      },
    );
  }

  // #***! видео, url заливка чанками сообщение
  Future<void> sendVideo({
    required int accountId,
    required int chatId,
    required String tempId,
    required File file,
    required String caption,
    CachedMessage? placeholder,
    int? scheduledTime,
  }) {
    return _run(
      UploadJob._(
        id: tempId,
        accountId: accountId,
        chatId: chatId,
        kind: UploadKind.video,
        slots: 1,
        placeholder: placeholder,
        scheduledTime: scheduledTime,
      ),
      (job) async {
        final info = await messagesModule.requestVideoUploadUrl();
        if (info == null || info.url.isEmpty) {
          throw const UploadFailure('no_upload_url');
        }
        final ok = await fileUploader.uploadVideoFile(
          Uri.parse(info.url),
          file,
          onProgress: (sent, total) => job.report(0, sent, total),
        );
        if (!ok) throw const UploadFailure('upload_failed');
        job.markUploaded();
        final sent = await messagesModule.sendVideoMessage(
          chatId,
          info.token,
          caption: caption.isEmpty ? null : caption,
          scheduledTime: scheduledTime,
        );
        if (sent == null) return null;
        return CachedMessage.fromPushPayload(accountId, chatId, sent);
      },
    );
  }

  // #***! голосовое
  Future<void> sendVoice({
    required int accountId,
    required int chatId,
    required String tempId,
    required File file,
    required int durationMs,
    required Uint8List wave,
    CachedMessage? placeholder,
  }) {
    return _sendRecording(
      accountId: accountId,
      chatId: chatId,
      tempId: tempId,
      file: file,
      kind: UploadKind.voice,
      placeholder: placeholder,
      requestUpload: () async {
        final info = await messagesModule.requestAudioUploadUrl();
        return info == null ? null : (url: info.url, token: info.token);
      },
      send: (token) => messagesModule.sendAudioMessage(
        chatId,
        token,
        duration: durationMs,
        wave: wave,
      ),
    );
  }

  // #***! кружок
  Future<void> sendVideoNote({
    required int accountId,
    required int chatId,
    required String tempId,
    required File file,
    required int durationMs,
    CachedMessage? placeholder,
  }) {
    return _sendRecording(
      accountId: accountId,
      chatId: chatId,
      tempId: tempId,
      file: file,
      kind: UploadKind.videoNote,
      placeholder: placeholder,
      requestUpload: () async {
        final info = await messagesModule.requestVideoNoteUploadUrl();
        return info == null ? null : (url: info.url, token: info.token);
      },
      send: (token) => messagesModule.sendVideoNoteMessage(
        chatId,
        token,
        duration: durationMs,
      ),
    );
  }

  // #***! общее для голосового и кружка, записанный файл потом удаляем
  Future<void> _sendRecording({
    required int accountId,
    required int chatId,
    required String tempId,
    required File file,
    required UploadKind kind,
    required Future<({String url, String token})?> Function() requestUpload,
    required Future<Map<String, dynamic>?> Function(String token) send,
    CachedMessage? placeholder,
  }) {
    return _run(
      UploadJob._(
        id: tempId,
        accountId: accountId,
        chatId: chatId,
        kind: kind,
        slots: 1,
        placeholder: placeholder,
      ),
      (job) async {
        try {
          final info = await requestUpload();
          if (info == null || info.url.isEmpty) {
            throw const UploadFailure('no_upload_url');
          }
          final ok = await fileUploader.uploadMediaFile(
            Uri.parse(info.url),
            file,
            onProgress: (sent, total) => job.report(0, sent, total),
          );
          if (!ok) throw const UploadFailure('upload_failed');
          job.markUploaded();
          final sent = await send(info.token);
          if (sent == null) return null;
          return CachedMessage.fromPushPayload(accountId, chatId, sent);
        } finally {
          try {
            await file.delete();
          } catch (_) {}
        }
      },
    );
  }

  // #***! документ, id и токен помним в истории файлов для облака
  Future<void> sendFile({
    required int accountId,
    required int chatId,
    required String tempId,
    required File source,
    required String filename,
    required int size,
    CachedMessage? placeholder,
    int? scheduledTime,
  }) {
    return _run(
      UploadJob._(
        id: tempId,
        accountId: accountId,
        chatId: chatId,
        kind: UploadKind.file,
        slots: 1,
        filename: filename,
        totalBytes: size,
        placeholder: placeholder,
        scheduledTime: scheduledTime,
      ),
      (job) async {
        final done = await _uploadFile(
          chatId: chatId,
          job: job,
          source: source,
          filename: filename,
          size: size,
          scheduledTime: scheduledTime,
        );
        FileHistoryCache.add(
          FileHistoryEntry(
            fileId: done.fileId,
            url: done.url,
            token: done.token,
            filename: done.filename,
            size: done.size,
            sentAt: DateTime.now(),
          ),
        );
        job.resultFileId = done.fileId;
        job.resultFileToken = done.token;
        if (scheduledTime != null) return null;

        final base = placeholder;
        return CachedMessage(
          id: done.messageId == null || done.messageId!.isEmpty
              ? tempId
              : done.messageId!,
          accountId: accountId,
          chatId: chatId,
          senderId: accountId,
          text: base?.text,
          time: base?.time ?? DateTime.now().millisecondsSinceEpoch,
          status: 'sent',
          attachments: [
            FileAttachment(
              fileId: done.fileId,
              fileToken: done.token,
              name: filename,
              size: size,
            ),
          ],
        );
      },
    );
  }

  // #***! обёртка над стримом FileUploader в один Future
  Future<UploadDone> _uploadFile({
    required int chatId,
    required UploadJob job,
    required File source,
    required String filename,
    required int size,
    int? scheduledTime,
  }) async {
    final result = Completer<UploadDone>();
    late final StreamSubscription<UploadEvent> sub;
    sub = fileUploader
        .upload(
          chatId: chatId,
          file: source,
          filename: filename,
          totalSize: size,
          scheduledTime: scheduledTime,
        )
        .listen(
          (event) {
            switch (event) {
              case UploadProgress(:final sent, :final total):
                job.report(0, sent, total);
              case UploadDone():
                if (!result.isCompleted) result.complete(event);
              case UploadError(:final message):
                if (!result.isCompleted) {
                  result.completeError(UploadFailure(message));
                }
            }
          },
          onError: (Object e) {
            if (!result.isCompleted) result.completeError(e);
          },
          onDone: () {
            if (!result.isCompleted) {
              result.completeError(const UploadFailure('upload_failed'));
            }
          },
        );
    try {
      return await result.future;
    } finally {
      await sub.cancel();
    }
  }

  // #***! прогон задачи, уведомление ошибка сохранение и событие
  Future<void> _run(
    UploadJob job,
    Future<CachedMessage?> Function(UploadJob job) upload,
  ) async {
    _jobs[job.id] = job;
    UploadNotificationService.begin(
      job.id,
      kind: job.kind,
      count: job.slots,
      filename: job.filename,
    );

    CachedMessage? real;
    String? failure;
    try {
      real = await upload(job);
      // #***! для отложенного null это нормально, оно уйдёт позже
      if (real == null && !job.scheduled) failure = 'send_failed';
    } catch (e) {
      failure = e is UploadFailure ? e.message : e.toString();
    }

    UploadNotificationService.end(job.id);
    _jobs.remove(job.id);

    if (failure != null) {
      logger.w('UploadService: ${job.id} — $failure');
      if (!job.scheduled) {
        _replaceInSessionCache(job.accountId, job.chatId, job.id, null);
        _remember(job.id, null);
      }
      _events.add(
        UploadJobFailed(
          chatId: job.chatId,
          tempId: job.id,
          kind: job.kind,
          scheduled: job.scheduled,
          reason: failure,
        ),
      );
      return;
    }

    // #***! отложенное просто наружу, в базу и кэш не пишем
    if (job.scheduled) {
      _events.add(
        UploadJobDone(
          chatId: job.chatId,
          tempId: job.id,
          kind: job.kind,
          scheduled: true,
          scheduledTime: job.scheduledTime,
          fileId: job.resultFileId,
          fileToken: job.resultFileToken,
        ),
      );
      return;
    }

    // #***! настоящее в базу, временное удаляем
    final message = real!;
    try {
      await AppDatabase.saveMessages([message.toDbRow()]);
      if (message.id != job.id) {
        await AppDatabase.deleteMessage(job.accountId, job.chatId, job.id);
      }
    } catch (e) {
      logger.w('UploadService: не удалось сохранить сообщение: $e');
    }
    _replaceInSessionCache(job.accountId, job.chatId, job.id, message);
    _remember(job.id, message);
    _events.add(
      UploadJobDone(
        chatId: job.chatId,
        tempId: job.id,
        kind: job.kind,
        scheduled: false,
        message: message,
        fileId: job.resultFileId,
        fileToken: job.resultFileToken,
      ),
    );
  }

  // #***! память о завершённых пока экран чата не подхватит
  void _remember(String tempId, CachedMessage? real) {
    if (_completed.length + _failed.length > _historyLimit) {
      _completed.clear();
      _failed.clear();
    }
    if (real == null) {
      _failed.add(tempId);
    } else {
      _completed[tempId] = real;
    }
  }

  // #***! фото пулом воркеров, первая ошибка рубит весь альбом
  Future<List<String?>> _uploadPhotos(
    List<({File file, GalleryItem? item})> jobs,
    UploadJob job,
  ) async {
    final tokens = List<String?>.filled(jobs.length, null);
    var nextIndex = 0;
    var failed = false;

    Future<void> worker() async {
      while (!failed) {
        final i = nextIndex++;
        if (i >= jobs.length) return;
        final token = await _uploadOnePhoto(jobs[i], i, job);
        if (token == null) {
          failed = true;
          return;
        }
        tokens[i] = token;
      }
    }

    final workerCount = jobs.length < _photoConcurrency
        ? jobs.length
        : _photoConcurrency;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return tokens;
  }

  // #***! перед заливкой пережимаем, три попытки с растущей паузой
  Future<String?> _uploadOnePhoto(
    ({File file, GalleryItem? item}) photo,
    int index,
    UploadJob job,
  ) async {
    File file;
    try {
      file = await optimizePhotoForUpload(photo.file, item: photo.item);
    } catch (e) {
      logger.w('optimize photo: $e');
      file = photo.file;
    }
    for (var attempt = 0; attempt < _photoAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: attempt));
        job.resetSlot(index);
      }
      try {
        final url = await messagesModule.requestPhotoUploadUrl();
        if (url == null || url.isEmpty) continue;
        final token = await fileUploader.uploadPhoto(
          Uri.parse(url),
          file,
          filename: _photoFilename(file),
          onProgress: (sent, total) => job.report(index, sent, total),
        );
        if (token != null) return token;
      } catch (e) {
        logger.w('uploadOnePhoto attempt ${attempt + 1}: $e');
      }
    }
    return null;
  }

  // #***! имя файла из пути иначе photo.jpg
  String _photoFilename(File file) {
    final segments = file.uri.pathSegments;
    final name = segments.isNotEmpty ? segments.last : '';
    return name.isNotEmpty ? name : 'photo.jpg';
  }

  // #***! подменяем плейсхолдер в кэше чата чтоб не мигнуло
  void _replaceInSessionCache(
    int accountId,
    int chatId,
    String tempId,
    CachedMessage? real,
  ) {
    final cached = MessageSessionCache.get(accountId, chatId);
    if (cached == null) return;
    final list = List<CachedMessage>.of(cached.messages);
    final idx = list.indexWhere((m) => m.id == tempId);
    if (idx == -1) return;
    list[idx] = real ?? list[idx].copyWith(status: 'error');
    MessageSessionCache.save(
      accountId,
      chatId,
      list,
      reachedStart: cached.reachedStart,
    );
  }
}

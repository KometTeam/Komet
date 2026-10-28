import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/cache/message_session_cache.dart';
import '../../core/crypto/outgoing_message_policy.dart';
import '../../core/storage/token_storage.dart';
import '../../core/media/gallery_source.dart';
import '../../core/media/image_optimizer.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/logger.dart';
import '../../main.dart' show api, fileUploader, messagesModule;
import '../../models/attachment.dart';
import '../../models/upload_bytes.dart';
import 'chats.dart' show chats;
import 'file_uploader.dart';
import 'messages.dart';
import 'upload_notification_service.dart';

export 'upload_notification_service.dart' show UploadKind;
export '../../models/upload_bytes.dart';

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

class UploadJobUpdated extends UploadJobEvent {
  const UploadJobUpdated({
    required super.chatId,
    required super.tempId,
    required super.kind,
    required super.scheduled,
    required this.message,
  });

  final CachedMessage message;
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
class UploadJobCancelled extends UploadJobEvent {
  const UploadJobCancelled({
    required super.chatId,
    required super.tempId,
    required super.kind,
    required super.scheduled,
  });
}

class UploadFailure implements Exception {
  const UploadFailure(this.message);

  final String message;

  @override
  String toString() => 'UploadFailure($message)';
}

class UploadCancelled implements Exception {
  const UploadCancelled();

  @override
  String toString() => 'UploadCancelled';
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
    CachedMessage? placeholder,
    this.scheduledTime,
    this.encryptedPayload = false,
  }) : _placeholder = placeholder,
       _session = api.session,
       _sessionEpoch = api.sessionEpoch,
       _accountEpoch = TokenStorage.accountEpoch,
       _slots = slots < 1 ? 1 : slots,
       _sent = List<int>.filled(slots < 1 ? 1 : slots, 0),
       _total = List<int>.filled(slots < 1 ? 1 : slots, 0),
       progress = ValueNotifier<List<UploadBytes>>(
         List<UploadBytes>.filled(slots < 1 ? 1 : slots, UploadBytes.none),
       ),
       bytes = ValueNotifier<UploadBytes>(UploadBytes(0, totalBytes)) {
    if (_slots == 1 && totalBytes > 0) _total[0] = totalBytes;
    _activeSlots = List<int>.generate(_slots, (i) => i);
    _slotCancels = List.generate(_slots, (_) => Completer<void>());
  }

  final String id;
  final int accountId;
  final int chatId;
  final UploadKind kind;
  final String? filename;
  final int totalBytes;
  CachedMessage? _placeholder;
  CachedMessage? get placeholder => _placeholder;
  final int? scheduledTime;
  final bool encryptedPayload;
  final Object? _session;
  final int _sessionEpoch;
  final int _accountEpoch;

  void ensureSendAllowed() {
    if (_session == null ||
        !identical(api.session, _session) ||
        api.sessionEpoch != _sessionEpoch ||
        TokenStorage.accountEpoch != _accountEpoch) {
      throw const UploadFailure('account_changed');
    }
    OutgoingMessagePolicy.requireSupported(
      accountId,
      chatId,
      encryptedPayload: encryptedPayload,
    );
  }

  final ValueNotifier<List<UploadBytes>> progress;
  final ValueNotifier<UploadBytes> bytes;

  int? resultFileId;
  String? resultFileToken;

  final int _slots;
  final List<int> _sent;
  final List<int> _total;
  final Completer<void> _cancelSignal = Completer<void>();
  late final List<int> _activeSlots;
  late final List<Completer<void>> _slotCancels;

  bool get scheduled => scheduledTime != null;
  int get slots => _slots;
  bool get isCancelled => _cancelSignal.isCompleted;
  Future<void> get cancelled => _cancelSignal.future;
  int get activeSlotCount => _activeSlots.length;

  bool isSlotCancelled(int slot) => _slotCancels[slot].isCompleted;

  Future<void> slotCancelled(int slot) =>
      Future.any([_cancelSignal.future, _slotCancels[slot].future]);

  bool dropVisible(int visibleIndex) {
    if (visibleIndex < 0 || visibleIndex >= _activeSlots.length) return false;
    final slot = _activeSlots.removeAt(visibleIndex);
    if (!_slotCancels[slot].isCompleted) _slotCancels[slot].complete();
    final placeholder = _placeholder;
    final attachments = placeholder?.attachments;
    if (placeholder != null &&
        attachments != null &&
        visibleIndex < attachments.length) {
      _placeholder = placeholder.copyWith(
        attachments: [...attachments]..removeAt(visibleIndex),
      );
    }
    _publish();
    return true;
  }

  // #***! прогресс по слоту, дальше считаем общий
  void cancel() {
    if (!isCancelled) _cancelSignal.complete();
  }

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
    final slots = [
      for (final slot in _activeSlots) UploadBytes(_sent[slot], _total[slot]),
    ];
    var sumSent = 0;
    var sumTotal = 0;
    var fractionSum = 0.0;
    for (final slot in slots) {
      sumSent += slot.sent;
      sumTotal += slot.total;
      fractionSum += slot.fraction;
    }
    progress.value = slots;
    bytes.value = UploadBytes(sumSent, sumTotal);
    UploadNotificationService.report(
      id,
      sent: sumSent,
      total: sumTotal,
      fraction: slots.isEmpty ? 0 : fractionSum / slots.length,
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

  void cancel(String tempId) => _jobs[tempId]?.cancel();

  void cancelItem(String tempId, int index) {
    final job = _jobs[tempId];
    if (job == null) return;
    if (job.activeSlotCount <= 1) {
      job.cancel();
      return;
    }
    if (!job.dropVisible(index)) return;
    final placeholder = job.placeholder;
    if (placeholder == null || job.scheduled) return;
    MessageSessionCache.replace(
      job.accountId,
      job.chatId,
      job.id,
      (_) => placeholder,
    );
    _events.add(
      UploadJobUpdated(
        chatId: job.chatId,
        tempId: job.id,
        kind: job.kind,
        scheduled: job.scheduled,
        message: placeholder,
      ),
    );
  }

  ValueListenable<List<UploadBytes>>? progressFor(String tempId) =>
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
        if (job.isCancelled) throw const UploadCancelled();
        final kept = [
          for (var i = 0; i < tokens.length; i++)
            if (!job.isSlotCancelled(i)) tokens[i],
        ];
        if (kept.isEmpty) throw const UploadCancelled();
        if (kept.any((token) => token == null)) {
          throw const UploadFailure('upload_failed');
        }
        final sent = await messagesModule.sendPhotoMessage(
          chatId,
          kept.cast<String>(),
          caption: caption.isEmpty ? null : caption,
          scheduledTime: scheduledTime,
          beforeSend: job.ensureSendAllowed,
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
        final info = await messagesModule.requestVideoUploadUrl(
          beforeSend: job.ensureSendAllowed,
        );
        if (info == null || info.url.isEmpty) {
          throw const UploadFailure('no_upload_url');
        }
        job.ensureSendAllowed();
        final ok = await fileUploader.uploadVideoFile(
          Uri.parse(info.url),
          file,
          onProgress: (sent, total) => job.report(0, sent, total),
          cancel: job.cancelled,
        );
        if (!ok) throw const UploadFailure('upload_failed');
        job.markUploaded();
        if (job.isCancelled) throw const UploadCancelled();
        final sent = await messagesModule.sendVideoMessage(
          chatId,
          info.token,
          caption: caption.isEmpty ? null : caption,
          scheduledTime: scheduledTime,
          beforeSend: job.ensureSendAllowed,
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
      requestUpload: (beforeSend) async {
        final info = await messagesModule.requestAudioUploadUrl(
          beforeSend: beforeSend,
        );
        return info == null ? null : (url: info.url, token: info.token);
      },
      send: (token, beforeSend) => messagesModule.sendAudioMessage(
        chatId,
        token,
        duration: durationMs,
        wave: wave,
        beforeSend: beforeSend,
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
      requestUpload: (beforeSend) async {
        final info = await messagesModule.requestVideoNoteUploadUrl(
          beforeSend: beforeSend,
        );
        return info == null ? null : (url: info.url, token: info.token);
      },
      send: (token, beforeSend) => messagesModule.sendVideoNoteMessage(
        chatId,
        token,
        duration: durationMs,
        beforeSend: beforeSend,
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
    required Future<({String url, String token})?> Function(
      void Function() beforeSend,
    )
    requestUpload,
    required Future<Map<String, dynamic>?> Function(
      String token,
      VoidCallback beforeSend,
    )
    send,
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
          final info = await requestUpload(job.ensureSendAllowed);
          if (info == null || info.url.isEmpty) {
            throw const UploadFailure('no_upload_url');
          }
          job.ensureSendAllowed();
          final ok = await fileUploader.uploadMediaFile(
            Uri.parse(info.url),
            file,
            onProgress: (sent, total) => job.report(0, sent, total),
            cancel: job.cancelled,
          );
          if (!ok) throw const UploadFailure('upload_failed');
          job.markUploaded();
          final sent = await send(info.token, job.ensureSendAllowed);
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
    String? text,
    int? scheduledTime,
    bool encryptedPayload = false,
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
        encryptedPayload: encryptedPayload,
      ),
      (job) async {
        final done = await _uploadFile(
          chatId: chatId,
          job: job,
          source: source,
          filename: filename,
          size: size,
          text: text,
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
          sealedText: base?.sealedText,
          e2ee: base?.e2ee ?? CachedMessage.e2eeNone,
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
    String? text,
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
          text: text,
          encryptedPayload: job.encryptedPayload,
          scheduledTime: scheduledTime,
          beforeSend: job.ensureSendAllowed,
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
    job.cancelled.then((_) {
      if (!result.isCompleted) result.completeError(const UploadCancelled());
    });
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
      await OutgoingMessagePolicy.load(job.accountId);
      final activeAccount = await TokenStorage.getActiveAccountId();
      if (activeAccount != job.accountId) {
        throw const UploadFailure('account_changed');
      }
      job.ensureSendAllowed();
      // #***! для отложенного null это нормально, оно уйдёт позже
      final work = upload(job);
      unawaited(work.then<void>((_) {}, onError: (_) {}));
      real = await Future.any<CachedMessage?>([
        work,
        job.cancelled.then<CachedMessage?>((_) => null),
      ]);
      if (real == null && !job.scheduled && !job.isCancelled) {
        failure = 'send_failed';
      }
    } catch (e) {
      failure = e is UploadFailure ? e.message : e.toString();
    }

    UploadNotificationService.end(job.id);
    _jobs.remove(job.id);

    if (job.isCancelled && real == null) {
      _dropCancelled(job);
      _events.add(
        UploadJobCancelled(
          chatId: job.chatId,
          tempId: job.id,
          kind: job.kind,
          scheduled: job.scheduled,
        ),
      );
      return;
    }

    if (failure != null) {
      logger.w('UploadService: ${job.id} — $failure');
      if (!job.scheduled) {
        _replaceInSessionCache(job.accountId, job.chatId, job.id, null);
        _remember(job.id, null);
        _syncChatPreview(job.placeholder, 'error');
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
    _syncChatPreview(message, 'sent', replacesTime: job.placeholder?.time);
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

  // #***! строку в списке чатов двигаем отсюда, а не с экрана чата: его
  void _dropCancelled(UploadJob job) {
    if (job.scheduled || job.placeholder == null) return;
    MessageSessionCache.removeMessage(job.accountId, job.chatId, job.id);
    unawaited(chats.reconcileLastMessage(job.accountId, job.chatId));
  }

  // могли закрыть сразу после выбора файла, а загрузка живёт дальше
  void _syncChatPreview(
    CachedMessage? message,
    String status, {
    int? replacesTime,
  }) {
    if (message == null) return;
    unawaited(
      chats.applyOutgoingMessage(
        message,
        status: status,
        replacesTime: replacesTime,
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
        if (job.isSlotCancelled(i)) continue;
        final token = await _uploadOnePhoto(jobs[i], i, job);
        if (token == null) {
          if (job.isSlotCancelled(i)) continue;
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

  Future<String?> _uploadOnePhoto(
    ({File file, GalleryItem? item}) photo,
    int index,
    UploadJob job,
  ) => uploadPhoto(
    photo.file,
    item: photo.item,
    cancel: job.slotCancelled(index),
    onProgress: (sent, total) => job.report(index, sent, total),
    onRetry: () => job.resetSlot(index),
    beforeSend: job.ensureSendAllowed,
  );

  // #***! перед заливкой пережимаем, три попытки с растущей паузой
  Future<String?> uploadPhoto(
    File source, {
    GalleryItem? item,
    required Future<void> cancel,
    required void Function(int sent, int total) onProgress,
    VoidCallback? onRetry,
    VoidCallback? beforeSend,
  }) async {
    var stopped = false;
    unawaited(cancel.then((_) => stopped = true));
    File file;
    try {
      file = await optimizePhotoForUpload(source, item: item);
    } catch (e) {
      logger.w('optimize photo: $e');
      file = source;
    }
    try {
      if (stopped) return null;
      for (var attempt = 0; attempt < _photoAttempts; attempt++) {
        if (attempt > 0) {
          await Future.delayed(Duration(seconds: attempt));
          if (stopped) return null;
          onRetry?.call();
        }
        try {
          final url = await messagesModule.requestPhotoUploadUrl(
            beforeSend: beforeSend,
          );
          if (url == null || url.isEmpty) continue;
          beforeSend?.call();
          final token = await fileUploader.uploadPhoto(
            Uri.parse(url),
            file,
            filename: _photoFilename(file),
            onProgress: onProgress,
            cancel: cancel,
          );
          if (token != null) return token;
        } catch (e) {
          logger.w('uploadPhoto attempt ${attempt + 1}: $e');
        }
        if (stopped) return null;
      }
      return null;
    } finally {
      if (file.path != source.path) {
        unawaited(file.delete().catchError((_) => file));
      }
    }
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
    MessageSessionCache.replace(
      accountId,
      chatId,
      tempId,
      (current) => real ?? current.copyWith(status: 'error'),
    );
  }
}

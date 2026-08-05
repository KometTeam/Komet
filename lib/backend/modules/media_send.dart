import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/cache/message_session_cache.dart';
import '../../core/media/gallery_source.dart';
import '../../core/media/image_optimizer.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/logger.dart';
import '../../main.dart' show fileUploader, messagesModule;
import 'messages.dart';

sealed class MediaSendEvent {
  final int chatId;
  final String tempId;
  final bool scheduled;

  const MediaSendEvent({
    required this.chatId,
    required this.tempId,
    required this.scheduled,
  });
}

class MediaSendDone extends MediaSendEvent {
  final CachedMessage? message;
  final int? scheduledTime;

  const MediaSendDone({
    required super.chatId,
    required super.tempId,
    required super.scheduled,
    this.message,
    this.scheduledTime,
  });
}

class MediaSendFailed extends MediaSendEvent {
  const MediaSendFailed({
    required super.chatId,
    required super.tempId,
    required super.scheduled,
  });
}

class MediaSendService {
  MediaSendService._();

  static final MediaSendService instance = MediaSendService._();

  final StreamController<MediaSendEvent> _events =
      StreamController<MediaSendEvent>.broadcast();

  static const int _historyLimit = 60;
  static const int _photoConcurrency = 3;
  static const int _photoAttempts = 3;

  final Map<String, ValueNotifier<List<double>>> _progress = {};
  final Map<int, List<CachedMessage>> _pending = {};
  final Map<String, CachedMessage> _completed = {};
  final Set<String> _failed = {};

  Stream<MediaSendEvent> get events => _events.stream;

  ValueListenable<List<double>>? progressFor(String tempId) =>
      _progress[tempId];

  List<CachedMessage> pendingFor(int chatId) =>
      List<CachedMessage>.unmodifiable(_pending[chatId] ?? const []);

  CachedMessage? completedFor(String tempId) => _completed[tempId];

  bool didFail(String tempId) => _failed.contains(tempId);

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
      accountId: accountId,
      chatId: chatId,
      tempId: tempId,
      placeholder: placeholder,
      scheduledTime: scheduledTime,
      slots: jobs.length,
      upload: (progress) async {
        final tokens = await _uploadPhotos(jobs, progress);
        if (tokens.any((t) => t == null)) return null;
        return messagesModule.sendPhotoMessage(
          chatId,
          tokens.cast<String>(),
          caption: caption.isEmpty ? null : caption,
          scheduledTime: scheduledTime,
        );
      },
    );
  }

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
      accountId: accountId,
      chatId: chatId,
      tempId: tempId,
      placeholder: placeholder,
      scheduledTime: scheduledTime,
      slots: 1,
      upload: (progress) async {
        final info = await messagesModule.requestVideoUploadUrl();
        if (info == null || info.url.isEmpty) return null;
        final ok = await fileUploader.uploadVideoFile(
          Uri.parse(info.url),
          file,
          onProgress: (sent, total) {
            if (total > 0) {
              progress.value = [(sent / total).clamp(0.0, 1.0)];
            }
          },
        );
        if (!ok) return null;
        progress.value = const [1];
        return messagesModule.sendVideoMessage(
          chatId,
          info.token,
          caption: caption.isEmpty ? null : caption,
          scheduledTime: scheduledTime,
        );
      },
    );
  }

  Future<void> _run({
    required int accountId,
    required int chatId,
    required String tempId,
    required int slots,
    required Future<Map<String, dynamic>?> Function(
      ValueNotifier<List<double>> progress,
    )
    upload,
    CachedMessage? placeholder,
    int? scheduledTime,
  }) async {
    final scheduled = scheduledTime != null;
    final progress = ValueNotifier<List<double>>(
      List<double>.filled(slots < 1 ? 1 : slots, 0),
    );
    _progress[tempId] = progress;
    if (placeholder != null) {
      (_pending[chatId] ??= <CachedMessage>[]).add(placeholder);
    }

    try {
      final serverMsg = await upload(progress);
      if (serverMsg == null) throw Exception('send_failed');

      if (scheduled) {
        _finish(chatId, tempId);
        _events.add(
          MediaSendDone(
            chatId: chatId,
            tempId: tempId,
            scheduled: true,
            scheduledTime: scheduledTime,
          ),
        );
        return;
      }

      final real = CachedMessage.fromPushPayload(accountId, chatId, serverMsg);
      try {
        await AppDatabase.saveMessages([real.toDbRow()]);
        if (real.id != tempId) {
          await AppDatabase.deleteMessage(accountId, chatId, tempId);
        }
      } catch (e) {
        logger.w('MediaSendService: не удалось сохранить сообщение: $e');
      }
      _replaceInSessionCache(accountId, chatId, tempId, real);
      _remember(tempId, real);
      _finish(chatId, tempId);
      _events.add(
        MediaSendDone(
          chatId: chatId,
          tempId: tempId,
          scheduled: false,
          message: real,
        ),
      );
    } catch (e) {
      logger.w('MediaSendService: $e');
      if (!scheduled) {
        _replaceInSessionCache(accountId, chatId, tempId, null);
        _remember(tempId, null);
      }
      _finish(chatId, tempId);
      _events.add(
        MediaSendFailed(chatId: chatId, tempId: tempId, scheduled: scheduled),
      );
    }
  }

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

  Future<List<String?>> _uploadPhotos(
    List<({File file, GalleryItem? item})> jobs,
    ValueNotifier<List<double>> progress,
  ) async {
    final tokens = List<String?>.filled(jobs.length, null);
    var nextIndex = 0;
    var failed = false;

    Future<void> worker() async {
      while (!failed) {
        final i = nextIndex++;
        if (i >= jobs.length) return;
        final token = await _uploadOnePhoto(jobs[i], i, progress);
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

  Future<String?> _uploadOnePhoto(
    ({File file, GalleryItem? item}) job,
    int index,
    ValueNotifier<List<double>> progress,
  ) async {
    File file;
    try {
      file = await optimizePhotoForUpload(job.file, item: job.item);
    } catch (e) {
      logger.w('optimize photo: $e');
      file = job.file;
    }
    for (var attempt = 0; attempt < _photoAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: attempt));
        _setSlot(progress, index, 0);
      }
      try {
        final url = await messagesModule.requestPhotoUploadUrl();
        if (url == null || url.isEmpty) continue;
        final token = await fileUploader.uploadPhoto(
          Uri.parse(url),
          file,
          filename: _photoFilename(file),
          onProgress: (sent, total) {
            if (total <= 0) return;
            _setSlot(progress, index, (sent / total).clamp(0.0, 1.0));
          },
        );
        if (token != null) return token;
      } catch (e) {
        logger.w('uploadOnePhoto attempt ${attempt + 1}: $e');
      }
    }
    return null;
  }

  void _setSlot(
    ValueNotifier<List<double>> progress,
    int index,
    double value,
  ) {
    final next = List<double>.from(progress.value);
    if (index < next.length) {
      next[index] = value;
      progress.value = next;
    }
  }

  String _photoFilename(File file) {
    final segments = file.uri.pathSegments;
    final name = segments.isNotEmpty ? segments.last : '';
    return name.isNotEmpty ? name : 'photo.jpg';
  }

  void _finish(int chatId, String tempId) {
    _progress.remove(tempId);
    final list = _pending[chatId];
    if (list == null) return;
    list.removeWhere((m) => m.id == tempId);
    if (list.isEmpty) _pending.remove(chatId);
  }

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

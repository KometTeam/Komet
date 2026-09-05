import 'dart:async';
import 'dart:convert' show base64Encode;
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../backend/modules/contacts.dart';
import '../../../../backend/modules/messages.dart';
import '../../../../backend/modules/upload_service.dart';
import '../../../../core/crypto/chat_crypto_service.dart';
import '../../../../core/crypto/encrypted_photo.dart';
import '../../../../core/media/desktop_video_probe.dart';
import '../../../../core/media/gallery_source.dart';
import '../../../../core/media/video_transcoder.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../main.dart';
import '../../../../models/attachment.dart';
import '../../../../models/sticker.dart';
import '../../../widgets/sending_clock_icon.dart';
import 'chat_controller.dart';
import 'upload_status.dart';

// #***! отправка вложений (фото/видео/голос/файл/стикер/контакт/локация) +
// отслеживание статуса загрузки; текстовые сообщения остаются в chat_screen.dart
class ChatMediaSendController {
  final ChatController chatController;
  final ValueNotifier<bool> showAttachmentPanel;
  final ValueNotifier<UploadStatus> uploadStatus;
  final VoidCallback bumpMessages;
  final VoidCallback scrollToBottom;
  final void Function(String?) setLastSentId;
  final void Function(String) notify;
  final bool Function() isMounted;
  final bool Function() encryptionEnabled;
  final Future<String?> Function(String text, {bool notify}) encryptOutgoing;
  final VoidCallback markHasScheduled;

  ChatMediaSendController({
    required this.chatController,
    required this.showAttachmentPanel,
    required this.uploadStatus,
    required this.bumpMessages,
    required this.scrollToBottom,
    required this.setLastSentId,
    required this.notify,
    required this.isMounted,
    required this.encryptionEnabled,
    required this.encryptOutgoing,
    required this.markHasScheduled,
  });

  int get _myId => chatController.myId;
  int get _chatId => chatController.chatId;

  String? _uploadStatusJobId;
  ValueListenable<UploadBytes>? _uploadStatusBytes;

  void dispose() {
    _detachUploadStatus();
  }

  CachedMessage addOptimisticMediaMessage(MessageAttachment attachment) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tempId = chatController.nextTempId();
    final msg = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: _chatId,
      senderId: _myId,
      time: now,
      status: 'sending',
      attachments: [attachment],
    );
    setLastSentId(tempId);
    chatController.addMessage(msg);
    bumpMessages();
    Haptics.send();
    scrollToBottom();
    return msg;
  }

  void updateFileMessageStatus(
    String tempId,
    String status, {
    FileAttachment? attachment,
    String? realId,
  }) {
    if (!isMounted()) return;
    final idx = chatController.indexOfId(tempId);
    if (idx == -1) return;
    final old = chatController.messages[idx];
    chatController.setMessageAt(
      idx,
      CachedMessage(
        id: realId != null && realId.isNotEmpty ? realId : tempId,
        accountId: old.accountId,
        chatId: old.chatId,
        senderId: old.senderId,
        text: old.text,
        time: old.time,
        status: status,
        payload: old.payload,
        attachments: attachment != null ? [attachment] : old.attachments,
      ),
    );
    bumpMessages();
  }

  void failPhotoMessage(String tempId) {
    final idx = chatController.indexOfId(tempId);
    if (idx != -1) {
      chatController.setMessageAt(
        idx,
        chatController.messages[idx].copyWith(status: 'error'),
      );
      bumpMessages();
    }
    Haptics.error();
  }

  Future<void> sendAttachMessage(
    List<MessageAttachment> optimistic,
    Future<Map<String, dynamic>?> Function() send,
  ) async {
    if (_myId == 0) return;
    final tempId = chatController.nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;

    final tempMessage = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: _chatId,
      senderId: _myId,
      time: now,
      status: 'sending',
      attachments: optimistic,
    );
    chatController.addMessage(tempMessage);
    setLastSentId(tempId);
    bumpMessages();
    Haptics.send();
    scrollToBottom();

    try {
      final serverMsg = await send();
      if (!isMounted()) return;
      final idx = chatController.indexOfId(tempId);
      if (idx == -1) return;
      if (serverMsg == null) {
        updateFileMessageStatus(tempId, 'error');
        notify('Ошибка отправки');
        return;
      }
      final real = CachedMessage.fromPushPayload(_myId, _chatId, serverMsg);
      chatController.setMessageAt(idx, real);
      bumpMessages();
      unawaited(chatController.persistOutgoing(real, removeId: tempId));
    } catch (e) {
      if (!isMounted()) return;
      updateFileMessageStatus(tempId, 'error');
      notify('Ошибка: $e');
    }
  }

  Future<void> sendSticker(StickerItem sticker) async {
    await sendAttachMessage([
      StickerAttachment(
        stickerId: sticker.id.toString(),
        baseUrl: sticker.url,
        lottieUrl: sticker.lottieUrl,
        width: sticker.width,
        height: sticker.height,
      ),
    ], () => messagesModule.sendStickerMessage(_chatId, sticker.id));
  }

  Future<void> sendContact(CachedContact contact) async {
    final last = contact.lastName;
    final fullName = (last != null && last.isNotEmpty)
        ? '${contact.firstName} $last'
        : contact.firstName;
    await sendAttachMessage([
      ContactAttachment(
        contactId: contact.id,
        firstName: contact.firstName,
        lastName: last,
        name: fullName,
        photoUrl: contact.baseUrl,
      ),
    ], () => messagesModule.sendContactMessage(_chatId, contact.id));
  }

  Future<Position?> _resolveCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (isMounted()) notify('Включите геолокацию');
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (isMounted()) notify('Нет доступа к геолокации');
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      if (isMounted()) notify('Не удалось получить геопозицию');
      return null;
    }
  }

  Future<void> shareLocation() async {
    final position = await _resolveCurrentPosition();
    if (position == null || !isMounted()) return;
    final lat = position.latitude;
    final lon = position.longitude;
    await sendAttachMessage([
      LocationAttachment(latitude: lat, longitude: lon, zoom: 15),
    ], () => messagesModule.sendLocationMessage(_chatId, lat, lon));
  }

  Uint8List _buildWave(List<double> amps, {int bars = 80}) {
    final out = Uint8List(bars);
    if (amps.isEmpty) return out;
    for (var i = 0; i < bars; i++) {
      final start = (i * amps.length / bars).floor();
      final end = (((i + 1) * amps.length / bars).ceil()).clamp(
        start + 1,
        amps.length,
      );
      var peak = 0.0;
      for (var j = start; j < end; j++) {
        if (amps[j] > peak) peak = amps[j];
      }
      out[i] = (peak * 120).round().clamp(0, 120);
    }
    return out;
  }

  Future<void> sendVoice(File file, int durationMs, List<double> amps) async {
    if (_myId == 0) {
      try {
        await file.delete();
      } catch (_) {}
      return;
    }
    final wave = _buildWave(amps);
    final placeholder = addOptimisticMediaMessage(
      AudioAttachment(
        duration: durationMs,
        waveform: String.fromCharCodes(wave),
      ),
    );

    unawaited(
      UploadService.instance.sendVoice(
        accountId: _myId,
        chatId: _chatId,
        tempId: placeholder.id,
        file: file,
        durationMs: durationMs,
        wave: wave,
        placeholder: placeholder,
      ),
    );
  }

  Future<void> sendVideoNote(File file, int durationMs) async {
    if (_myId == 0) {
      try {
        await file.delete();
      } catch (_) {}
      return;
    }
    final placeholder = addOptimisticMediaMessage(
      VideoAttachment(duration: durationMs, videoType: 1, localPath: file.path),
    );

    unawaited(
      UploadService.instance.sendVideoNote(
        accountId: _myId,
        chatId: _chatId,
        tempId: placeholder.id,
        file: file,
        durationMs: durationMs,
        placeholder: placeholder,
      ),
    );
  }

  Future<void> sendHistoryFile(FileHistoryEntry entry) async {
    final tempId = addOptimisticMediaMessage(
      FileAttachment(
        fileId: entry.fileId,
        fileToken: entry.token,
        name: entry.filename,
        size: entry.size,
      ),
    ).id;
    showAttachmentPanel.value = false;
    try {
      final realId = await messagesModule.sendFileMessage(
        _chatId,
        entry.fileId,
        token: entry.token,
      );
      updateFileMessageStatus(
        tempId,
        realId != null ? 'sent' : 'error',
        realId: realId,
      );
    } catch (_) {
      updateFileMessageStatus(tempId, 'error');
    }
  }

  Future<bool> sendFileById(int fileId) async {
    final tempId = addOptimisticMediaMessage(
      FileAttachment(fileId: fileId),
    ).id;
    try {
      final realId = await messagesModule.sendFileMessage(_chatId, fileId);
      final ok = realId != null;
      if (!isMounted()) return ok;
      if (ok) {
        FileHistoryCache.add(
          FileHistoryEntry(fileId: fileId, sentAt: DateTime.now()),
        );
        updateFileMessageStatus(tempId, 'sent', realId: realId);
        showAttachmentPanel.value = false;
      } else {
        updateFileMessageStatus(tempId, 'error');
        notify('Ошибка отправки');
      }
      return ok;
    } catch (e) {
      updateFileMessageStatus(tempId, 'error');
      if (isMounted()) notify('Ошибка: $e');
      return false;
    }
  }

  Future<void> sendPhotos(
    List<PickedPhoto> picked,
    String caption, {
    bool waitForUpload = false,
  }) async {
    if (_myId == 0) return;
    if (encryptionEnabled()) return sendEncryptedPhotos(picked, caption);
    final videos = picked.where((ph) => ph.item.isVideo).toList();
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.isEmpty && videos.isEmpty) return;

    for (var i = 0; i < videos.length; i++) {
      final cap = (photos.isEmpty && i == 0) ? caption : '';
      await sendVideo(videos[i], cap);
    }
    if (photos.isEmpty) return;

    final jobs = <({File file, GalleryItem? item})>[];
    final attachments = <PhotoAttachment>[];
    for (final photo in photos) {
      final edited = photo.editedFile;
      final file =
          edited ?? photo.item.localFile ?? await photo.item.originFile();
      if (file == null) continue;
      final dim = edited != null
          ? await imageFileDimensions(edited)
          : await photo.item.dimensions();
      jobs.add((file: file, item: edited == null ? photo.item : null));
      attachments.add(
        PhotoAttachment(localPath: file.path, width: dim?.$1, height: dim?.$2),
      );
    }
    if (jobs.isEmpty || !isMounted()) return;

    final tempId = chatController.nextTempId();
    final placeholder = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: _chatId,
      senderId: _myId,
      text: caption.isEmpty ? null : caption,
      time: DateTime.now().millisecondsSinceEpoch,
      status: 'sending',
      attachments: attachments,
    );

    chatController.addMessage(placeholder);
    setLastSentId(tempId);
    bumpMessages();
    Haptics.send();
    scrollToBottom();

    final upload = UploadService.instance.sendPhotos(
      accountId: _myId,
      chatId: _chatId,
      tempId: tempId,
      jobs: jobs,
      caption: caption,
      placeholder: placeholder,
    );
    if (waitForUpload) {
      await upload;
    } else {
      unawaited(upload);
    }
  }

  Future<void> sendVideo(
    PickedPhoto video,
    String caption, {
    int? scheduledTime,
  }) async {
    if (_myId == 0) return;
    final file =
        video.editedFile ??
        video.item.localFile ??
        await video.item.originFile();
    if (file == null || !isMounted()) return;

    final edited = video.editedFile;
    var durationMs = video.item.duration?.inMilliseconds;
    var dims = await video.item.dimensions();
    Uint8List? thumbBytes;
    if (edited != null) {
      final info = await VideoTranscoder.probe(edited.path);
      if (info != null) {
        if (info.durationMs > 0) durationMs = info.durationMs;
        if (info.width > 0 && info.height > 0) dims = (info.width, info.height);
      }
      final frames = await VideoTranscoder.frames(edited.path, const [
        0,
      ], size: 512);
      if (frames.isNotEmpty) thumbBytes = frames.first;
    }
    if (durationMs == null && DesktopVideoProbe.supported) {
      durationMs = (await DesktopVideoProbe.duration(
        file.path,
      ))?.inMilliseconds;
    }
    if (thumbBytes == null) {
      try {
        thumbBytes = await video.item.thumbnail(512);
      } catch (_) {}
    }
    if (!isMounted()) return;
    final thumbData = thumbBytes == null || thumbBytes.isEmpty
        ? null
        : 'data:image/jpeg;base64,${base64Encode(thumbBytes)}';

    final tempId = chatController.nextTempId();
    CachedMessage? placeholder;

    if (scheduledTime != null) {
      notify('Загрузка…');
    } else {
      placeholder = CachedMessage(
        id: tempId,
        accountId: _myId,
        chatId: _chatId,
        senderId: _myId,
        text: caption.isEmpty ? null : caption,
        time: DateTime.now().millisecondsSinceEpoch,
        status: 'sending',
        attachments: [
          VideoAttachment(
            duration: durationMs,
            localPath: file.path,
            previewData: thumbData,
            width: dims?.$1,
            height: dims?.$2,
          ),
        ],
      );
      chatController.addMessage(placeholder);
      setLastSentId(tempId);
      bumpMessages();
      Haptics.send();
      scrollToBottom();
    }

    unawaited(
      UploadService.instance.sendVideo(
        accountId: _myId,
        chatId: _chatId,
        tempId: tempId,
        file: file,
        caption: caption,
        placeholder: placeholder,
        scheduledTime: scheduledTime,
      ),
    );
  }

  Future<void> sendScheduledPhotos(
    List<PickedPhoto> picked,
    String caption,
    int scheduledTime,
  ) async {
    if (_myId == 0) return;
    final videos = picked.where((ph) => ph.item.isVideo).toList();
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.isEmpty && videos.isEmpty) return;

    for (var i = 0; i < videos.length; i++) {
      final cap = (photos.isEmpty && i == 0) ? caption : '';
      await sendVideo(videos[i], cap, scheduledTime: scheduledTime);
    }
    if (photos.isEmpty) return;

    final jobs = <({File file, GalleryItem? item})>[];
    for (final photo in photos) {
      final edited = photo.editedFile;
      final file =
          edited ?? photo.item.localFile ?? await photo.item.originFile();
      if (file != null) {
        jobs.add((file: file, item: edited == null ? photo.item : null));
      }
    }
    if (jobs.isEmpty || !isMounted()) return;

    notify('Загрузка…');
    unawaited(
      UploadService.instance.sendPhotos(
        accountId: _myId,
        chatId: _chatId,
        tempId: chatController.nextTempId(),
        jobs: jobs,
        caption: caption,
        scheduledTime: scheduledTime,
      ),
    );
  }

  Future<void> sendEncryptedPhotos(
    List<PickedPhoto> picked,
    String caption,
  ) async {
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.length != picked.length && isMounted()) {
      notify('Видео пока нельзя зашифровать');
    }
    if (photos.isEmpty) return;

    for (final photo in photos) {
      final source =
          photo.editedFile ??
          photo.item.localFile ??
          await photo.item.originFile();
      if (source == null || !isMounted()) continue;

      showAttachmentPanel.value = false;
      uploadStatus.value = const UploadStatus(active: true);
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      final prepared = await prepareEncryptedPhoto(
        accountId: _myId,
        chatId: _chatId,
        source: source,
        stamp: stamp,
      );
      if (!isMounted()) return;
      if (!prepared.isOk) {
        uploadStatus.value = const UploadStatus();
        notify(
          prepared.failure == CryptoFailure.noKey
              ? 'Не задан ключ шифрования'
              : 'Не удалось зашифровать фото',
        );
        return;
      }

      final encrypted = prepared.file!;
      await uploadAsFile(
        source: encrypted,
        filename: 'photo_$stamp$kEncryptedPhotoExtension',
        size: await encrypted.length(),
      );
      if (!isMounted()) return;
    }

    if (caption.isNotEmpty) {
      final wire = await encryptOutgoing(caption);
      if (wire != null && isMounted()) {
        await messagesModule.sendMessage(_myId, _chatId, wire);
      }
    }
  }

  Future<void> uploadAsFile({
    required File source,
    required String filename,
    required int size,
    int? scheduledTime,
  }) async {
    if (_myId == 0) return;

    showAttachmentPanel.value = false;

    final placeholder = scheduledTime != null
        ? null
        : addOptimisticMediaMessage(
            FileAttachment(name: filename, size: size),
          );

    final sending = UploadService.instance.sendFile(
      accountId: _myId,
      chatId: _chatId,
      tempId: placeholder?.id ?? chatController.nextTempId(),
      source: source,
      filename: filename,
      size: size,
      placeholder: placeholder,
      scheduledTime: scheduledTime,
    );
    syncUploadStatus();
    await sending;
  }

  void syncUploadStatus() {
    final job = UploadService.instance.activeFileJob(_chatId);
    if (job?.id == _uploadStatusJobId) return;
    _detachUploadStatus();
    if (job == null) {
      uploadStatus.value = const UploadStatus();
      return;
    }
    _uploadStatusJobId = job.id;
    _uploadStatusBytes = job.bytes;
    job.bytes.addListener(_onUploadBytes);
    _onUploadBytes();
  }

  void _onUploadBytes() {
    final bytes = _uploadStatusBytes?.value;
    if (bytes == null) return;
    uploadStatus.value = UploadStatus(
      active: true,
      sent: bytes.sent,
      total: bytes.total,
    );
  }

  void _detachUploadStatus() {
    _uploadStatusBytes?.removeListener(_onUploadBytes);
    _uploadStatusBytes = null;
    _uploadStatusJobId = null;
  }

  void mergePendingMedia() {
    syncUploadStatus();
    final service = UploadService.instance;
    var changed = false;

    final messages = chatController.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (!isSendingStatus(msg.status)) continue;
      final done = service.completedFor(msg.id);
      if (done != null) {
        if (done.id != msg.id && chatController.containsId(done.id)) {
          chatController.removeMessageAt(i);
        } else {
          chatController.setMessageAt(i, done);
        }
        changed = true;
        continue;
      }
      if (service.didFail(msg.id)) {
        chatController.setMessageAt(i, msg.copyWith(status: 'error'));
        changed = true;
      }
    }

    for (final msg in service.pendingFor(_chatId)) {
      if (chatController.containsId(msg.id)) continue;
      chatController.addMessage(msg);
      changed = true;
    }

    if (changed) bumpMessages();
  }

  String? _uploadFailureText(UploadKind kind, String reason) {
    final detail = switch (reason) {
      'no_upload_url' => 'сервер не выдал ссылку',
      'upload_failed' => 'загрузка отклонена',
      'send_failed' => 'сервер не принял сообщение',
      _ => reason,
    };
    return switch (kind) {
      UploadKind.file => 'Ошибка: $reason',
      UploadKind.videoNote => 'Кружок не отправлен: $detail',
      UploadKind.voice => 'Голосовое не отправлено: $detail',
      UploadKind.photo || UploadKind.video => null,
    };
  }

  void onUploadEvent(UploadJobEvent event) {
    if (!isMounted() || event.chatId != _chatId) return;
    syncUploadStatus();
    if (event is UploadJobDone) {
      if (event.scheduled) {
        Haptics.send();
        markHasScheduled();
        final at = event.scheduledTime;
        notify(
          at == null
              ? 'Запланировано'
              : 'Запланировано на '
                    '${formatDateTimeWords(DateTime.fromMillisecondsSinceEpoch(at))}',
        );
        return;
      }
      final real = event.message;
      if (real == null) return;
      final idx = chatController.indexOfId(event.tempId);
      if (idx != -1) {
        chatController.setMessageAt(idx, real);
        bumpMessages();
      }
    } else if (event is UploadJobFailed) {
      if (event.scheduled) {
        Haptics.error();
        notify('Не удалось запланировать');
        return;
      }
      failPhotoMessage(event.tempId);
      final text = _uploadFailureText(event.kind, event.reason);
      if (text != null) notify(text);
    }
  }
}

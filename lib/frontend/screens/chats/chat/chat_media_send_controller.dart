import 'dart:async';
import '../../../../core/crypto/outgoing_message_policy.dart';
import 'dart:convert' show base64Encode;
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/contacts.dart';
import '../../../../backend/modules/messages.dart';
import '../../../../backend/modules/outgoing_reply.dart';
import '../../../../backend/modules/upload_service.dart';
import '../../../../core/cache/message_session_cache.dart';
import '../../../../core/crypto/chat_crypto_service.dart';
import '../../../../core/crypto/e2ee_service.dart';
import '../../../../core/storage/app_database.dart';

import 'package:komet_crypto/komet_crypto.dart' show ContentType;

import '../../../../core/crypto/encrypted_photo.dart';
import '../../../../core/media/desktop_video_probe.dart';
import '../../../../core/media/gallery_source.dart';
import '../../../../core/media/video_transcoder.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../models/attachment.dart';
import '../../../../models/sticker.dart';
import '../../../widgets/sending_clock_icon.dart';
import 'chat_controller.dart';
import 'upload_status.dart';

typedef _AttachSender =
    Future<Map<String, dynamic>?> Function(
      void Function() beforeSend,
      OutgoingReply? reply,
    );

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
  final Future<bool> Function() confirmSend;
  final OutgoingReply? Function() takeReply;

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
    required this.confirmSend,
    required this.markHasScheduled,
    required this.takeReply,
  });

  int get _myId => chatController.myId;
  int get _chatId => chatController.chatId;

  AppLocalizations get _l10n =>
      AppLocalizations.of(KometApp.navigatorKey.currentContext!)!;

  bool get _e2eeActive => E2eeService.instance.isActive(_myId, _chatId);

  String? _uploadStatusJobId;
  ValueListenable<UploadBytes>? _uploadStatusBytes;

  void dispose() {
    _detachUploadStatus();
  }

  CachedMessage addOptimisticMediaMessage(
    MessageAttachment attachment, {
    String? text,
    Uint8List? sealedText,
    int e2ee = CachedMessage.e2eeNone,
    OutgoingReply? reply,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tempId = chatController.nextTempId();
    final unquoted = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: _chatId,
      senderId: _myId,
      text: text,
      time: now,
      status: 'sending',
      attachments: [attachment],
      sealedText: sealedText,
      e2ee: e2ee,
    );
    final msg = reply?.quotedIn(unquoted) ?? unquoted;
    setLastSentId(tempId);
    chatController.addMessage(msg);
    _previewInChatList(msg, 'sending');
    bumpMessages();
    Haptics.send();
    scrollToBottom();
    return msg;
  }

  bool canRetry(CachedMessage message) {
    if (message.status != 'error') return false;
    if (message.e2ee != CachedMessage.e2eeNone) return false;
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) return false;
    return switch (attachments.first) {
      PhotoAttachment() => attachments.every(
        (a) => a is PhotoAttachment && a.localPath != null,
      ),
      VideoAttachment(:final localPath) => localPath != null,
      AudioAttachment(:final localPath) => localPath != null,
      FileAttachment(:final localPath, :final fileId) =>
        localPath != null || fileId != null,
      StickerAttachment(:final stickerId) => int.tryParse('$stickerId') != null,
      ContactAttachment(:final contactId) => contactId != null,
      LocationAttachment(:final latitude, :final longitude) =>
        latitude != null && longitude != null,
      _ => false,
    };
  }

  Future<void> retry(CachedMessage failed) async {
    if (_myId == 0 || !canRetry(failed)) return;
    if (encryptionEnabled()) {
      notify(_l10n.chatEncryptedUnsupportedMedia);
      return;
    }
    final attachments = failed.attachments!;
    for (final attachment in attachments) {
      final path = switch (attachment) {
        PhotoAttachment(:final localPath) => localPath,
        VideoAttachment(:final localPath) => localPath,
        AudioAttachment(:final localPath) => localPath,
        FileAttachment(:final localPath) => localPath,
        _ => null,
      };
      if (path != null && !await File(path).exists()) {
        if (isMounted()) notify(_l10n.chatRetryFileMissing);
        return;
      }
    }
    if (!isMounted()) return;
    final reply = OutgoingReply.fromPayload(
      failed.payload,
      accountId: _myId,
      chatId: _chatId,
    );
    final caption = failed.text ?? '';
    _discard(failed);
    switch (attachments.first) {
      case PhotoAttachment():
        await _sendPhotoAlbum(
          [
            for (final photo in attachments.cast<PhotoAttachment>())
              PickedPhoto(item: GalleryItem.fromFile(File(photo.localPath!))),
          ],
          caption,
          waitForUpload: false,
          reply: reply,
        );
      case VideoAttachment(videoType: 1, :final localPath?, :final duration):
        _sendVideoNoteFile(File(localPath), duration ?? 0, reply);
      case VideoAttachment(:final localPath?):
        await sendVideo(
          PickedPhoto(item: GalleryItem.fromFile(File(localPath))),
          caption,
          reply: reply,
        );
      case AudioAttachment(:final localPath?, :final duration, :final waveform):
        _sendVoiceFile(
          File(localPath),
          duration ?? 0,
          Uint8List.fromList((waveform ?? '').codeUnits),
          reply,
        );
      case FileAttachment(:final localPath?, :final name, :final size):
        final source = File(localPath);
        await _uploadAsFile(
          source: source,
          filename: name ?? source.uri.pathSegments.last,
          size: size ?? await source.length(),
          text: failed.text,
          reply: reply,
        );
      case final FileAttachment stored:
        await _sendStoredFile(
          stored,
          reply: reply,
          beforeSend: _unencryptedSendGuard(),
        );
      case final StickerAttachment sticker:
        await _sendAttach(
          [sticker],
          _stickerSender(int.parse('${sticker.stickerId}')),
          reply: reply,
          beforeSend: _unencryptedSendGuard(),
        );
      case final ContactAttachment contact:
        await _sendAttach(
          [contact],
          _contactSender(contact.contactId!),
          reply: reply,
          beforeSend: _unencryptedSendGuard(),
        );
      case final LocationAttachment location:
        await _sendAttach(
          [location],
          _locationSender(
            location.latitude!,
            location.longitude!,
            location.zoom ?? 15,
          ),
          reply: reply,
          beforeSend: _unencryptedSendGuard(),
        );
      default:
        break;
    }
  }

  void _discard(CachedMessage failed) {
    final index = chatController.indexOfId(failed.id);
    if (index != -1) chatController.removeMessageAt(index);
    MessageSessionCache.removeMessage(_myId, _chatId, failed.id);
    unawaited(AppDatabase.deleteMessage(_myId, _chatId, failed.id));
    bumpMessages();
  }

  // #***! строку в списке чатов обновляем сами: экран чата к моменту
  // доставки могли уже закрыть, а пуш на своё сообщение не приходит
  void _previewInChatList(
    CachedMessage message,
    String status, {
    int? replacesTime,
  }) {
    unawaited(
      chats.applyOutgoingMessage(
        message,
        status: status,
        replacesTime: replacesTime,
      ),
    );
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
    _previewInChatList(chatController.messages[idx], status);
    bumpMessages();
  }

  void failPhotoMessage(String tempId) {
    final idx = chatController.indexOfId(tempId);
    if (idx != -1) {
      chatController.setMessageAt(
        idx,
        chatController.messages[idx].copyWith(status: 'error'),
      );
      _previewInChatList(chatController.messages[idx], 'error');
      bumpMessages();
    }
    Haptics.error();
  }

  void Function() _unencryptedSendGuard() {
    final session = api.session;
    final accountId = _myId;
    final chatId = _chatId;
    return () {
      if (session == null || !identical(api.session, session)) {
        throw StateError('Account changed during sending');
      }
      OutgoingMessagePolicy.requireSupported(accountId, chatId);
    };
  }

  Future<void> sendAttachMessage(
    List<MessageAttachment> optimistic,
    Future<Map<String, dynamic>?> Function(
      void Function() beforeSend,
      OutgoingReply? reply,
    )
    send,
  ) async {
    if (_myId == 0) return;
    final beforeSend = _unencryptedSendGuard();
    if (encryptionEnabled()) {
      notify(_l10n.chatEncryptedUnsupportedMedia);
      return;
    }
    if (!await confirmSend() || !isMounted()) return;
    await _sendAttach(
      optimistic,
      send,
      reply: takeReply(),
      beforeSend: beforeSend,
    );
  }

  Future<void> _sendAttach(
    List<MessageAttachment> optimistic,
    Future<Map<String, dynamic>?> Function(
      void Function() beforeSend,
      OutgoingReply? reply,
    )
    send, {
    required OutgoingReply? reply,
    required void Function() beforeSend,
  }) async {
    final tempId = chatController.nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;

    final unquoted = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: _chatId,
      senderId: _myId,
      time: now,
      status: 'sending',
      attachments: optimistic,
    );
    final tempMessage = reply?.quotedIn(unquoted) ?? unquoted;
    chatController.addMessage(tempMessage);
    setLastSentId(tempId);
    _previewInChatList(tempMessage, 'sending');
    bumpMessages();
    Haptics.send();
    scrollToBottom();

    try {
      final serverMsg = await send(beforeSend, reply);
      final mounted = isMounted();
      final idx = chatController.indexOfId(tempId);
      if (mounted && idx == -1) return;
      if (serverMsg == null) {
        if (mounted) {
          updateFileMessageStatus(tempId, 'error');
          notify(_l10n.cloudStorageSendError);
        } else {
          _previewInChatList(tempMessage.copyWith(status: 'error'), 'error');
        }
        return;
      }
      final real = OutgoingReply.keepQuote(
        CachedMessage.fromPushPayload(_myId, _chatId, serverMsg),
        tempMessage,
      );
      if (mounted) {
        chatController.setMessageAt(idx, real);
        bumpMessages();
      }
      MessageSessionCache.replace(_myId, _chatId, tempId, (_) => real);
      unawaited(chatController.persistOutgoing(real, removeId: tempId));
      _previewInChatList(real, 'sent', replacesTime: now);
    } catch (e) {
      if (!isMounted()) return;
      updateFileMessageStatus(tempId, 'error');
      notify(_l10n.devicesGenericError('$e'));
    }
  }

  Future<void> sendSticker(StickerItem sticker) async {
    await sendAttachMessage(
      [
        StickerAttachment(
          stickerId: sticker.id.toString(),
          baseUrl: sticker.url,
          lottieUrl: sticker.lottieUrl,
          width: sticker.width,
          height: sticker.height,
        ),
      ],
      _stickerSender(sticker.id),
    );
  }

  _AttachSender _stickerSender(int stickerId) =>
      (beforeSend, reply) => messagesModule.sendStickerMessage(
        _chatId,
        stickerId,
        beforeSend: beforeSend,
        replyToMessageId: reply?.messageId,
        replySourceChatId: reply?.sourceChatId,
      );

  _AttachSender _contactSender(int contactId) =>
      (beforeSend, reply) => messagesModule.sendContactMessage(
        _chatId,
        contactId,
        beforeSend: beforeSend,
        replyToMessageId: reply?.messageId,
        replySourceChatId: reply?.sourceChatId,
      );

  _AttachSender _locationSender(double lat, double lon, double zoom) =>
      (beforeSend, reply) => messagesModule.sendLocationMessage(
        _chatId,
        lat,
        lon,
        zoom: zoom,
        beforeSend: beforeSend,
        replyToMessageId: reply?.messageId,
        replySourceChatId: reply?.sourceChatId,
      );

  Future<void> sendContact(CachedContact contact) async {
    final last = contact.lastName;
    final fullName = (last != null && last.isNotEmpty)
        ? '${contact.firstName} $last'
        : contact.firstName;
    await sendAttachMessage(
      [
        ContactAttachment(
          contactId: contact.id,
          firstName: contact.firstName,
          lastName: last,
          name: fullName,
          photoUrl: contact.baseUrl,
        ),
      ],
      _contactSender(contact.id),
    );
  }

  Future<Position?> _resolveCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (isMounted()) notify(_l10n.chatMediaSendEnableLocation);
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (isMounted()) notify(_l10n.chatMediaSendNoLocationAccess);
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      if (isMounted()) notify(_l10n.chatMediaSendLocationFailed);
      return null;
    }
  }

  Future<void> shareLocation() async {
    final position = await _resolveCurrentPosition();
    if (position == null || !isMounted()) return;
    final lat = position.latitude;
    final lon = position.longitude;
    await sendAttachMessage(
      [LocationAttachment(latitude: lat, longitude: lon, zoom: 15)],
      _locationSender(lat, lon, 15),
    );
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
    if (encryptionEnabled()) {
      try {
        await file.delete();
      } catch (_) {}
      if (isMounted()) notify(_l10n.chatEncryptedUnsupportedMedia);
      return;
    }
    if (_myId == 0 || !await confirmSend()) {
      try {
        await file.delete();
      } catch (_) {}
      return;
    }
    _sendVoiceFile(file, durationMs, _buildWave(amps), takeReply());
  }

  void _sendVoiceFile(
    File file,
    int durationMs,
    Uint8List wave,
    OutgoingReply? reply,
  ) {
    final placeholder = addOptimisticMediaMessage(
      AudioAttachment(
        duration: durationMs,
        waveform: String.fromCharCodes(wave),
        localPath: file.path,
      ),
      reply: reply,
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
        reply: reply,
      ),
    );
  }

  Future<void> sendVideoNote(File file, int durationMs) async {
    if (encryptionEnabled()) {
      try {
        await file.delete();
      } catch (_) {}
      if (isMounted()) notify(_l10n.chatEncryptedUnsupportedMedia);
      return;
    }
    if (_myId == 0 || !await confirmSend()) {
      try {
        await file.delete();
      } catch (_) {}
      return;
    }
    _sendVideoNoteFile(file, durationMs, takeReply());
  }

  void _sendVideoNoteFile(File file, int durationMs, OutgoingReply? reply) {
    final placeholder = addOptimisticMediaMessage(
      VideoAttachment(duration: durationMs, videoType: 1, localPath: file.path),
      reply: reply,
    );

    unawaited(
      UploadService.instance.sendVideoNote(
        accountId: _myId,
        chatId: _chatId,
        tempId: placeholder.id,
        file: file,
        durationMs: durationMs,
        placeholder: placeholder,
        reply: reply,
      ),
    );
  }

  Future<void> sendHistoryFile(FileHistoryEntry entry) async {
    final beforeSend = _unencryptedSendGuard();
    if (encryptionEnabled()) {
      notify(_l10n.chatEncryptedUnsupportedMedia);
      return;
    }
    if (!await confirmSend() || !isMounted()) return;
    showAttachmentPanel.value = false;
    await _sendStoredFile(
      FileAttachment(
        fileId: entry.fileId,
        fileToken: entry.token,
        name: entry.filename,
        size: entry.size,
      ),
      reply: takeReply(),
      beforeSend: beforeSend,
    );
  }

  Future<void> _sendStoredFile(
    FileAttachment file, {
    required OutgoingReply? reply,
    required void Function() beforeSend,
  }) async {
    final fileId = file.fileId;
    if (fileId == null) return;
    final tempId = addOptimisticMediaMessage(file, reply: reply).id;
    try {
      final realId = await messagesModule.sendFileMessage(
        _chatId,
        fileId,
        token: file.fileToken,
        beforeSend: beforeSend,
        replyToMessageId: reply?.messageId,
        replySourceChatId: reply?.sourceChatId,
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
    if (encryptionEnabled()) {
      notify(_l10n.chatEncryptedUnsupportedMedia);
      return false;
    }
    final beforeSend = _unencryptedSendGuard();
    if (!await confirmSend() || !isMounted()) return false;
    final reply = takeReply();
    final tempId = addOptimisticMediaMessage(
      FileAttachment(fileId: fileId),
      reply: reply,
    ).id;
    try {
      final realId = await messagesModule.sendFileMessage(
        _chatId,
        fileId,
        beforeSend: beforeSend,
        replyToMessageId: reply?.messageId,
        replySourceChatId: reply?.sourceChatId,
      );
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
        notify(_l10n.cloudStorageSendError);
      }
      return ok;
    } catch (e) {
      updateFileMessageStatus(tempId, 'error');
      if (isMounted()) notify(_l10n.devicesGenericError('$e'));
      return false;
    }
  }

  Future<void> sendPhotos(
    List<PickedPhoto> picked,
    String caption, {
    bool waitForUpload = false,
    bool separate = false,
    VoidCallback? onConfirmed,
  }) async {
    if (_myId == 0) return;
    if (!await confirmSend() || !isMounted()) return;
    onConfirmed?.call();
    var reply = takeReply();
    if (encryptionEnabled()) {
      return sendEncryptedPhotos(picked, caption, reply: reply);
    }
    final videos = picked.where((ph) => ph.item.isVideo).toList();
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.isEmpty && videos.isEmpty) return;

    for (var i = 0; i < videos.length; i++) {
      final cap = (photos.isEmpty && i == 0) ? caption : '';
      await sendVideo(videos[i], cap, reply: reply);
      reply = null;
    }
    if (photos.isEmpty) return;

    if (separate && photos.length > 1) {
      for (var i = 0; i < photos.length; i++) {
        await _sendPhotoAlbum(
          [photos[i]],
          i == 0 ? caption : '',
          waitForUpload: waitForUpload,
          reply: reply,
        );
        reply = null;
      }
      return;
    }
    await _sendPhotoAlbum(
      photos,
      caption,
      waitForUpload: waitForUpload,
      reply: reply,
    );
  }

  Future<void> _sendPhotoAlbum(
    List<PickedPhoto> photos,
    String caption, {
    required bool waitForUpload,
    OutgoingReply? reply,
  }) async {
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
    final unquoted = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: _chatId,
      senderId: _myId,
      text: caption.isEmpty ? null : caption,
      time: DateTime.now().millisecondsSinceEpoch,
      status: 'sending',
      attachments: attachments,
    );
    final placeholder = reply?.quotedIn(unquoted) ?? unquoted;

    chatController.addMessage(placeholder);
    setLastSentId(tempId);
    _previewInChatList(placeholder, 'sending');
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
      reply: reply,
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
    OutgoingReply? reply,
  }) async {
    if (_myId == 0) return;
    if (encryptionEnabled()) {
      notify(_l10n.chatMediaSendVideoNotEncryptable);
      return;
    }
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
      notify(_l10n.fontSettingsLoading);
    } else {
      final unquoted = CachedMessage(
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
      placeholder = reply?.quotedIn(unquoted) ?? unquoted;
      chatController.addMessage(placeholder);
      setLastSentId(tempId);
      _previewInChatList(placeholder, 'sending');
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
        reply: reply,
      ),
    );
  }

  Future<void> sendScheduledPhotos(
    List<PickedPhoto> picked,
    String caption,
    int scheduledTime, {
    bool separate = false,
    VoidCallback? onConfirmed,
  }) async {
    if (_myId == 0) return;
    if (encryptionEnabled()) {
      notify(_l10n.chatMediaSendScheduledEncryptedPhotos);
      return;
    }
    if (!await confirmSend() || !isMounted()) return;
    onConfirmed?.call();
    final videos = picked.where((ph) => ph.item.isVideo).toList();
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.isEmpty && videos.isEmpty) return;
    var reply = takeReply();

    for (var i = 0; i < videos.length; i++) {
      final cap = (photos.isEmpty && i == 0) ? caption : '';
      await sendVideo(
        videos[i],
        cap,
        scheduledTime: scheduledTime,
        reply: reply,
      );
      reply = null;
    }
    if (photos.isEmpty) return;

    if (separate && photos.length > 1) {
      for (var i = 0; i < photos.length; i++) {
        await _sendScheduledPhotoAlbum(
          [photos[i]],
          i == 0 ? caption : '',
          scheduledTime,
          reply: reply,
        );
        reply = null;
      }
      return;
    }
    await _sendScheduledPhotoAlbum(
      photos,
      caption,
      scheduledTime,
      reply: reply,
    );
  }

  Future<void> _sendScheduledPhotoAlbum(
    List<PickedPhoto> photos,
    String caption,
    int scheduledTime, {
    OutgoingReply? reply,
  }) async {
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

    if (encryptionEnabled()) {
      notify(_l10n.chatMediaSendScheduledEncryptedPhotos);
      return;
    }

    notify(_l10n.fontSettingsLoading);
    unawaited(
      UploadService.instance.sendPhotos(
        accountId: _myId,
        chatId: _chatId,
        tempId: chatController.nextTempId(),
        jobs: jobs,
        caption: caption,
        scheduledTime: scheduledTime,
        reply: reply,
      ),
    );
  }

  Future<void> sendEncryptedPhotos(
    List<PickedPhoto> picked,
    String caption, {
    OutgoingReply? reply,
  }) async {
    var pendingReply = reply;
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.length != picked.length && isMounted()) {
      notify(_l10n.chatMediaSendVideoNotEncryptable);
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
      if (_e2eeActive) {
        final e2eePhoto = await prepareE2eePhoto(source: source, stamp: stamp);
        if (!isMounted()) return;
        final wire = e2eePhoto == null
            ? null
            : await E2eeService.instance.encryptBytes(
                _myId,
                _chatId,
                ContentType.file,
                e2eePhoto.ticket,
              );
        if (e2eePhoto == null || wire == null) {
          uploadStatus.value = const UploadStatus();
          if (isMounted()) {
            notify(_l10n.chatMediaSendPhotoEncryptFailed);
          }
          return;
        }
        final sealed = await E2eeService.instance.sealBytes(
          _myId,
          _chatId,
          e2eePhoto.ticket,
        );
        if (!isMounted()) return;
        await _uploadAsFile(
          source: e2eePhoto.file,
          filename: 'photo_$stamp$kE2eePhotoExtension',
          encryptedPayload: true,
          size: await e2eePhoto.file.length(),
          text: wire,
          sealedText: sealed,
          e2ee: CachedMessage.e2eeFile,
          reply: pendingReply,
        );
        pendingReply = null;
        if (!isMounted()) return;
        continue;
      }
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
              ? _l10n.chatMediaSendNoEncryptionKey
              : _l10n.chatMediaSendPhotoEncryptFailed,
        );
        return;
      }

      final encrypted = prepared.file!;
      await _uploadAsFile(
        source: encrypted,
        filename: 'photo_$stamp$kEncryptedPhotoExtension',
        encryptedPayload: true,
        size: await encrypted.length(),
        reply: pendingReply,
      );
      pendingReply = null;
      if (!isMounted()) return;
    }

    if (caption.isNotEmpty) {
      final wire = await encryptOutgoing(caption);
      if (wire != null && isMounted()) {
        await messagesModule.sendMessage(
          _myId,
          _chatId,
          wire,
          encryptedPayload: wire != caption,
        );
      }
    }
  }

  Future<void> uploadAsFile({
    required File source,
    required String filename,
    required int size,
    int? scheduledTime,
    String? text,
    Uint8List? sealedText,
    int e2ee = CachedMessage.e2eeNone,
  }) async {
    if (_myId == 0) return;
    if (!await confirmSend() || !isMounted()) return;
    await _uploadAsFile(
      source: source,
      filename: filename,
      size: size,
      scheduledTime: scheduledTime,
      text: text,
      sealedText: sealedText,
      e2ee: e2ee,
      reply: takeReply(),
    );
  }

  Future<void> _uploadAsFile({
    required File source,
    required String filename,
    required int size,
    int? scheduledTime,
    String? text,
    Uint8List? sealedText,
    int e2ee = CachedMessage.e2eeNone,
    bool encryptedPayload = false,
    OutgoingReply? reply,
  }) async {
    if (_myId == 0) return;

    showAttachmentPanel.value = false;

    final placeholder = scheduledTime != null
        ? null
        : addOptimisticMediaMessage(
            FileAttachment(
              name: filename,
              size: size,
              localPath: encryptedPayload ? null : source.path,
            ),
            text: text,
            sealedText: sealedText,
            e2ee: e2ee,
            reply: reply,
          );

    final sending = UploadService.instance.sendFile(
      accountId: _myId,
      chatId: _chatId,
      tempId: placeholder?.id ?? chatController.nextTempId(),
      source: source,
      filename: filename,
      size: size,
      placeholder: placeholder,
      text: text,
      scheduledTime: scheduledTime,
      encryptedPayload: encryptedPayload,
      reply: reply,
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

  String _uploadFailureText(UploadKind kind, String reason) {
    final l10n = _l10n;
    final detail = switch (reason) {
      'no_upload_url' => l10n.chatMediaSendNoUploadUrl,
      'upload_failed' => l10n.chatMediaSendUploadRejected,
      'send_failed' => l10n.chatMediaSendServerRejected,
      _ => reason,
    };
    return switch (kind) {
      UploadKind.file => l10n.chatMediaSendFileFailed(detail),
      UploadKind.videoNote => l10n.chatMediaSendVideoNoteFailed(detail),
      UploadKind.voice => l10n.chatMediaSendVoiceFailed(detail),
      UploadKind.photo => l10n.chatMediaSendPhotoFailed(detail),
      UploadKind.video => l10n.chatMediaSendVideoFailed(detail),
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
              ? _l10n.chatMediaSendScheduled
              : _l10n.chatMediaSendScheduledAt(
                  formatDateTimeWords(
                    _l10n,
                    DateTime.fromMillisecondsSinceEpoch(at),
                  ),
                ),
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
    } else if (event is UploadJobUpdated) {
      final idx = chatController.indexOfId(event.tempId);
      if (idx == -1) return;
      chatController.setMessageAt(idx, event.message);
      bumpMessages();
    } else if (event is UploadJobCancelled) {
      if (event.scheduled) return;
      final idx = chatController.indexOfId(event.tempId);
      if (idx == -1) return;
      chatController.removeMessageAt(idx);
      bumpMessages();
    } else if (event is UploadJobFailed) {
      if (event.scheduled) {
        Haptics.error();
        notify(_l10n.chatMediaSendScheduleFailed);
        return;
      }
      failPhotoMessage(event.tempId);
      notify(_uploadFailureText(event.kind, event.reason));
    }
  }
}

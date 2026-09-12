import 'dart:async';
import 'dart:io';

import '../../core/media/gallery_source.dart';
import '../../core/media/share_thumbnail.dart';
import '../../core/media/video_transcoder.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/logger.dart';
import '../../models/attachment.dart';
import '../../models/chat_preview_media.dart';
import '../../models/shared_payload.dart';
import '../../main.dart';
import 'chats.dart';
import 'messages.dart';
import 'upload_service.dart';

// #***! файл из системного поделиться с миниатюрой и размерами
class PreparedShareFile {
  final SharedFile source;
  final String? thumbDataUri;
  final int? width;
  final int? height;
  final int? durationMs;

  const PreparedShareFile({
    required this.source,
    this.thumbDataUri,
    this.width,
    this.height,
    this.durationMs,
  });

  SharedFileKind get kind => source.kind;
  File get file => source.file;
}

// #***! весь пакет шаринга после подготовки
class PreparedShare {
  final List<PreparedShareFile> files;
  final String? text;

  const PreparedShare({required this.files, this.text});

  List<PreparedShareFile> get photos =>
      files.where((f) => f.kind == SharedFileKind.photo).toList();

  List<PreparedShareFile> get videos =>
      files.where((f) => f.kind == SharedFileKind.video).toList();

  List<PreparedShareFile> get documents =>
      files.where((f) => f.kind == SharedFileKind.file).toList();

  bool get isTextOnly => files.isEmpty;

  // #***! миниатюры и размеры считаем один раз а не на каждый чат
  static Future<PreparedShare> prepare(SharedPayload payload) async {
    final prepared = <PreparedShareFile>[];
    for (final source in payload.files) {
      prepared.add(await _prepareOne(source));
    }
    return PreparedShare(files: prepared, text: payload.text);
  }

  // #***! у фото размеры из файла, у видео через probe
  static Future<PreparedShareFile> _prepareOne(SharedFile source) async {
    final thumb = await sharedThumbnailDataUri(source);
    switch (source.kind) {
      case SharedFileKind.photo:
        final dim = await imageFileDimensions(source.file);
        return PreparedShareFile(
          source: source,
          thumbDataUri: thumb,
          width: dim?.$1,
          height: dim?.$2,
        );
      case SharedFileKind.video:
        VideoInfo? info;
        try {
          info = await VideoTranscoder.probe(source.path);
        } catch (e) {
          logger.w('Поделиться: probe ${source.path}: $e');
        }
        return PreparedShareFile(
          source: source,
          thumbDataUri: thumb,
          width: (info?.width ?? 0) > 0 ? info!.width : null,
          height: (info?.height ?? 0) > 0 ? info!.height : null,
          durationMs: (info?.durationMs ?? 0) > 0 ? info!.durationMs : null,
        );
      case SharedFileKind.file:
        return PreparedShareFile(source: source);
    }
  }
}

// #***! итог отправки для уведомления
class ShareSendResult {
  final int chatCount;
  final int messageCount;

  const ShareSendResult({required this.chatCount, required this.messageCount});
}

// #***! отправка сразу в несколько чатов
class ShareSender {
  ShareSender._();

  // #***! плейсхолдеры ждущие загрузку, по ним обновится строка чата
  static final Map<
    String,
    ({int accountId, int chatId, String text, String? preview, int time})
  >
  _tracked = {};

  static StreamSubscription<UploadJobEvent>? _sub;

  static void _track(
    String tempId, {
    required int accountId,
    required int chatId,
    required String text,
    required String? preview,
    required int time,
  }) {
    _sub ??= UploadService.instance.events.listen(_onUploadEvent);
    _tracked[tempId] = (
      accountId: accountId,
      chatId: chatId,
      text: text,
      preview: preview,
      time: time,
    );
  }

  // #***! загрузка кончилась, правим строку чата на отправлено или ошибку
  static void _onUploadEvent(UploadJobEvent event) {
    final entry = _tracked.remove(event.tempId);
    if (entry == null) return;
    final status = event is UploadJobDone ? 'sent' : 'error';
    final messageId = event is UploadJobDone
        ? (event.message?.id ?? event.tempId)
        : event.tempId;
    unawaited(
      chats
          .applyOutgoing(
            entry.accountId,
            entry.chatId,
            messageId: messageId,
            time: entry.time,
            text: entry.text,
            status: status,
            preview: entry.preview,
          )
          .catchError((Object e) {
            logger.w('Поделиться: не обновить превью чата ${entry.chatId}: $e');
          }),
    );
  }

  // #***! по очереди во все выбранные чаты
  static Future<ShareSendResult> send({
    required int accountId,
    required List<int> chatIds,
    required PreparedShare share,
    required String caption,
  }) async {
    var messages = 0;
    for (final chatId in chatIds) {
      messages += await _sendToChat(
        accountId: accountId,
        chatId: chatId,
        share: share,
        caption: caption,
      );
    }
    logger.i(
      'Поделиться: отправлено $messages сообщений в ${chatIds.length} чатов',
    );
    return ShareSendResult(chatCount: chatIds.length, messageCount: messages);
  }

  // #***! фото альбомом, видео и документы по одному
  static Future<int> _sendToChat({
    required int accountId,
    required int chatId,
    required PreparedShare share,
    required String caption,
  }) async {
    if (share.isTextOnly) {
      final text = caption.trim().isNotEmpty
          ? caption
          : (share.text ?? '').trim();
      if (text.isEmpty) return 0;
      await _sendText(accountId: accountId, chatId: chatId, text: text);
      return 1;
    }

    final photos = share.photos;
    final videos = share.videos;
    final documents = share.documents;

    var used = false;
    // #***! подпись только к первому сообщению
    String take() {
      if (used || caption.isEmpty) return '';
      used = true;
      return caption;
    }

    var count = 0;
    if (photos.isNotEmpty) {
      await _sendPhotos(
        accountId: accountId,
        chatId: chatId,
        photos: photos,
        caption: take(),
      );
      count++;
    }
    for (final video in videos) {
      await _sendVideo(
        accountId: accountId,
        chatId: chatId,
        video: video,
        caption: take(),
      );
      count++;
    }
    for (final document in documents) {
      await _sendDocument(
        accountId: accountId,
        chatId: chatId,
        document: document,
        caption: take(),
      );
      count++;
    }
    return count;
  }

  // #***! текст уходит сразу, плейсхолдер чтоб сообщение появилось мгновенно
  static Future<void> _sendText({
    required int accountId,
    required int chatId,
    required String text,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tempId = UploadService.instance.newTempId();
    final placeholder = CachedMessage(
      id: tempId,
      accountId: accountId,
      chatId: chatId,
      senderId: accountId,
      text: text,
      time: now,
      status: 'sending',
    );
    await _persist(placeholder);
    await _bumpChat(
      accountId: accountId,
      chatId: chatId,
      messageId: tempId,
      time: now,
      text: text,
      preview: null,
      status: 'sending',
    );

    // #***! сервер дал настоящий id, временный удаляем
    String realId = tempId;
    var status = 'sent';
    try {
      final sent = await messagesModule.sendMessage(accountId, chatId, text);
      if (sent.isNotEmpty) realId = sent;
    } catch (e) {
      logger.w('Поделиться: текст в $chatId не ушёл: $e');
      status = 'error';
    }
    final settled = CachedMessage(
      id: realId,
      accountId: accountId,
      chatId: chatId,
      senderId: accountId,
      text: text,
      time: now,
      status: status,
    );
    await _persist(settled, removeId: realId == tempId ? null : tempId);
    await _bumpChat(
      accountId: accountId,
      chatId: chatId,
      messageId: realId,
      time: now,
      text: text,
      preview: null,
      status: status,
    );
  }

  // #***! фото одним альбомом, загрузка в фоне
  static Future<void> _sendPhotos({
    required int accountId,
    required int chatId,
    required List<PreparedShareFile> photos,
    required String caption,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tempId = UploadService.instance.newTempId();

    final jobs = <({File file, GalleryItem? item})>[];
    final attachments = <PhotoAttachment>[];
    for (final photo in photos) {
      jobs.add((file: photo.file, item: null));
      attachments.add(
        PhotoAttachment(
          localPath: photo.file.path,
          previewData: photo.thumbDataUri,
          width: photo.width,
          height: photo.height,
        ),
      );
    }
    if (jobs.isEmpty) return;

    final label = photos.length > 1 ? 'Изображения' : 'Изображение';
    final preview = _preview(
      kind: ChatPreviewKind.photo,
      files: photos,
      label: caption.isEmpty ? label : null,
    );
    final placeholder = CachedMessage(
      id: tempId,
      accountId: accountId,
      chatId: chatId,
      senderId: accountId,
      text: caption.isEmpty ? null : caption,
      time: now,
      status: 'sending',
      attachments: attachments,
    );

    await _persist(placeholder);
    final text = caption.isEmpty ? label : caption;
    await _bumpChat(
      accountId: accountId,
      chatId: chatId,
      messageId: tempId,
      time: now,
      text: text,
      preview: preview,
      status: 'sending',
    );
    _track(
      tempId,
      accountId: accountId,
      chatId: chatId,
      text: text,
      preview: preview,
      time: now,
    );

    // #***! загрузку не ждём, экран закрывается сразу дальше UploadService
    unawaited(
      UploadService.instance.sendPhotos(
        accountId: accountId,
        chatId: chatId,
        tempId: tempId,
        jobs: jobs,
        caption: caption,
        placeholder: placeholder,
      ),
    );
  }

  // #***! видео по одному, у каждого своя длительность
  static Future<void> _sendVideo({
    required int accountId,
    required int chatId,
    required PreparedShareFile video,
    required String caption,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tempId = UploadService.instance.newTempId();

    final preview = _preview(
      kind: ChatPreviewKind.video,
      files: [video],
      label: caption.isEmpty ? 'Видео' : null,
    );
    final placeholder = CachedMessage(
      id: tempId,
      accountId: accountId,
      chatId: chatId,
      senderId: accountId,
      text: caption.isEmpty ? null : caption,
      time: now,
      status: 'sending',
      attachments: [
        VideoAttachment(
          localPath: video.file.path,
          previewData: video.thumbDataUri,
          width: video.width,
          height: video.height,
          duration: video.durationMs,
        ),
      ],
    );

    await _persist(placeholder);
    final text = caption.isEmpty ? 'Видео' : caption;
    await _bumpChat(
      accountId: accountId,
      chatId: chatId,
      messageId: tempId,
      time: now,
      text: text,
      preview: preview,
      status: 'sending',
    );
    _track(
      tempId,
      accountId: accountId,
      chatId: chatId,
      text: text,
      preview: preview,
      time: now,
    );

    unawaited(
      UploadService.instance.sendVideo(
        accountId: accountId,
        chatId: chatId,
        tempId: tempId,
        file: video.file,
        caption: caption,
        placeholder: placeholder,
      ),
    );
  }

  // #***! документ, в строке чата имя файла
  static Future<void> _sendDocument({
    required int accountId,
    required int chatId,
    required PreparedShareFile document,
    required String caption,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tempId = UploadService.instance.newTempId();
    final name = document.source.name;
    final size = document.source.size;

    final preview = ChatPreviewMedia(
      kind: ChatPreviewKind.file,
      label: caption.isEmpty ? 'Файл' : null,
      detail: caption.isEmpty ? name : null,
    ).encode();
    final placeholder = CachedMessage(
      id: tempId,
      accountId: accountId,
      chatId: chatId,
      senderId: accountId,
      text: caption.isEmpty ? null : caption,
      time: now,
      status: 'sending',
      attachments: [FileAttachment(name: name, size: size)],
    );

    await _persist(placeholder);
    final text = caption.isEmpty ? 'Файл: $name' : caption;
    await _bumpChat(
      accountId: accountId,
      chatId: chatId,
      messageId: tempId,
      time: now,
      text: text,
      preview: preview,
      status: 'sending',
    );
    _track(
      tempId,
      accountId: accountId,
      chatId: chatId,
      text: text,
      preview: preview,
      time: now,
    );

    unawaited(
      UploadService.instance.sendFile(
        accountId: accountId,
        chatId: chatId,
        tempId: tempId,
        source: document.file,
        filename: name,
        size: size,
        placeholder: placeholder,
      ),
    );
  }

  // #***! превью для списка чатов, до трёх миниатюр
  static String? _preview({
    required ChatPreviewKind kind,
    required List<PreparedShareFile> files,
    String? label,
  }) {
    final thumbs = <ChatPreviewThumb>[];
    for (final file in files) {
      final data = file.thumbDataUri;
      if (data == null) continue;
      thumbs.add(
        ChatPreviewThumb(
          source: data,
          video: file.kind == SharedFileKind.video,
        ),
      );
      if (thumbs.length >= 3) break;
    }
    if (thumbs.isEmpty && label == null) return null;
    return ChatPreviewMedia(kind: kind, thumbs: thumbs, label: label).encode();
  }

  // #***! плейсхолдер в базу чтоб пережил перезапуск
  static Future<void> _persist(
    CachedMessage message, {
    String? removeId,
  }) async {
    try {
      if (removeId != null && removeId != message.id) {
        await AppDatabase.deleteMessage(
          message.accountId,
          message.chatId,
          removeId,
        );
      }
      await AppDatabase.saveMessages([message.toDbRow()]);
    } catch (e) {
      logger.w('Поделиться: не сохранить плейсхолдер: $e');
    }
  }

  // #***! обновление строки чата, ошибку глотаем сообщение уже ушло
  static Future<void> _bumpChat({
    required int accountId,
    required int chatId,
    required String messageId,
    required int time,
    required String text,
    required String? preview,
    required String status,
  }) async {
    try {
      await chats.applyOutgoing(
        accountId,
        chatId,
        messageId: messageId,
        time: time,
        text: text,
        status: status,
        preview: preview,
      );
    } catch (e) {
      logger.w('Поделиться: не обновить строку чата $chatId: $e');
    }
  }
}

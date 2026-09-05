import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/main.dart';

import '../../../../core/utils/download_progress.dart';
import '../../../../core/utils/download_history.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/utils/media_cache.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/media/audio_file_track.dart';
import '../../../../core/media/audio_playback_controller.dart';
import '../../../../core/media/media_playback.dart';
import '../../../../core/crypto/chat_crypto_service.dart';
import '../../../../core/crypto/encrypted_photo_cache.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/attachment.dart';
import '../../custom_notification.dart';
import '../../decrypted_photo.dart';
import '../../photo_viewer.dart';
import '../../upload_progress_ring.dart';
import 'bubble_context.dart';

class FileBubble extends StatelessWidget {
  static const double _previewWidth = 240;
  static const double _previewHeight = 160;

  final BubbleContext ctx;
  final FileAttachment file;
  final bool fill;

  const FileBubble({
    super.key,
    required this.ctx,
    required this.file,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = ctx.isMe;
    final name = file.name ?? 'File';
    final size = file.size ?? 0;
    final sizeStr = formatBytes(size);
    final fileId = file.fileId;
    final cacheName = '${fileId}_$name';
    final audioFile = downloadKindForName(name) == DownloadKind.audio;

    final preview = file.preview;
    final previewUrl = preview?.baseUrl ?? preview?.previewData ?? '';
    final previewWidget = _preview(
      name: name,
      cacheName: cacheName,
      previewUrl: previewUrl,
      encrypted: fileId != null && _isEncryptedImage(name),
    );

    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?previewWidget,
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isMe ? ctx.systemTint : ctx.cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ctx.uploadProgress == null
                    ? Icon(
                        audioFile ? Symbols.audio_file : Symbols.description,
                        color: isMe
                            ? ctx.cs.onPrimaryContainer
                            : ctx.cs.primary,
                        size: 20,
                      )
                    : UploadProgressRing(
                        progress: ctx.uploadProgress!,
                        color: isMe
                            ? ctx.cs.onPrimaryContainer
                            : ctx.cs.primary,
                        size: 38,
                        strokeWidth: 2.4,
                        iconSize: 14,
                        padding: const EdgeInsets.all(4),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: ctx.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    ValueListenableBuilder<double?>(
                      valueListenable: MediaDownloadProgress.notifier(
                        cacheName,
                      ),
                      builder: (context, progress, _) => Text(
                        progress != null
                            ? '${(progress * 100).round()}% · $sizeStr'
                            : sizeStr,
                        style: TextStyle(
                          color: ctx.dim,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<double?>(
                valueListenable: MediaDownloadProgress.notifier(cacheName),
                builder: (context, progress, _) {
                  final iconColor = isMe
                      ? ctx.cs.onPrimaryContainer
                      : ctx.cs.primary;
                  Widget circle(Widget child, VoidCallback? onTap) {
                    return GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isMe
                              ? ctx.systemTint
                              : ctx.cs.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: child,
                      ),
                    );
                  }

                  if (progress != null) {
                    return circle(
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress > 0 ? progress : null,
                          color: iconColor,
                        ),
                      ),
                      null,
                    );
                  }

                  return ValueListenableBuilder<bool>(
                    valueListenable: MediaCache.presence(cacheName),
                    builder: (context, cached, _) {
                      if (!audioFile) {
                        return circle(
                          Icon(
                            cached ? Symbols.check : Symbols.download,
                            color: iconColor,
                            size: 18,
                          ),
                          () => _downloadFile(ctx.context, file, name),
                        );
                      }
                      Widget button(IconData icon) => circle(
                        Icon(icon, color: iconColor, size: 18, fill: 1),
                        () => _playAudioFile(ctx.context, file, name),
                      );
                      return ValueListenableBuilder<AudioFileTrack?>(
                        valueListenable: MediaPlayback.instance.audioFile,
                        builder: (context, track, _) {
                          if (!cached) return button(Symbols.download);
                          if (track?.cacheName != cacheName ||
                              !AudioPlaybackController.isInitialized) {
                            return button(Symbols.play_arrow);
                          }
                          return ValueListenableBuilder<bool>(
                            valueListenable:
                                AudioPlaybackController.instance.playing,
                            builder: (context, playing, _) => button(
                              playing ? Symbols.pause : Symbols.play_arrow,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
          if (audioFile)
            _AudioFilePlaybackControl(
              cacheName: cacheName,
              color: isMe ? ctx.cs.onPrimaryContainer : ctx.cs.primary,
              textColor: ctx.dim,
            ),
          ctx.meta(),
        ],
      ),
    );
    final body = fill ? inner : IntrinsicWidth(child: inner);
    if (!_isViewableImage(name)) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openInViewer(ctx.context, name, cacheName),
      child: body,
    );
  }

  static const Set<String> _coverExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
  };

  static bool _isViewableImage(String name) =>
      name.toLowerCase().endsWith('.png');

  static bool _hasCover(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return _coverExtensions.contains(name.substring(dot).toLowerCase());
  }

  bool _isEncryptedImage(String name) =>
      _isViewableImage(name) &&
      ChatCryptoService.instance.isEnabled(
        ctx.message.accountId,
        ctx.message.chatId,
      );

  Widget? _preview({
    required String name,
    required String cacheName,
    required String previewUrl,
    required bool encrypted,
  }) {
    if (encrypted) {
      return DecryptedPhoto(
        accountId: ctx.message.accountId,
        chatId: ctx.message.chatId,
        cacheName: cacheName,
        size: file.size ?? 0,
        urlLoader: _fileUrl,
        builder: (view) => _encryptedPreview(view, previewUrl),
      );
    }
    if (previewUrl.isEmpty || !_hasCover(name)) return null;
    return _networkPreview(previewUrl);
  }

  Widget _encryptedPreview(EncryptedPhotoView? view, String previewUrl) {
    switch (view?.status) {
      case EncryptedPhotoStatus.decrypted:
        return _framed(
          Image.file(
            view!.file!,
            width: _previewWidth,
            height: _previewHeight,
            fit: BoxFit.cover,
            cacheWidth: 480,
            errorBuilder: (_, _, _) => _placeholder(
              icon: Symbols.broken_image,
              label: 'Файл повреждён',
            ),
          ),
        );
      case EncryptedPhotoStatus.plain:
        return previewUrl.isEmpty
            ? const SizedBox.shrink()
            : _networkPreview(previewUrl);
      case EncryptedPhotoStatus.wrongKey:
        return _placeholder(icon: Symbols.lock, label: 'Неверный ключ');
      case EncryptedPhotoStatus.locked:
        return _placeholder(
          icon: Symbols.lock,
          label: 'Нажмите, чтобы открыть',
        );
      case null:
        return _placeholder();
    }
  }

  Widget _networkPreview(String url) => _framed(
    CachedNetworkImage(
      imageUrl: url,
      memCacheWidth: 480,
      fadeInDuration: const Duration(milliseconds: 120),
      imageBuilder: (context, image) => Image(
        image: image,
        width: _previewWidth,
        height: _previewHeight,
        fit: BoxFit.cover,
      ),
      placeholder: (_, _) =>
          const SizedBox(width: _previewWidth, height: _previewHeight),
      errorWidget: (_, _, _) => const SizedBox.shrink(),
    ),
  );

  Widget _placeholder({IconData? icon, String? label}) => _framed(
    Container(
      width: _previewWidth,
      height: _previewHeight,
      alignment: Alignment.center,
      color: ctx.isMe ? ctx.systemTint : ctx.cs.surfaceContainerHighest,
      child: icon == null
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: ctx.dim),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 26, color: ctx.dim),
                if (label != null) ...[
                  const SizedBox(height: 6),
                  Text(label, style: TextStyle(color: ctx.dim, fontSize: 12)),
                ],
              ],
            ),
    ),
  );

  Widget _framed(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
  );

  String? get _thumbnailUrl =>
      file.preview?.baseUrl ?? file.preview?.previewData ?? file.previewData;

  Future<String?> _fileUrl() {
    final fileId = file.fileId;
    if (fileId == null) return Future.value(null);
    return messagesModule.getFileUrl(
      messageId: ctx.message.id,
      chatId: ctx.message.chatId,
      fileId: fileId,
    );
  }

  Future<void> _openInViewer(
    BuildContext context,
    String name,
    String cacheName,
  ) async {
    final fileId = file.fileId;
    if (fileId == null) return;
    Haptics.tap();

    final wasCached = (await MediaCache.existing(cacheName)) != null;
    if (!wasCached) MediaDownloadProgress.set(cacheName, 0);
    File? local;
    try {
      final url = await _fileUrl();
      if (url != null && url.isNotEmpty) {
        local = await MediaCache.getOrDownload(
          cacheName,
          url,
          onProgress: (p) => MediaDownloadProgress.set(cacheName, p),
        );
      }
    } finally {
      if (!wasCached) MediaDownloadProgress.set(cacheName, null);
    }

    if (!context.mounted) return;
    if (local == null) {
      showCustomNotification(context, 'Не удалось загрузить файл');
      return;
    }

    final kind = downloadKindForName(name);
    try {
      await DownloadHistory.record(
        DownloadMetadata(
          cacheName: cacheName,
          name: name,
          kind: kind,
          sourceName: ctx.chatName ?? '',
          thumbnailUrl: _thumbnailUrl,
          expectedSize: file.size ?? 0,
          chatId: ctx.message.chatId,
          messageId: ctx.message.id,
          messageTime: ctx.message.time,
        ),
        local,
      );
    } catch (_) {}

    if (!context.mounted) return;
    final shown = await _decryptIfNeeded(context, local, cacheName);
    if (!context.mounted || shown == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          photos: [PhotoAttachment(localPath: shown.path)],
          chatId: ctx.message.chatId,
          message: ctx.message,
          isFile: true,
        ),
      ),
    );
  }

  Future<File?> _decryptIfNeeded(
    BuildContext context,
    File local,
    String cacheName,
  ) async {
    final accountId = ctx.message.accountId;
    final chatId = ctx.message.chatId;
    if (!ChatCryptoService.instance.isEnabled(accountId, chatId)) return local;

    final view = await EncryptedPhotoCache.instance.resolve(
      accountId: accountId,
      chatId: chatId,
      cacheName: cacheName,
      urlLoader: _fileUrl,
    );
    if (!context.mounted) return null;

    switch (view.status) {
      case EncryptedPhotoStatus.decrypted:
        return view.file;
      case EncryptedPhotoStatus.plain:
        return local;
      case EncryptedPhotoStatus.wrongKey:
        showCustomNotification(context, 'Неверный ключ');
        return null;
      case EncryptedPhotoStatus.locked:
        showCustomNotification(context, 'Не удалось расшифровать фото');
        return null;
    }
  }

  Future<void> _downloadFile(
    BuildContext context,
    FileAttachment file,
    String name,
  ) async {
    final fileId = file.fileId;
    if (fileId == null) {
      showCustomNotification(context, 'Не удалось определить файл');
      return;
    }
    Haptics.tap();

    final cacheName = '${fileId}_$name';
    final cached = (await MediaCache.existing(cacheName)) != null;
    final kind = downloadKindForName(name);

    if (!cached) MediaDownloadProgress.set(cacheName, 0);
    final result = await openCachedFile(
      cacheName,
      () => messagesModule.getFileUrl(
        messageId: ctx.message.id,
        chatId: ctx.message.chatId,
        fileId: fileId,
      ),
      onProgress: (p) => MediaDownloadProgress.set(cacheName, p),
      onReady: () {
        if (!cached) MediaDownloadProgress.set(cacheName, null);
      },
      download: DownloadMetadata(
        cacheName: cacheName,
        name: name,
        kind: kind,
        sourceName: ctx.chatName ?? '',
        thumbnailUrl: _thumbnailUrl,
        expectedSize: file.size ?? 0,
        chatId: ctx.message.chatId,
        messageId: ctx.message.id,
        messageTime: ctx.message.time,
      ),
    );
    if (!context.mounted) return;
    if (!result.ok) {
      showCustomNotification(
        context,
        'Ошибка загрузки: ${result.error ?? 'не удалось открыть'}',
      );
    }
  }

  Future<void> _playAudioFile(
    BuildContext context,
    FileAttachment file,
    String name,
  ) async {
    final fileId = file.fileId;
    if (fileId == null) {
      showCustomNotification(context, 'Не удалось определить файл');
      return;
    }
    Haptics.tap();
    final cacheName = '${fileId}_$name';
    final playback = MediaPlayback.instance;
    if (playback.audioFile.value?.cacheName == cacheName &&
        AudioPlaybackController.isInitialized) {
      await AudioPlaybackController.instance.toggle();
      return;
    }
    final cached = (await MediaCache.existing(cacheName)) != null;
    if (!cached) MediaDownloadProgress.set(cacheName, 0);
    final result = await ensureCachedFile(
      cacheName,
      _fileUrl,
      onProgress: (value) => MediaDownloadProgress.set(cacheName, value),
      onReady: () {
        if (!cached) MediaDownloadProgress.set(cacheName, null);
      },
      download: DownloadMetadata(
        cacheName: cacheName,
        name: name,
        kind: DownloadKind.audio,
        sourceName: ctx.chatName ?? '',
        thumbnailUrl: _thumbnailUrl,
        expectedSize: file.size ?? 0,
        chatId: ctx.message.chatId,
        messageId: ctx.message.id,
        messageTime: ctx.message.time,
      ),
    );
    if (!context.mounted) return;
    if (!result.ok || result.path == null) {
      showCustomNotification(
        context,
        'Ошибка загрузки: ${result.error ?? 'не удалось загрузить'}',
      );
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    try {
      await playback.activateAudioFile(
        AudioFileTrack(
          cacheName: cacheName,
          path: result.path!,
          name: name,
          sourceName: ctx.chatName ?? '',
          chatId: ctx.message.chatId,
          messageId: ctx.message.id,
          messageTime: ctx.message.time,
          thumbnailUrl: _thumbnailUrl,
        ),
        notificationChannelName: l10n.audioPlaybackChannel,
      );
    } catch (_) {
      if (context.mounted) {
        showCustomNotification(context, l10n.audioPlaybackFailed);
      }
    }
  }
}

class _AudioFilePlaybackControl extends StatelessWidget {
  const _AudioFilePlaybackControl({
    required this.cacheName,
    required this.color,
    required this.textColor,
  });

  final String cacheName;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AudioFileTrack?>(
      valueListenable: MediaPlayback.instance.audioFile,
      builder: (context, track, _) =>
          track?.cacheName != cacheName || !AudioPlaybackController.isInitialized
          ? const SizedBox.shrink()
          : _AudioFileScrubber(color: color, textColor: textColor),
    );
  }
}

class _AudioFileScrubber extends StatefulWidget {
  const _AudioFileScrubber({required this.color, required this.textColor});

  final Color color;
  final Color textColor;

  @override
  State<_AudioFileScrubber> createState() => _AudioFileScrubberState();
}

class _AudioFileScrubberState extends State<_AudioFileScrubber> {
  double? _dragMilliseconds;

  @override
  Widget build(BuildContext context) {
    final audio = AudioPlaybackController.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([audio.position, audio.duration]),
      builder: (context, _) {
        final total = audio.duration.value.inMilliseconds;
        final elapsed = _dragMilliseconds != null
            ? _dragMilliseconds!.round()
            : audio.position.value.inMilliseconds.clamp(0, total > 0 ? total : 0);
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                formatSecondsMmSs(elapsed ~/ 1000),
                style: TextStyle(color: widget.textColor, fontSize: 10),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: widget.color,
                    inactiveTrackColor: widget.color.withValues(alpha: 0.2),
                    thumbColor: widget.color,
                    overlayColor: widget.color.withValues(alpha: 0.12),
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: total > 0 ? total.toDouble() : 1,
                    value: total > 0 ? elapsed.toDouble() : 0,
                    onChanged: total > 0
                        ? (next) => setState(() => _dragMilliseconds = next)
                        : null,
                    onChangeEnd: total > 0
                        ? (next) {
                            setState(() => _dragMilliseconds = null);
                            audio.seek(Duration(milliseconds: next.round()));
                          }
                        : null,
                  ),
                ),
              ),
              Text(
                formatSecondsMmSs(audio.duration.value.inSeconds),
                style: TextStyle(color: widget.textColor, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/main.dart';

import '../../../../core/utils/download_progress.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/utils/media_cache.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/crypto/chat_crypto_service.dart';
import '../../../../core/crypto/encrypted_photo.dart';
import '../../../../models/attachment.dart';
import '../../custom_notification.dart';
import '../../photo_viewer.dart';
import 'bubble_context.dart';

class FileBubble extends StatelessWidget {
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

    final preview = file.preview;
    final previewUrl = preview?.baseUrl ?? preview?.previewData ?? '';

    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (previewUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: previewUrl,
                width: 240,
                height: 160,
                fit: BoxFit.cover,
                memCacheWidth: 480,
                fadeInDuration: const Duration(milliseconds: 120),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
                child: Icon(
                  Symbols.description,
                  color: isMe ? ctx.cs.onPrimaryContainer : ctx.cs.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
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
                    builder: (context, cached, _) => circle(
                      Icon(
                        cached ? Symbols.check : Symbols.download,
                        color: iconColor,
                        size: 18,
                      ),
                      () => _downloadFile(ctx.context, file, name),
                    ),
                  );
                },
              ),
            ],
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

  static bool _isViewableImage(String name) =>
      name.toLowerCase().endsWith('.png');

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
      final url = await messagesModule.getFileUrl(
        messageId: ctx.message.id,
        chatId: ctx.message.chatId,
        fileId: fileId,
      );
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

    final shown = await _decryptIfNeeded(local, cacheName);
    if (!context.mounted) return;
    if (shown == null) {
      showCustomNotification(context, 'Неверный ключ');
      return;
    }

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

  Future<File?> _decryptIfNeeded(File local, String cacheName) async {
    final accountId = ctx.message.accountId;
    final chatId = ctx.message.chatId;
    if (!ChatCryptoService.instance.isEnabled(accountId, chatId)) return local;
    if (!await ChatCryptoService.instance.looksEncryptedImage(local.path)) {
      return local;
    }
    final result = await openEncryptedPhoto(
      accountId: accountId,
      chatId: chatId,
      encrypted: local,
      cacheName: cacheName,
    );
    return result.file;
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
    );
    if (!context.mounted) return;
    if (!result.ok) {
      showCustomNotification(
        context,
        'Ошибка загрузки: ${result.error ?? 'не удалось открыть'}',
      );
    }
  }
}

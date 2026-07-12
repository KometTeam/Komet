import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/main.dart';

import '../../../../core/utils/download_progress.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../models/attachment.dart';
import '../../custom_notification.dart';
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
                  final downloading = progress != null;
                  return GestureDetector(
                    onTap: downloading
                        ? null
                        : () => _downloadFile(ctx.context, file, name),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isMe
                            ? ctx.systemTint
                            : ctx.cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: downloading
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: progress > 0 ? progress : null,
                                color: isMe
                                    ? ctx.cs.onPrimaryContainer
                                    : ctx.cs.primary,
                              ),
                            )
                          : Icon(
                              Symbols.download,
                              color: isMe
                                  ? ctx.cs.onPrimaryContainer
                                  : ctx.cs.primary,
                              size: 18,
                            ),
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
    return fill ? inner : IntrinsicWidth(child: inner);
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

    MediaDownloadProgress.set(cacheName, 0);
    final result = await openCachedFile(
      cacheName,
      () => messagesModule.getFileUrl(
        messageId: ctx.message.id,
        chatId: ctx.message.chatId,
        fileId: fileId,
      ),
      onProgress: (p) => MediaDownloadProgress.set(cacheName, p),
    );
    MediaDownloadProgress.set(cacheName, null);
    if (!context.mounted) return;
    if (!result.ok) {
      showCustomNotification(
        context,
        'Ошибка загрузки: ${result.error ?? 'не удалось открыть'}',
      );
    }
  }
}

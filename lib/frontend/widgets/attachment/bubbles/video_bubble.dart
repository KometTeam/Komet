import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/main.dart';

import '../../../../core/media/preview_image.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../models/attachment.dart';
import '../../custom_notification.dart';
import '../../upload_progress_ring.dart';
import '../../photo_viewer.dart';
import '../../text_with_meta.dart';
import 'bubble_context.dart';
import 'video_note_bubble.dart';

class VideoBubble extends StatelessWidget {
  final BubbleContext ctx;
  final VideoAttachment video;

  const VideoBubble({super.key, required this.ctx, required this.video});

  static double layoutWidth(VideoAttachment video, {bool hasCaption = false}) {
    return (video.width?.toDouble() ?? 200.0).clamp(
      hasCaption
          ? BubbleContext.captionedMediaMinWidth
          : BubbleContext.photoMinSize,
      BubbleContext.photoMaxSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = ctx.message;
    if (video.isNote) {
      return VideoNoteBubble(
        attachment: video,
        messageId: message.id,
        chatId: message.chatId,
        sourceMessageId: ctx.sourceMessageId,
        sourceChatId: ctx.sourceChatId,
        senderId: message.senderId,
        isMe: ctx.isMe,
        time: message.time,
        cs: ctx.cs,
        textColor: ctx.text,
        meta: ctx.meta(),
        uploadProgress: ctx.uploadProgress,
      );
    }
    final hasMessageCaption = ctx.contentText?.isNotEmpty ?? false;
    final resolvedCaption = hasMessageCaption ? ctx.caption() : null;
    final hasCaption = resolvedCaption != null;
    final thumb = video.thumbnail;
    final durationMs = video.duration;
    final previewUrl = (thumb != null && thumb.isNotEmpty)
        ? thumb
        : (video.baseUrl != null && video.baseUrl!.isNotEmpty)
        ? video.baseUrl!
        : (video.previewData ?? '');

    final h = video.height;
    final width = layoutWidth(video, hasCaption: hasCaption);
    final height = (h?.toDouble() ?? 150.0).clamp(
      BubbleContext.photoMinSize,
      BubbleContext.photoMaxSize,
    );
    final dpr = MediaQuery.of(ctx.context).devicePixelRatio;

    Widget placeholder() => Container(
      width: width,
      height: height,
      color: ctx.cs.surfaceContainerHighest,
      child: Icon(Symbols.videocam, size: 48, color: ctx.cs.onSurfaceVariant),
    );

    final localThumb = dataUriImage(video, video.previewData);
    final uploading = ctx.uploadProgress;

    Widget previewImage() {
      if (previewUrl.isNotEmpty && !previewUrl.startsWith('data:')) {
        return CachedNetworkImage(
          imageUrl: previewUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          memCacheWidth: (width * dpr).round(),
          fadeInDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          errorWidget: (_, _, _) => localThumb == null
              ? placeholder()
              : Image(
                  image: localThumb,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                ),
        );
      }
      if (localThumb != null) {
        return Image(
          image: localThumb,
          width: width,
          height: height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => placeholder(),
        );
      }
      return placeholder();
    }

    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(BubbleContext.photoBorderRadius),
      child: Stack(
        children: [
          previewImage(),
          if (uploading != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: UploadProgressRing(
                    progress: uploading,
                    color: Colors.white,
                    trackColor: Colors.white24,
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Symbols.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          if (durationMs != null && durationMs > 0)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  formatSecondsMmSs((durationMs / 1000).round()),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          if (uploading == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _playVideo(ctx.context, video),
              ),
            ),
        ],
      ),
    );

    if (!hasCaption) {
      return Stack(
        children: [
          preview,
          Positioned(
            bottom: BubbleContext.compactTimePadding,
            right: BubbleContext.compactTimePadding,
            child: ctx.compactTime(),
          ),
        ],
      );
    }

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          preview,
          Padding(
            padding: const EdgeInsets.only(
              left: BubbleContext.captionPaddingHorizontal,
              right: BubbleContext.captionPaddingRight,
              top: BubbleContext.captionPaddingTop,
              bottom: 6,
            ),
            child: TextWithMeta(
              text: resolvedCaption,
              meta: ctx.meta(),
              fillWidth: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playVideo(BuildContext context, VideoAttachment video) =>
      openVideoPlayer(ctx, video);
}

// #***! общий вход в плеер, зовут и одиночное видео и плитка альбома
Future<void> openVideoPlayer(BubbleContext ctx, VideoAttachment video) async {
  final context = ctx.context;
  final videoId = video.videoId;
  final token = video.videoToken;
  if (videoId == null || token == null) {
    showCustomNotification(context, 'Не удалось открыть видео');
    return;
  }
  Haptics.tap();

  final sources = await messagesModule.getVideoSources(
    messageId: ctx.sourceMessageId,
    chatId: ctx.sourceChatId,
    token: token,
    videoId: videoId,
  );
  if (!context.mounted) return;
  if (sources.isEmpty) {
    showCustomNotification(context, 'Не удалось получить видео');
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoViewerScreen.video(
        attachment: video,
        initialVideoSources: sources,
        chatId: ctx.message.chatId,
        message: ctx.message,
        actions: ctx.photoActions,
        sourceName: ctx.chatName,
      ),
    ),
  );
}

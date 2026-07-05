import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/main.dart';

import '../../../../core/utils/format.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../models/attachment.dart';
import '../../custom_notification.dart';
import '../../video_player_screen.dart';
import 'bubble_context.dart';
import 'video_note_bubble.dart';

class VideoBubble extends StatelessWidget {
  final BubbleContext ctx;
  final VideoAttachment video;

  const VideoBubble({super.key, required this.ctx, required this.video});

  @override
  Widget build(BuildContext context) {
    final message = ctx.message;
    if (video.isNote) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          VideoNoteBubble(
            attachment: video,
            messageId: message.id,
            chatId: message.chatId,
            cs: ctx.cs,
          ),
          const SizedBox(height: 6),
          ctx.meta(),
        ],
      );
    }
    final hasCaption = message.text != null && message.text!.isNotEmpty;
    final thumb = video.thumbnail;
    final durationMs = video.duration;
    final previewUrl = (thumb != null && thumb.isNotEmpty)
        ? thumb
        : (video.baseUrl != null && video.baseUrl!.isNotEmpty)
        ? video.baseUrl!
        : (video.previewData ?? '');

    final w = video.width;
    final h = video.height;
    final width = (w?.toDouble() ?? 200.0).clamp(
      BubbleContext.photoMinSize,
      BubbleContext.photoMaxSize,
    );
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

    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(BubbleContext.photoBorderRadius),
      child: Stack(
        children: [
          previewUrl.isEmpty
              ? placeholder()
              : CachedNetworkImage(
                  imageUrl: previewUrl,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  memCacheWidth: (width * dpr).round(),
                  fadeInDuration: Duration.zero,
                  placeholderFadeInDuration: Duration.zero,
                  errorWidget: (_, _, _) => placeholder(),
                ),
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
              bottom: 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: ctx.caption()),
                ctx.meta(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playVideo(BuildContext context, VideoAttachment video) async {
    final videoId = video.videoId;
    final token = video.videoToken;
    if (videoId == null || token == null) {
      showCustomNotification(context, 'Не удалось открыть видео');
      return;
    }
    Haptics.tap();

    final sources = await messagesModule.getVideoSources(
      messageId: ctx.message.id,
      chatId: ctx.message.chatId,
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
        builder: (_) => VideoPlayerScreen(sources: sources),
      ),
    );
  }
}

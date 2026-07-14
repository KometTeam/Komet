import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../models/attachment.dart';
import '../../photo_viewer.dart';
import 'bubble_context.dart';

class PhotoBubble extends StatelessWidget {
  static const Radius _bigRadius = Radius.circular(
    BubbleContext.bubbleBorderRadius,
  );
  static const Radius _smallRadius = Radius.circular(4);
  static const Radius _photoRadius = Radius.circular(
    BubbleContext.photoBorderRadius,
  );

  final BubbleContext ctx;
  final List<PhotoAttachment> photos;

  const PhotoBubble({super.key, required this.ctx, required this.photos});

  @override
  Widget build(BuildContext context) {
    final message = ctx.message;
    final hasCaption = message.text != null && message.text!.isNotEmpty;
    final count = photos.length;

    Widget photosWidget;
    if (count == 1) {
      photosWidget = _buildSinglePhoto(ctx, photos[0]);
    } else if (count == 2) {
      photosWidget = _buildTwoPhotos(ctx, photos[0], photos[1]);
    } else {
      photosWidget = _buildPhotoGrid(ctx, photos);
    }

    if (!hasCaption) {
      return Stack(
        children: [
          photosWidget,
          Positioned(
            bottom: BubbleContext.compactTimePadding,
            right: BubbleContext.compactTimePadding,
            child: ctx.compactTime(),
          ),
        ],
      );
    }

    if (count == 1) {
      final photo = photos[0];
      final pw = photo.width?.toDouble() ?? 200;
      final photoWidth = pw.clamp(
        BubbleContext.photoMinSize,
        BubbleContext.photoMaxSize,
      );

      return SizedBox(
        width: photoWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            photosWidget,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        photosWidget,
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
    );
  }

  Widget _buildSinglePhoto(BubbleContext ctx, PhotoAttachment photo) {
    final width = photo.width?.toDouble() ?? 200;
    final height = photo.height?.toDouble() ?? 200;

    final constrainedWidth = width.clamp(
      BubbleContext.photoMinSize,
      BubbleContext.photoMaxSize,
    );
    final constrainedHeight = height.clamp(
      BubbleContext.photoMinSize,
      BubbleContext.photoMaxSize,
    );
    final dpr = MediaQuery.of(ctx.context).devicePixelRatio;

    final matchTop = ctx.hasPhotoWithCaption;
    final matchBottom = !ctx.hasPhotoWithCaption;

    final topR = matchTop ? _bigRadius : _photoRadius;
    final bottomL = matchBottom
        ? (ctx.isMe ? _bigRadius : _smallRadius)
        : _smallRadius;
    final bottomR = matchBottom
        ? (ctx.isMe ? _smallRadius : _bigRadius)
        : _smallRadius;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: topR,
        topRight: topR,
        bottomLeft: bottomL,
        bottomRight: bottomR,
      ),
      child: Stack(
        children: [
          _buildPhotoImage(
            ctx,
            photo,
            constrainedWidth,
            constrainedHeight,
            memWidth: (constrainedWidth * dpr).round(),
            memHeight: (constrainedHeight * dpr).round(),
          ),
          if (ctx.uploadProgress != null)
            _buildUploadOverlay(ctx.uploadProgress!, 0),
          if (ctx.uploadProgress == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openPhotoViewer(ctx.context, 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoImage(
    BubbleContext ctx,
    PhotoAttachment photo,
    double width,
    double height, {
    required int memWidth,
    required int memHeight,
  }) {
    final localPath = photo.localPath;
    if (localPath != null) {
      return Image.file(
        File(localPath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: memWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            _buildPhotoPlaceholder(ctx.cs, width, height),
      );
    }
    final imageUrl = photo.baseUrl ?? '';
    if (imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: memWidth,
        memCacheHeight: memHeight,
        fadeInDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        errorWidget: (_, _, _) => _buildPhotoPlaceholder(ctx.cs, width, height),
      );
    }
    return _buildPhotoPlaceholder(ctx.cs, width, height);
  }

  Widget _buildUploadOverlay(
    ValueListenable<List<double>> progress,
    int index,
  ) {
    return Positioned.fill(
      child: ValueListenableBuilder<List<double>>(
        valueListenable: progress,
        builder: (context, values, _) {
          final value = index < values.length ? values[index] : 1.0;
          final indeterminate = value <= 0 || value >= 1.0;
          return Container(
            color: Colors.black.withValues(alpha: 0.4),
            alignment: Alignment.center,
            child: SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: indeterminate ? null : value,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  BorderRadius _multiPhotoCornerRadius({
    required bool matchTop,
    required bool matchBottom,
    required bool isMe,
  }) {
    final topR = matchTop ? _bigRadius : _photoRadius;
    final bottomL = matchBottom ? _smallRadius : _photoRadius;
    final bottomR = matchBottom
        ? (isMe ? _smallRadius : _bigRadius)
        : _photoRadius;
    return BorderRadius.only(
      topLeft: topR,
      topRight: topR,
      bottomLeft: bottomL,
      bottomRight: bottomR,
    );
  }

  Widget _buildTwoPhotos(
    BubbleContext ctx,
    PhotoAttachment p1,
    PhotoAttachment p2,
  ) {
    final matchTop =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleTop;
    final matchBottom =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleBottom;

    return ClipRRect(
      borderRadius: _multiPhotoCornerRadius(
        matchTop: matchTop,
        matchBottom: matchBottom,
        isMe: ctx.isMe,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: _buildPhotoTile(ctx, p1, 0)),
          const SizedBox(width: 2),
          Expanded(child: _buildPhotoTile(ctx, p2, 1)),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(BubbleContext ctx, List<PhotoAttachment> photos) {
    final displayCount = photos.length > 4 ? 4 : photos.length;
    final remaining = photos.length - 4;

    final matchTop =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleTop;
    final matchBottom =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleBottom;

    final rows = <Widget>[];
    for (var i = 0; i < displayCount; i += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 2));
      rows.add(
        Row(
          children: [
            Expanded(child: _buildGridTile(ctx, photos, i, remaining)),
            const SizedBox(width: 2),
            Expanded(
              child: i + 1 < displayCount
                  ? _buildGridTile(ctx, photos, i + 1, remaining)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: _multiPhotoCornerRadius(
        matchTop: matchTop,
        matchBottom: matchBottom,
        isMe: ctx.isMe,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _buildGridTile(
    BubbleContext ctx,
    List<PhotoAttachment> photos,
    int index,
    int remaining,
  ) {
    if (index == 3 && remaining > 0) {
      return _buildPhotoTileWithOverlay(
        ctx,
        photos[index],
        '+$remaining',
        index,
      );
    }
    return _buildPhotoTile(ctx, photos[index], index);
  }

  Widget _buildPhotoTile(BubbleContext ctx, PhotoAttachment photo, int index) {
    final cachePx =
        (BubbleContext.photoMaxSize /
                2 *
                MediaQuery.of(ctx.context).devicePixelRatio)
            .round();
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          _buildPhotoImage(
            ctx,
            photo,
            double.infinity,
            double.infinity,
            memWidth: cachePx,
            memHeight: cachePx,
          ),
          if (ctx.uploadProgress != null)
            _buildUploadOverlay(ctx.uploadProgress!, index),
          if (ctx.uploadProgress == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openPhotoViewer(ctx.context, index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoTileWithOverlay(
    BubbleContext ctx,
    PhotoAttachment photo,
    String overlay,
    int index,
  ) {
    final cachePx =
        (BubbleContext.photoMaxSize /
                2 *
                MediaQuery.of(ctx.context).devicePixelRatio)
            .round();
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          _buildPhotoImage(
            ctx,
            photo,
            double.infinity,
            double.infinity,
            memWidth: cachePx,
            memHeight: cachePx,
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: Center(
                child: Text(
                  overlay,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          if (ctx.uploadProgress != null)
            _buildUploadOverlay(ctx.uploadProgress!, index),
          if (ctx.uploadProgress == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openPhotoViewer(ctx.context, index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder(
    ColorScheme cs,
    double w,
    double h, {
    VoidCallback? onRetry,
  }) {
    return Container(
      width: w,
      height: h,
      color: cs.surfaceContainerHighest,
      child: onRetry != null
          ? Center(
              child: IconButton(
                icon: Icon(Symbols.refresh, color: cs.onSurfaceVariant),
                onPressed: onRetry,
                tooltip: 'Retry',
              ),
            )
          : Center(
              child: Icon(Symbols.image, size: 48, color: cs.onSurfaceVariant),
            ),
    );
  }

  void _openPhotoViewer(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(
          photos: photos,
          initialIndex: index,
          chatId: ctx.chatId,
          message: ctx.message,
          actions: ctx.photoActions,
        ),
      ),
    );
  }
}

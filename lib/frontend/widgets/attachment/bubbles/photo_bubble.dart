import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/media/preview_image.dart';
import '../../../../models/attachment.dart';
import '../../photo_viewer.dart';
import '../photo_hero.dart';
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
  final bool hasContentAbove;

  const PhotoBubble({
    super.key,
    required this.ctx,
    required this.photos,
    this.hasContentAbove = false,
  });

  static double layoutWidth(List<PhotoAttachment> photos) {
    if (photos.length != 1) return BubbleContext.photoMaxSize;
    return _displaySize(photos.single).width;
  }

  static Size _displaySize(PhotoAttachment photo) {
    return BubbleContext.fitMediaSize(
      photo.width?.toDouble() ?? 0,
      photo.height?.toDouble() ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMessageCaption = ctx.contentText?.isNotEmpty ?? false;
    final resolvedCaption = hasMessageCaption ? ctx.caption() : null;
    final hasCaption = resolvedCaption != null;
    final count = photos.length;

    Widget photosWidget;
    if (count == 1) {
      photosWidget = _buildSinglePhoto(
        ctx,
        photos[0],
        hasCaption: hasCaption,
        hasContentAbove: hasContentAbove,
      );
    } else if (count == 2) {
      photosWidget = _buildTwoPhotos(ctx, photos[0], photos[1]);
    } else if (count == 3) {
      photosWidget = _buildThreePhotos(ctx, photos);
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
      return SizedBox(
        width: layoutWidth(photos),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            photosWidget,
            Padding(
              padding: const EdgeInsets.only(
                left: BubbleContext.captionPaddingHorizontal,
                right: BubbleContext.captionPaddingRight,
                top: BubbleContext.captionPaddingTop,
                bottom: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: resolvedCaption),
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
            top: BubbleContext.captionPaddingTop,
            bottom: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: resolvedCaption),
              ctx.meta(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePhoto(
    BubbleContext ctx,
    PhotoAttachment photo, {
    required bool hasCaption,
    required bool hasContentAbove,
  }) {
    final size = _displaySize(photo);
    final constrainedWidth = size.width;
    final constrainedHeight = size.height;
    final dpr = MediaQuery.of(ctx.context).devicePixelRatio;

    final matchTop = hasCaption && !hasContentAbove;
    final matchBottom = !hasCaption;

    final topR = matchTop ? _bigRadius : _photoRadius;
    final bottomL = matchBottom
        ? (ctx.isMe ? _bigRadius : _smallRadius)
        : _smallRadius;
    final bottomR = matchBottom
        ? (ctx.isMe ? _smallRadius : _bigRadius)
        : _smallRadius;

    final radius = BorderRadius.only(
      topLeft: topR,
      topRight: topR,
      bottomLeft: bottomL,
      bottomRight: bottomR,
    );
    final memWidth = (constrainedWidth * dpr).round();

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          _buildPhotoImage(
            ctx,
            photo,
            constrainedWidth,
            constrainedHeight,
            memWidth: memWidth,
          ),
          if (ctx.uploadProgress != null)
            _buildUploadOverlay(ctx.uploadProgress!, 0),
          if (ctx.uploadProgress == null)
            Positioned.fill(
              child: Builder(
                builder: (tileContext) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openPhotoViewer(
                    ctx.context,
                    0,
                    tileContext: tileContext,
                    radius: radius,
                    memWidth: memWidth,
                  ),
                ),
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
  }) {
    final preview = dataUriImage(photo, photo.previewData);
    Widget box(Widget child) {
      if (width.isFinite && height.isFinite) return child;
      return SizedBox.expand(child: child);
    }

    final placeholder = preview == null
        ? _buildPhotoPlaceholder(
            ctx.cs,
            width.isFinite ? width : double.infinity,
            height.isFinite ? height : double.infinity,
          )
        : box(
            Image(
              image: preview,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
    final localPath = photo.localPath;
    if (localPath != null) {
      return box(
        Image.file(
          File(localPath),
          width: width.isFinite ? width : null,
          height: height.isFinite ? height : null,
          fit: BoxFit.cover,
          cacheWidth: memWidth,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => placeholder,
        ),
      );
    }
    final imageUrl = photo.baseUrl ?? '';
    if (imageUrl.isNotEmpty) {
      return box(
        CachedNetworkImage(
          imageUrl: imageUrl,
          width: width.isFinite ? width : null,
          height: height.isFinite ? height : null,
          fit: BoxFit.cover,
          memCacheWidth: memWidth,
          fadeInDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) => placeholder,
        ),
      );
    }
    return placeholder;
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

    return SizedBox(
      width: BubbleContext.photoMaxSize,
      child: ClipRRect(
        borderRadius: _multiPhotoCornerRadius(
          matchTop: matchTop,
          matchBottom: matchBottom,
          isMe: ctx.isMe,
        ),
        child: AspectRatio(
          aspectRatio: 2,
          child: Row(
            children: [
              Expanded(child: _buildFillTile(ctx, p1, 0)),
              const SizedBox(width: 2),
              Expanded(child: _buildFillTile(ctx, p2, 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreePhotos(BubbleContext ctx, List<PhotoAttachment> photos) {
    final matchTop =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleTop;
    final matchBottom =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleBottom;

    return SizedBox(
      width: BubbleContext.photoMaxSize,
      child: ClipRRect(
      borderRadius: _multiPhotoCornerRadius(
        matchTop: matchTop,
        matchBottom: matchBottom,
        isMe: ctx.isMe,
      ),
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: Row(
          children: [
            Expanded(flex: 2, child: _buildFillTile(ctx, photos[0], 0)),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildFillTile(ctx, photos[1], 1)),
                  const SizedBox(height: 2),
                  Expanded(child: _buildFillTile(ctx, photos[2], 2)),
                ],
              ),
            ),
          ],
        ),
      ),
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

    return SizedBox(
      width: BubbleContext.photoMaxSize,
      child: ClipRRect(
        borderRadius: _multiPhotoCornerRadius(
          matchTop: matchTop,
          matchBottom: matchBottom,
          isMe: ctx.isMe,
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGridTile(ctx, photos, 0, remaining),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: displayCount > 1
                          ? _buildGridTile(ctx, photos, 1, remaining)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              if (displayCount > 2) ...[
                const SizedBox(height: 2),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildGridTile(ctx, photos, 2, remaining),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: displayCount > 3
                            ? _buildGridTile(ctx, photos, 3, remaining)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
    return _buildFillTile(ctx, photos[index], index);
  }

  Widget _buildPhotoTile(BubbleContext ctx, PhotoAttachment photo, int index) =>
      AspectRatio(aspectRatio: 1, child: _buildFillTile(ctx, photo, index));

  Widget _buildFillTile(BubbleContext ctx, PhotoAttachment photo, int index) {
    final cachePx =
        (BubbleContext.photoMaxSize /
                2 *
                MediaQuery.of(ctx.context).devicePixelRatio)
            .round();
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPhotoImage(
          ctx,
          photo,
          double.infinity,
          double.infinity,
          memWidth: cachePx,
        ),
        if (ctx.uploadProgress != null)
          _buildUploadOverlay(ctx.uploadProgress!, index),
        if (ctx.uploadProgress == null)
          _buildTileTapTarget(ctx, index, cachePx),
      ],
    );
  }

  Widget _buildTileTapTarget(BubbleContext ctx, int index, int cachePx) {
    return Positioned.fill(
      child: Builder(
        builder: (tileContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openPhotoViewer(
            ctx.context,
            index,
            tileContext: tileContext,
            radius: BorderRadius.zero,
            memWidth: cachePx,
          ),
        ),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPhotoImage(
          ctx,
          photo,
          double.infinity,
          double.infinity,
          memWidth: cachePx,
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
            _buildTileTapTarget(ctx, index, cachePx),
        ],
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

  static ImageProvider? _photoProvider(
    PhotoAttachment photo, {
    required int memWidth,
  }) {
    final localPath = photo.localPath;
    if (localPath != null) {
      return ResizeImage.resizeIfNeeded(
        memWidth,
        null,
        FileImage(File(localPath)),
      );
    }
    final url = photo.baseUrl ?? '';
    if (url.isEmpty) return null;
    return ResizeImage.resizeIfNeeded(
      memWidth,
      null,
      CachedNetworkImageProvider(url),
    );
  }

  static Size? _photoSize(PhotoAttachment photo) {
    final width = photo.width ?? 0;
    final height = photo.height ?? 0;
    if (width <= 0 || height <= 0) return null;
    return Size(width.toDouble(), height.toDouble());
  }

  void _openPhotoViewer(
    BuildContext context,
    int index, {
    required BuildContext tileContext,
    required BorderRadius radius,
    required int memWidth,
  }) {
    final photo = photos[index];
    final hero = PhotoHeroController(
      origin: () => photoHeroRectOf(tileContext),
      image: _photoProvider(photo, memWidth: memWidth),
      size: _photoSize(photo),
      radius: radius,
    );
    Navigator.of(context).push(
      PhotoHeroRoute<void>(
        hero: hero,
        builder: (_) => PhotoViewerScreen(
          photos: photos,
          initialIndex: index,
          chatId: ctx.chatId,
          message: ctx.message,
          actions: ctx.photoActions,
          hero: hero,
          sourceName: ctx.chatName,
        ),
      ),
    );
  }
}

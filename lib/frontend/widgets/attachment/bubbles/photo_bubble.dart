import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/config/app_bubble_behavior.dart';
import '../../../../core/config/app_bubble_shape.dart';
import '../../../../core/media/preview_image.dart';
import '../../../../core/utils/bubble_radius.dart';
import '../../../../core/utils/telegram_album_layout.dart';
import '../../../../models/attachment.dart';
import '../../photo_viewer.dart';
import '../photo_hero.dart';
import 'bubble_context.dart';

class PhotoBubble extends StatelessWidget {
  final BubbleContext ctx;
  final List<PhotoAttachment> photos;
  final bool hasContentAbove;

  const PhotoBubble({
    super.key,
    required this.ctx,
    required this.photos,
    this.hasContentAbove = false,
  });

  static AlbumLayout layoutOf(
    List<PhotoAttachment> photos, {
    double maxWidth = BubbleContext.photoMaxSize,
  }) {
    return layoutTelegramAlbum(
      [
        for (final photo in photos)
          AlbumMediaSize(
            photo.width?.toDouble() ?? 0,
            photo.height?.toDouble() ?? 0,
          ),
      ],
      maxWidth: maxWidth,
    );
  }

  static double layoutWidth(List<PhotoAttachment> photos) =>
      layoutOf(photos).width;

  BorderRadius _bubbleRadius() {
    final shape = ctx.shape;
    final isTop =
        shape == BubbleShape.singleTop || shape == BubbleShape.singleMiddle;
    final isBottom =
        shape == BubbleShape.singleBottom || shape == BubbleShape.singleMiddle;
    return computeBubbleRadius(
      isMe: ctx.isMe,
      isTop: isTop,
      isBottom: isBottom,
      style: AppBubbleShape.current.value,
      behavior: AppBubbleBehavior.current.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMessageCaption = ctx.contentText?.isNotEmpty ?? false;
    final resolvedCaption = hasMessageCaption ? ctx.caption() : null;
    final hasCaption = resolvedCaption != null;
    final maxW = MediaQuery.sizeOf(context).width;
    final layout = layoutOf(
      photos,
      maxWidth: photos.length == 1
          ? BubbleContext.photoMaxSize
          : (maxW * 0.80).clamp(240.0, BubbleContext.photoMaxSize),
    );
    final clip = albumClipRadius(
      _bubbleRadius(),
      hasCaption: hasCaption,
      hasContentAbove: hasContentAbove,
    );

    final photosWidget = _buildAlbum(layout, clip);

    if (!hasCaption) {
      return SizedBox(
        width: layout.width,
        height: layout.height,
        child: Stack(
          children: [
            photosWidget,
            Positioned(
              bottom: BubbleContext.compactTimePadding,
              right: BubbleContext.compactTimePadding,
              child: ctx.compactTime(),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: layout.width,
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

  Widget _buildAlbum(AlbumLayout layout, BorderRadius clip) {
    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: ClipRRect(
        borderRadius: clip,
        child: Stack(
          children: [
            for (final tile in layout.tiles)
              Positioned(
                left: tile.left,
                top: tile.top,
                width: tile.width,
                height: tile.height,
                child: _buildFillTile(
                  ctx,
                  photos[tile.index],
                  tile.index,
                  tile.width,
                  tile.height,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoImage(
    BubbleContext ctx,
    PhotoAttachment photo,
    double width,
    double height, {
    required int memWidth,
    BoxFit fit = BoxFit.cover,
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
              fit: fit,
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
          fit: fit,
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
          fit: fit,
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

  Widget _buildFillTile(
    BubbleContext ctx,
    PhotoAttachment photo,
    int index,
    double tileWidth,
    double tileHeight,
  ) {
    final cachePx =
        (tileWidth * MediaQuery.of(ctx.context).devicePixelRatio).round();
    final media = _buildPhotoImage(
      ctx,
      photo,
      double.infinity,
      double.infinity,
      memWidth: cachePx,
      fit: BoxFit.cover,
    );
    final framed = _needsSideBlur(photo, tileWidth, tileHeight)
        ? _blurFilledMedia(
            _buildPhotoImage(
              ctx,
              photo,
              double.infinity,
              double.infinity,
              memWidth: cachePx,
              fit: BoxFit.cover,
            ),
            _buildPhotoImage(
              ctx,
              photo,
              double.infinity,
              double.infinity,
              memWidth: cachePx,
              fit: BoxFit.contain,
            ),
          )
        : media;
    return Stack(
      fit: StackFit.expand,
      children: [
        framed,
        if (ctx.uploadProgress != null)
          _buildUploadOverlay(ctx.uploadProgress!, index),
        if (ctx.uploadProgress == null)
          _buildTileTapTarget(ctx, index, cachePx),
      ],
    );
  }

  bool _needsSideBlur(
    PhotoAttachment photo,
    double tileWidth,
    double tileHeight,
  ) {
    if (tileWidth <= 0 || tileHeight <= 0) return false;
    final pw = photo.width?.toDouble() ?? 0;
    final ph = photo.height?.toDouble() ?? 0;
    final photoRatio = pw > 0 && ph > 0 ? pw / ph : 1.0;
    return photoRatio < (tileWidth / tileHeight) * 0.92;
  }

  Widget _blurFilledMedia(Widget backdrop, Widget foreground) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Transform.scale(scale: 1.16, child: backdrop),
          ),
        ),
        const ColoredBox(color: Color(0x3A000000)),
        foreground,
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

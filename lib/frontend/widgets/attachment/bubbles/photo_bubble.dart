import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:komet/main.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/utils/format.dart';
import '../../../../models/attachment.dart';
import '../../../../models/upload_bytes.dart';
import '../../../../core/media/preview_image.dart';
import '../../photo_viewer.dart';
import '../photo_hero.dart';
import '../../text_with_meta.dart';
import 'album_layout.dart';
import '../../upload_bytes_label.dart';
import '../../upload_progress_ring.dart';
import 'edge_stretch_fill.dart';
import 'bubble_context.dart';
import 'media_autoplay.dart';
import 'network_photo.dart';
import 'video_bubble.dart';
import '../../../../core/config/komet_settings.dart';
import '../../../../core/media/auto_download_gate.dart';

class PhotoBubble extends StatelessWidget {
  static const String gifLabel = 'GIF';
  static const Radius _bigRadius = Radius.circular(
    BubbleContext.bubbleBorderRadius,
  );
  static const Radius _smallRadius = Radius.circular(4);
  static const Radius _photoRadius = Radius.circular(
    BubbleContext.photoBorderRadius,
  );

  final BubbleContext ctx;
  final List<MessageAttachment> media;
  final bool hasContentAbove;

  const PhotoBubble({
    super.key,
    required this.ctx,
    required this.media,
    this.hasContentAbove = false,
  });

  // #***! альбом собирает фото и обычные видео, кружки живут отдельно
  static bool isAlbumMedia(MessageAttachment item) =>
      item is PhotoAttachment || (item is VideoAttachment && !item.isNote);

  static int? _intrinsicWidth(MessageAttachment item) => switch (item) {
    PhotoAttachment(:final width) => width,
    VideoAttachment(:final width) => width,
    _ => null,
  };

  static int? _intrinsicHeight(MessageAttachment item) => switch (item) {
    PhotoAttachment(:final height) => height,
    VideoAttachment(:final height) => height,
    _ => null,
  };

  static double _aspectRatio(MessageAttachment item) {
    final w = _intrinsicWidth(item)?.toDouble();
    final h = _intrinsicHeight(item)?.toDouble();
    if (w == null || h == null || w <= 0 || h <= 0) return 1.0;
    return w / h;
  }

  static String? _localPathOf(MessageAttachment item) => switch (item) {
    PhotoAttachment(:final localPath) => localPath,
    VideoAttachment(:final localPath) => localPath,
    _ => null,
  };

  // #***! у видео обложка отдельным полем, baseUrl это уже сам файл
  static String _previewUrlOf(MessageAttachment item) {
    if (item is VideoAttachment) {
      final thumb = item.thumbnail;
      if (thumb != null && thumb.isNotEmpty) return thumb;
      return item.baseUrl ?? '';
    }
    if (item is PhotoAttachment) {
      final still = item.isGif ? item.previewUrl : null;
      if (still != null && still.isNotEmpty) return still;
      return item.baseUrl ?? '';
    }
    return '';
  }

  Widget _autoplay(
    BuildContext context,
    BubbleContext ctx,
    MessageAttachment item, {
    required MediaAutoplayBuilder builder,
  }) {
    final clip = switch (item) {
      VideoAttachment() => AutoplayClip.video(
        item,
        messageId: ctx.sourceMessageId,
        chatId: ctx.sourceChatId,
      ),
      PhotoAttachment() => AutoplayClip.gif(item),
      _ => null,
    };
    if (clip == null) return builder(context, const SizedBox.shrink(), false);
    final previewUrl = _previewUrlOf(item);
    return MediaAutoplay(
      clip: clip,
      manualLoadKey: previewUrl.isEmpty || previewUrl.startsWith('data:')
          ? null
          : previewUrl,
      suspended: ctx.uploadProgress != null,
      builder: builder,
    );
  }

  static double layoutWidth(
    List<MessageAttachment> media, {
    bool hasCaption = false,
  }) {
    if (media.length != 1) return BubbleContext.photoMaxSize;
    return _displaySize(media.single, hasCaption: hasCaption).width;
  }

  static Size _displaySize(MessageAttachment item, {bool hasCaption = false}) {
    final minWidth = hasCaption
        ? BubbleContext.captionedMediaMinWidth
        : BubbleContext.photoMinSize;
    final width = _intrinsicWidth(item)?.toDouble() ?? 200;
    final height = _intrinsicHeight(item)?.toDouble() ?? 200;

    final downScale = math.min(
      1.0,
      math.min(
        BubbleContext.photoMaxSize / width,
        BubbleContext.photoMaxSize / height,
      ),
    );
    var displayWidth = width * downScale;
    var displayHeight = height * downScale;

    final upScale = math.max(
      1.0,
      math.max(
        minWidth / displayWidth,
        BubbleContext.photoMinSize / displayHeight,
      ),
    );
    displayWidth *= upScale;
    displayHeight *= upScale;

    return Size(
      displayWidth.clamp(minWidth, BubbleContext.photoMaxSize),
      displayHeight.clamp(
        BubbleContext.photoMinSize,
        BubbleContext.photoMaxSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMessageCaption = ctx.contentText?.isNotEmpty ?? false;
    final resolvedCaption = hasMessageCaption ? ctx.caption() : null;
    final hasCaption = resolvedCaption != null;
    final count = media.length;

    Widget photosWidget;
    if (count == 1) {
      photosWidget = _buildSinglePhoto(
        ctx,
        media[0],
        hasCaption: hasCaption,
        hasContentAbove: hasContentAbove,
      );
    } else {
      photosWidget = _buildAlbum(ctx, media);
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
        width: layoutWidth(media, hasCaption: true),
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
          child: TextWithMeta(
            text: resolvedCaption,
            meta: ctx.meta(),
            fillWidth: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePhoto(
    BubbleContext ctx,
    MessageAttachment photo, {
    required bool hasCaption,
    required bool hasContentAbove,
  }) {
    final size = _displaySize(photo, hasCaption: hasCaption);
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
    final shown = _shownSize(photo, size);
    final decoded = _coverSize(photo, shown);
    final memWidth = (decoded.width * dpr).round();
    final memHeight = (decoded.height * dpr).round();

    return ClipRRect(
      borderRadius: radius,
      child: _autoplay(
        ctx.context,
        ctx,
        photo,
        builder: (context, surface, playing) => Stack(
        children: [
          _buildLetterboxedImage(
            ctx,
            photo,
            size,
            shown,
            memWidth: memWidth,
            memHeight: memHeight,
          ),
          Positioned.fill(
            child: shown == size
                ? surface
                : Center(child: SizedBox.fromSize(size: shown, child: surface)),
          ),
          ..._mediaBadges(ctx, photo, compact: false, playing: playing),
          if (ctx.uploadProgress != null)
            _buildUploadOverlay(ctx, ctx.uploadProgress!, 0),
          if (ctx.uploadProgress == null)
            Positioned.fill(
              child: Builder(
                builder: (tileContext) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_awaitsManualLoad(photo)) {
                      AutoDownloadGate.loadManually(_previewUrlOf(photo));
                      return;
                    }
                    _openMedia(
                      ctx.context,
                      0,
                      tileContext: tileContext,
                      radius: radius,
                      memWidth: memWidth,
                      memHeight: memHeight,
                      letterboxed: shown != size,
                    );
                  },
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  static const double _minVisibleFraction = 0.6;

  static bool _isLetterboxed(MessageAttachment photo, Size box) {
    final imageAspect = _aspectRatio(photo);
    final boxAspect = box.width / box.height;
    final visible =
        math.min(imageAspect, boxAspect) / math.max(imageAspect, boxAspect);
    return visible < _minVisibleFraction;
  }

  static Size _coverSize(MessageAttachment photo, Size box) {
    final imageAspect = _aspectRatio(photo);
    return imageAspect > box.width / box.height
        ? Size(box.height * imageAspect, box.height)
        : Size(box.width, box.width / imageAspect);
  }

  static Size _shownSize(MessageAttachment photo, Size box) {
    if (!_isLetterboxed(photo, box)) return box;
    final imageAspect = _aspectRatio(photo);
    return imageAspect < box.width / box.height
        ? Size(box.height * imageAspect, box.height)
        : Size(box.width, box.width / imageAspect);
  }

  Widget _buildLetterboxedImage(
    BubbleContext ctx,
    MessageAttachment photo,
    Size box,
    Size shown, {
    required int memWidth,
    required int memHeight,
  }) {
    final image = _buildPhotoImage(
      ctx,
      photo,
      shown.width,
      shown.height,
      memWidth: memWidth,
      memHeight: memHeight,
    );
    if (shown == box) return image;
    return SizedBox.fromSize(
      size: box,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildEdgeFill(ctx, photo, memWidth: memWidth, memHeight: memHeight),
          Center(child: image),
        ],
      ),
    );
  }

  Widget _buildEdgeFill(
    BubbleContext ctx,
    MessageAttachment photo, {
    required int memWidth,
    required int memHeight,
  }) {
    Widget fill(ImageProvider? source) => EdgeStretchFill(
      source: source,
      imageAspect: _aspectRatio(photo),
      fallback: ctx.cs.surfaceContainerHighest,
    );
    final preview = dataUriImage(photo, photo.previewData);
    if (preview != null || _localPathOf(photo) != null) {
      return fill(
        preview ??
            _photoProvider(photo, memWidth: memWidth, memHeight: memHeight),
      );
    }
    final url = _previewUrlOf(photo);
    if (url.isEmpty || url.startsWith('data:')) return fill(null);
    return ListenableBuilder(
      listenable: Listenable.merge([
        AutoDownloadGate.listen(url),
        KometSettings.autoDownloadPhoto,
      ]),
      builder: (context, _) => fill(
        AutoDownloadGate.allows(KometSettings.autoDownloadPhoto.value, url)
            ? _photoProvider(photo, memWidth: memWidth, memHeight: memHeight)
            : null,
      ),
    );
  }

  Widget _buildPhotoImage(
    BubbleContext ctx,
    MessageAttachment photo,
    double width,
    double height, {
    required int memWidth,
    required int memHeight,
  }) {
    final localPath = _localPathOf(photo);
    if (localPath != null) {
      return Image.file(
        File(localPath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: memWidth,
        gaplessPlayback: true,
        frameBuilder: (_, child, frame, synchronouslyLoaded) =>
            frame != null || synchronouslyLoaded
            ? child
            : _buildPreviewImage(ctx, photo, width, height),
        errorBuilder: (_, _, _) => _buildNetworkPhoto(
          ctx,
          photo,
          width,
          height,
          memWidth: memWidth,
          memHeight: memHeight,
        ),
      );
    }
    return _buildNetworkPhoto(
      ctx,
      photo,
      width,
      height,
      memWidth: memWidth,
      memHeight: memHeight,
    );
  }

  Widget _buildNetworkPhoto(
    BubbleContext ctx,
    MessageAttachment photo,
    double width,
    double height, {
    required int memWidth,
    required int memHeight,
  }) {
    final imageUrl = _previewUrlOf(photo);
    if (imageUrl.isEmpty || imageUrl.startsWith('data:')) {
      return _buildPreviewImage(ctx, photo, width, height);
    }
    return ListenableBuilder(
      listenable: Listenable.merge([
        AutoDownloadGate.listen(imageUrl),
        KometSettings.autoDownloadPhoto,
      ]),
      builder: (context, _) {
        if (!AutoDownloadGate.allows(
          KometSettings.autoDownloadPhoto.value,
          imageUrl,
        )) {
          return _manualLoadTile(ctx, photo, imageUrl, width, height);
        }
        return NetworkPhoto(
          url: imageUrl,
          width: width,
          height: height,
          memWidth: memWidth,
          memHeight: memHeight,
          logId: switch (photo) {
            PhotoAttachment(:final photoId) => photoId,
            VideoAttachment(:final videoId) => videoId,
            _ => null,
          },
          fallback: (_) => _buildPreviewImage(ctx, photo, width, height),
        );
      },
    );
  }

  Widget _manualLoadTile(
    BubbleContext ctx,
    MessageAttachment photo,
    String key,
    double width,
    double height,
  ) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPreviewImage(ctx, photo, width, height),
          Center(
            child: GestureDetector(
              onTap: () => AutoDownloadGate.loadManually(key),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.download, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewImage(
    BubbleContext ctx,
    MessageAttachment photo,
    double width,
    double height,
  ) {
    final preview = dataUriImage(photo, photo.previewData);
    if (preview == null) return _buildPhotoPlaceholder(ctx.cs, width, height);
    return Image(
      image: preview,
      width: width,
      height: height,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _buildPhotoPlaceholder(ctx.cs, width, height),
    );
  }

  // #***! плитка видео отличается от фото только кружком плеера и длительностью
  List<Widget> _mediaBadges(
    BubbleContext ctx,
    MessageAttachment item, {
    required bool compact,
    bool playing = false,
  }) {
    if (item is PhotoAttachment && item.isGif) {
      return [
        Positioned(
          left: BubbleContext.compactTimePadding,
          bottom: BubbleContext.compactTimePadding,
          child: ctx.overlayLabel(gifLabel),
        ),
      ];
    }
    if (item is! VideoAttachment) return const [];
    final side = compact ? 36.0 : 48.0;
    final durationMs = item.duration;
    return [
      Positioned.fill(
        child: Center(
          child: AnimatedOpacity(
            opacity: playing ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: side,
              height: side,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.play_arrow,
                color: Colors.white,
                size: side * 0.625,
              ),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatSecondsMmSs((durationMs / 1000).round()),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                if (playing) ...[
                  const SizedBox(width: 4),
                  const Icon(Symbols.volume_off, color: Colors.white, size: 13),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  Widget _buildUploadOverlay(
    BubbleContext ctx,
    ValueListenable<List<UploadBytes>> progress,
    int index,
  ) {
    final cancelItem = ctx.onCancelUploadItem;
    return Positioned.fill(
      child: _UploadSlotOverlay(
        progress: progress,
        slot: index,
        onCancel: cancelItem != null
            ? () => cancelItem(index)
            : ctx.onCancelUpload,
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

  Widget _buildAlbum(BubbleContext ctx, List<MessageAttachment> photos) {
    final visible = math.min(photos.length, AlbumLayout.maxTiles);
    final remaining = photos.length - visible;
    final grid = AlbumLayout.layout([
      for (var i = 0; i < visible; i++) _aspectRatio(photos[i]),
    ]);

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
      child: AspectRatio(
        aspectRatio: grid.aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            return Stack(
              children: [
                for (var i = 0; i < visible; i++)
                  Positioned.fromRect(
                    rect: _insetTile(grid.tiles[i], width, height),
                    child: _buildAlbumTile(
                      ctx,
                      photos[i],
                      i,
                      overlay: i == visible - 1 && remaining > 0
                          ? '+$remaining'
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const double _tileGap = 2;
  static const double _edgeEpsilon = 1e-6;

  static Rect _insetTile(Rect tile, double width, double height) {
    const half = _tileGap / 2;
    return Rect.fromLTRB(
      tile.left * width + (tile.left > _edgeEpsilon ? half : 0),
      tile.top * height + (tile.top > _edgeEpsilon ? half : 0),
      tile.right * width - (tile.right < 1 - _edgeEpsilon ? half : 0),
      tile.bottom * height - (tile.bottom < 1 - _edgeEpsilon ? half : 0),
    );
  }

  Widget _buildAlbumTile(
    BubbleContext ctx,
    MessageAttachment photo,
    int index, {
    String? overlay,
  }) {
    final dpr = MediaQuery.of(ctx.context).devicePixelRatio;
    final ratio = _aspectRatio(photo);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : BubbleContext.photoMaxSize / 2;
        final tileHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : tileWidth / ratio;
        final coverWidth = math.max(tileWidth, tileHeight * ratio);
        final memWidth = (coverWidth * dpr).round().clamp(1, 2048);
        final memHeight = math.max(1, (memWidth / ratio).round());
        Widget tile(Widget surface, bool playing) => Stack(
          children: [
            _buildPhotoImage(
              ctx,
              photo,
              double.infinity,
              double.infinity,
              memWidth: memWidth,
              memHeight: memHeight,
            ),
            Positioned.fill(child: surface),
            if (overlay == null)
              ..._mediaBadges(ctx, photo, compact: true, playing: playing)
            else
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
              _buildUploadOverlay(ctx, ctx.uploadProgress!, index),
            if (ctx.uploadProgress == null)
              _buildTileTapTarget(ctx, index, memWidth, memHeight, photo),
          ],
        );
        if (overlay != null) return tile(const SizedBox.shrink(), false);
        return _autoplay(
          context,
          ctx,
          photo,
          builder: (context, surface, playing) => tile(surface, playing),
        );
      },
    );
  }

  Widget _buildTileTapTarget(
    BubbleContext ctx,
    int index,
    int memWidth,
    int memHeight,
    MessageAttachment photo,
  ) {
    return Positioned.fill(
      child: Builder(
        builder: (tileContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_awaitsManualLoad(photo)) {
              AutoDownloadGate.loadManually(_previewUrlOf(photo));
              return;
            }
            _openMedia(
              ctx.context,
              index,
              tileContext: tileContext,
              radius: BorderRadius.zero,
              memWidth: memWidth,
              memHeight: memHeight,
            );
          },
        ),
      ),
    );
  }

  bool _awaitsManualLoad(MessageAttachment photo) {
    if (_localPathOf(photo) != null) return false;
    final url = _previewUrlOf(photo);
    if (url.isEmpty || url.startsWith('data:')) return false;
    return !AutoDownloadGate.allows(
      KometSettings.autoDownloadPhoto.value,
      url,
    );
  }

  Widget _buildPhotoPlaceholder(ColorScheme cs, double w, double h) {
    return Container(
      width: w,
      height: h,
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(Symbols.image, size: 48, color: cs.onSurfaceVariant),
      ),
    );
  }

  static ImageProvider? _photoProvider(
    MessageAttachment photo, {
    required int memWidth,
    required int memHeight,
  }) {
    final localPath = _localPathOf(photo);
    if (localPath != null) {
      return ResizeImage.resizeIfNeeded(
        memWidth,
        null,
        FileImage(File(localPath)),
      );
    }
    final url = _previewUrlOf(photo);
    if (url.isEmpty || url.startsWith('data:')) {
      return dataUriImage(photo, photo.previewData);
    }
    return ResizeImage.resizeIfNeeded(
      memWidth,
      memHeight,
      CachedNetworkImageProvider(url),
    );
  }

  static Size? _photoSize(MessageAttachment photo) {
    final width = _intrinsicWidth(photo) ?? 0;
    final height = _intrinsicHeight(photo) ?? 0;
    if (width <= 0 || height <= 0) return null;
    return Size(width.toDouble(), height.toDouble());
  }

  // #***! просмотрщик листает только фото, видео из альбома уходит в плеер
  void _openMedia(
    BuildContext context,
    int index, {
    required BuildContext tileContext,
    required BorderRadius radius,
    required int memWidth,
    required int memHeight,
    bool letterboxed = false,
  }) {
    final photo = media[index];
    if (photo is VideoAttachment) {
      openVideoPlayer(ctx, photo);
      return;
    }
    final photos = media.whereType<PhotoAttachment>().toList();
    final photoIndex = photos.indexOf(photo as PhotoAttachment);
    final imageSize = _photoSize(photo);
    final hero = PhotoHeroController(
      origin: () {
        final box = photoHeroRectOf(tileContext);
        if (box == null || !letterboxed || imageSize == null) return box;
        return inscribeRect(imageSize, box);
      },
      image: _photoProvider(photo, memWidth: memWidth, memHeight: memHeight),
      size: _photoSize(photo),
      radius: radius,
    );
    Navigator.of(context).push(
      PhotoHeroRoute<void>(
        hero: hero,
        builder: (_) => PhotoViewerScreen(
          photos: photos,
          initialIndex: photoIndex < 0 ? 0 : photoIndex,
          chatId: ctx.chatId,
          message: ctx.message,
          actions: ctx.photoActions,
          hero: hero,
          sourceName: ctx.chatName,
          videoUserAgentProvider: () => api.session?.userAgent(),
        ),
      ),
    );
  }
}

class _UploadSlotOverlay extends StatefulWidget {
  const _UploadSlotOverlay({
    required this.progress,
    required this.slot,
    required this.onCancel,
  });

  final ValueListenable<List<UploadBytes>> progress;
  final int slot;
  final VoidCallback? onCancel;

  @override
  State<_UploadSlotOverlay> createState() => _UploadSlotOverlayState();
}

class _UploadSlotOverlayState extends State<_UploadSlotOverlay> {
  late bool _done = _isDone;

  bool get _isDone =>
      UploadProgressRing.fractionOf(widget.progress.value, widget.slot) >= 1;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgress);
  }

  @override
  void didUpdateWidget(_UploadSlotOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.progress, widget.progress)) {
      oldWidget.progress.removeListener(_onProgress);
      widget.progress.addListener(_onProgress);
    }
    _done = _isDone;
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    super.dispose();
  }

  void _onProgress() {
    final done = _isDone;
    if (done != _done) setState(() => _done = done);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: _done,
      child: AnimatedOpacity(
        opacity: _done ? 0 : 1,
        duration: const Duration(milliseconds: 240),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onCancel,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.4),
            child: Stack(
              children: [
                Center(
                  child: UploadProgressRing(
                    progress: widget.progress,
                    slot: widget.slot,
                    color: Colors.white,
                    trackColor: Colors.white24,
                    size: 52,
                    iconSize: 18,
                    onCancel: widget.onCancel,
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  right: 6,
                  child: UploadBytesLabel(
                    progress: widget.progress,
                    slot: widget.slot,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

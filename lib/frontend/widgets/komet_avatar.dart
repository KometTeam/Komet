import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_spectrum_background.dart';
import 'local_avatar_builder.dart';
import 'spectrum_tint.dart';

/// Circular avatar: shows [imageUrl] when available, otherwise the first letter
/// of [name] on a colored background. Falls back to the letter on image error.
class KometAvatar extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? fontSize;
  final bool fadeIn;
  final int? userId;

  const KometAvatar({
    super.key,
    required this.name,
    required this.size,
    this.imageUrl,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize,
    this.fadeIn = true,
    this.userId,
  });

  static const _fadeInDuration = Duration(milliseconds: 500);
  static const _fadeOutDuration = Duration(milliseconds: 1000);
  static const _decodeSteps = [48, 96, 144, 192, 288, 384, 576, 768, 1152];

  static int decodeSizeFor(double size) {
    final wanted = (size * 3).round();
    for (final step in _decodeSteps) {
      if (step >= wanted) return step;
    }
    return wanted;
  }

  @override
  State<KometAvatar> createState() => _KometAvatarState();
}

class _KometAvatarState extends State<KometAvatar>
    implements SpectrumTintSource {
  Color _background = const Color(0xFF000000);
  bool _registered = false;
  int _decodeSize = 0;
  bool _keepPrevious = false;

  @override
  void initState() {
    super.initState();
    AppSpectrumBackground.current.addListener(_syncRegistration);
    _syncRegistration();
    _decodeSize = KometAvatar.decodeSizeFor(widget.size);
  }

  @override
  void didUpdateWidget(KometAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wanted = KometAvatar.decodeSizeFor(widget.size);
    final sameImage =
        oldWidget.imageUrl == widget.imageUrl &&
        oldWidget.userId == widget.userId;
    if (!sameImage) {
      _decodeSize = wanted;
      _keepPrevious = false;
    } else if (wanted > _decodeSize) {
      _decodeSize = wanted;
      _keepPrevious = true;
    }
  }

  @override
  void dispose() {
    AppSpectrumBackground.current.removeListener(_syncRegistration);
    if (_registered) SpectrumTintRegistry.instance.unregister(this);
    super.dispose();
  }

  void _syncRegistration() {
    final shouldRegister = AppSpectrumBackground.isEnabled;
    if (shouldRegister == _registered) return;
    _registered = shouldRegister;
    if (shouldRegister) {
      SpectrumTintRegistry.instance.register(this);
    } else {
      SpectrumTintRegistry.instance.unregister(this);
    }
  }

  @override
  BuildContext? get tintContext => mounted ? context : null;

  @override
  String? get tintImageUrl => widget.imageUrl;

  @override
  Color get tintFallbackColor => _background;

  @override
  double get tintWeight => widget.size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = widget.backgroundColor ?? cs.primaryContainer;
    final fg = widget.foregroundColor ?? cs.onPrimaryContainer;
    _background = bg;
    final letter = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    final placeholder = Center(
      child: Text(
        letter,
        style: TextStyle(
          color: fg,
          fontSize: widget.fontSize ?? widget.size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    final url = widget.imageUrl;
    final cache = _decodeSize;
    final remote = (url != null && url.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth: cache,
            memCacheHeight: cache,
            useOldImageOnUrlChange: _keepPrevious,
            fadeInDuration: widget.fadeIn
                ? KometAvatar._fadeInDuration
                : Duration.zero,
            fadeOutDuration: widget.fadeIn
                ? KometAvatar._fadeOutDuration
                : Duration.zero,
            errorWidget: (_, _, _) => placeholder,
          )
        : placeholder;
    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: LocalAvatarBuilder(
        userId: widget.userId ?? 0,
        builder: (context, local) => local == null
            ? remote
            : Image(
                image: ResizeImage(local, width: cache, height: cache),
                fit: BoxFit.cover,
                gaplessPlayback: _keepPrevious,
                errorBuilder: (_, _, _) => remote,
              ),
      ),
    );
  }
}

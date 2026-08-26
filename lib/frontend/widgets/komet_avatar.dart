import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_spectrum_background.dart';
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

  const KometAvatar({
    super.key,
    required this.name,
    required this.size,
    this.imageUrl,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize,
    this.fadeIn = true,
  });

  static const _fadeInDuration = Duration(milliseconds: 500);
  static const _fadeOutDuration = Duration(milliseconds: 1000);

  @override
  State<KometAvatar> createState() => _KometAvatarState();
}

class _KometAvatarState extends State<KometAvatar>
    implements SpectrumTintSource {
  Color _background = const Color(0xFF000000);
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    AppSpectrumBackground.current.addListener(_syncRegistration);
    _syncRegistration();
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
    final cache = (widget.size * 3).round();
    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: cache,
              memCacheHeight: cache,
              fadeInDuration: widget.fadeIn
                  ? KometAvatar._fadeInDuration
                  : Duration.zero,
              fadeOutDuration: widget.fadeIn
                  ? KometAvatar._fadeOutDuration
                  : Duration.zero,
              errorWidget: (_, _, _) => placeholder,
            )
          : placeholder,
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular avatar: shows [imageUrl] when available, otherwise the first letter
/// of [name] on a colored background. Falls back to the letter on image error.
class KometAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? fontSize;

  const KometAvatar({
    super.key,
    required this.name,
    required this.size,
    this.imageUrl,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.primaryContainer;
    final fg = foregroundColor ?? cs.onPrimaryContainer;
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final placeholder = Center(
      child: Text(
        letter,
        style: TextStyle(
          color: fg,
          fontSize: fontSize ?? size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    final url = imageUrl;
    final cache = (size * 3).round();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: cache,
              memCacheHeight: cache,
              errorWidget: (_, _, _) => placeholder,
            )
          : placeholder,
    );
  }
}

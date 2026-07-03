import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'sticker_lottie.dart';

class StickerImage extends StatelessWidget {
  final String? url;
  final String? lottieUrl;
  final double? size;
  final int? memCacheWidth;

  const StickerImage({
    super.key,
    this.url,
    this.lottieUrl,
    this.size,
    this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (lottieUrl != null && lottieUrl!.isNotEmpty) {
      return StickerLottie(
        lottieUrl: lottieUrl!,
        fallbackUrl: url,
        size: size,
        memCacheWidth: memCacheWidth,
      );
    }
    return _static();
  }

  Widget _static() {
    final src = url ?? '';
    final blank = SizedBox(width: size, height: size);
    if (src.isEmpty) return blank;
    return CachedNetworkImage(
      imageUrl: src,
      width: size,
      height: size,
      fit: BoxFit.contain,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => blank,
      errorWidget: (_, _, _) => blank,
    );
  }
}

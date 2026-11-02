import 'package:flutter/material.dart';

import '../../core/config/komet_settings.dart';
import 'lottie_image.dart';

class MessageAnimoji extends StatelessWidget {
  final String lottieUrl;
  final double size;
  final int memCacheWidth;
  final Widget? placeholder;
  final bool shimmer;
  final bool eager;

  const MessageAnimoji({
    super.key,
    required this.lottieUrl,
    required this.size,
    required this.memCacheWidth,
    this.placeholder,
    this.shimmer = true,
    this.eager = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: KometSettings.autoplayAnimoji,
      builder: (context, animate, _) => LottieImage(
        lottieUrl: lottieUrl,
        size: size,
        memCacheWidth: memCacheWidth,
        placeholder: placeholder,
        shimmer: shimmer,
        eager: eager,
        animate: animate,
      ),
    );
  }
}

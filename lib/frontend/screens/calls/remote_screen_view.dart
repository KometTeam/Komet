import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/calls/remote_screens.dart';

class RemoteScreenContent extends StatelessWidget {
  const RemoteScreenContent({super.key, required this.screen});

  final RemoteScreen screen;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: switch (screen) {
        RemoteScreenPicture(:final image) => RawImage(
          image: image,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
        RemoteScreenTexture(:final textureId) => Center(
          child: AspectRatio(
            aspectRatio: screen.aspectRatio,
            child: Texture(
              textureId: textureId,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      },
    );
  }
}

class RemoteScreenView extends StatelessWidget {
  const RemoteScreenView({
    super.key,
    required this.screen,
    required this.fallback,
  });

  final ValueListenable<RemoteScreen?> screen;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RemoteScreen?>(
      valueListenable: screen,
      builder: (context, value, _) =>
          value == null ? fallback : RemoteScreenContent(screen: value),
    );
  }
}

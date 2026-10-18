import 'package:flutter/material.dart';

import '../../core/window/window_frame.dart';

class WindowTitleStrip extends StatelessWidget {
  const WindowTitleStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: WindowFrame.inset,
      builder: (context, inset, _) {
        if (inset <= 0) return const SizedBox.shrink();
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => WindowFrame.startDrag(),
            onDoubleTap: WindowFrame.toggleZoom,
            child: SizedBox(height: inset),
          ),
        );
      },
    );
  }
}

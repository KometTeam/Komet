import 'package:flutter/material.dart';

import '../../main.dart' show animojiModule;
import '../../models/animoji.dart';
import 'lottie_image.dart';

class AnimojiGlyph extends StatefulWidget {
  final String emoji;
  final double size;

  const AnimojiGlyph({super.key, required this.emoji, required this.size});

  @override
  State<AnimojiGlyph> createState() => _AnimojiGlyphState();
}

class _AnimojiGlyphState extends State<AnimojiGlyph> {
  late Future<Animoji?> _animoji = _resolve(widget.emoji);

  static Future<Animoji?> _resolve(String emoji) async {
    final known = animojiModule.findByEmoji(emoji);
    if (known != null) return known;
    try {
      await animojiModule.ensureLoaded();
    } catch (_) {
      return null;
    }
    return animojiModule.findByEmoji(emoji);
  }

  @override
  void didUpdateWidget(AnimojiGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emoji != widget.emoji) _animoji = _resolve(widget.emoji);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final glyph = Center(
      child: Text(widget.emoji, style: TextStyle(fontSize: size * 0.72)),
    );
    return SizedBox.square(
      dimension: size,
      child: FutureBuilder<Animoji?>(
        future: _animoji,
        initialData: animojiModule.findByEmoji(widget.emoji),
        builder: (context, snapshot) {
          final source = snapshot.data;
          if (source == null) return glyph;
          return LottieImage(
            url: source.iconUrl,
            lottieUrl: source.lottieUrl,
            size: size,
            memCacheWidth: (size * 2).round(),
            placeholder: glyph,
            shimmer: false,
            eager: true,
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

class GalaxyAnimatedText extends StatefulWidget {
  final String text;

  const GalaxyAnimatedText({super.key, required this.text});

  @override
  State<GalaxyAnimatedText> createState() => _GalaxyAnimatedTextState();
}

class _GalaxyAnimatedTextState extends State<GalaxyAnimatedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final color = Color.lerp(Colors.black, Colors.white, t)!;

        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, Color.lerp(Colors.white, Colors.black, t)!],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}

class PulseAnimatedText extends StatefulWidget {
  final String text;

  const PulseAnimatedText({super.key, required this.text});

  @override
  State<PulseAnimatedText> createState() => _PulseAnimatedTextState();
}

class _PulseAnimatedTextState extends State<PulseAnimatedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Color? _pulseColor;

  @override
  void initState() {
    super.initState();
    _parseColor();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  void _parseColor() {
    final text = widget.text;
    const prefix = "komet.cosmetic.pulse#";
    if (!text.startsWith(prefix)) {
      _pulseColor = Colors.red;
      return;
    }

    final afterHash = text.substring(prefix.length);
    final quoteIndex = afterHash.indexOf("'");
    if (quoteIndex == -1) {
      _pulseColor = Colors.red;
      return;
    }

    final hexStr = afterHash.substring(0, quoteIndex).trim();
    _pulseColor = _parseHexColor(hexStr);
  }

  Color _parseHexColor(String hex) {
    String hexClean = hex.trim();
    if (hexClean.startsWith('#')) {
      hexClean = hexClean.substring(1);
    }

    if (hexClean.isEmpty) {
      return Colors.red;
    }

    if (hexClean.length == 3) {
      hexClean =
          '${hexClean[0]}${hexClean[0]}${hexClean[1]}${hexClean[1]}${hexClean[2]}${hexClean[2]}';
    } else if (hexClean.length == 4) {
      hexClean =
          '${hexClean[0]}${hexClean[0]}${hexClean[1]}${hexClean[1]}${hexClean[2]}${hexClean[2]}${hexClean[3]}${hexClean[3]}';
    } else if (hexClean.length == 5) {
      hexClean = '0$hexClean';
    } else if (hexClean.length < 6) {
      hexClean = hexClean.padRight(6, '0');
    } else if (hexClean.length > 6) {
      hexClean = hexClean.substring(0, 6);
    }

    try {
      return Color(int.parse('FF$hexClean', radix: 16));
    } catch (e) {
      return Colors.red;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    const prefix = "komet.cosmetic.pulse#";
    if (!text.startsWith(prefix) || !text.endsWith("'")) {
      return Text(text);
    }

    final afterHash = text.substring(prefix.length);
    final quoteIndex = afterHash.indexOf("'");
    if (quoteIndex == -1 || quoteIndex + 1 >= afterHash.length) {
      return Text(text);
    }

    final textStart = quoteIndex + 1;
    final secondQuote = afterHash.indexOf("'", textStart);
    if (secondQuote == -1) {
      return Text(text);
    }

    final messageText = afterHash.substring(textStart, secondQuote);
    final baseColor = _pulseColor ?? Colors.red;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final opacity = 0.5 + (t * 0.5);
        final color = baseColor.withValues(alpha: opacity);

        return Text(
          messageText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        );
      },
    );
  }
}

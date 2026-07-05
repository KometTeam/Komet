import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/utils/link_opener.dart';

final RegExp linkPattern = RegExp(
  r'(https?://[^\s<>]+|www\.[^\s<>]+)',
  caseSensitive: false,
);

class LinkText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const LinkText({super.key, required this.text, required this.style});

  static bool hasLinks(String? text) =>
      text != null && linkPattern.hasMatch(text);

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in linkPattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final url = match.group(0)!;
      final target = url.startsWith('www.') ? 'https://$url' : url;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => openExternalUrl(context, target);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(decoration: TextDecoration.underline),
          recognizer: recognizer,
        ),
      );
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

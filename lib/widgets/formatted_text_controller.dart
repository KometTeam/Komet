import 'package:flutter/material.dart';

class FormattedTextController extends TextEditingController {
  final List<Map<String, dynamic>> elements = [];

  FormattedTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool withComposing = false,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final text = value.text;

    if (text.isEmpty || elements.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final bold = List<bool>.filled(text.length, false);
    final italic = List<bool>.filled(text.length, false);
    final underline = List<bool>.filled(text.length, false);
    final strike = List<bool>.filled(text.length, false);

    for (final el in elements) {
      final type = el['type'] as String?;
      final from = (el['from'] as int?) ?? 0;
      final length = (el['length'] as int?) ?? 0;
      if (type == null || length <= 0) continue;
      final start = from.clamp(0, text.length);
      final end = (from + length).clamp(0, text.length);
      for (int i = start; i < end; i++) {
        switch (type) {
          case 'STRONG':
            bold[i] = true;
            break;
          case 'EMPHASIZED':
            italic[i] = true;
            break;
          case 'UNDERLINE':
            underline[i] = true;
            break;
          case 'STRIKETHROUGH':
            strike[i] = true;
            break;
        }
      }
    }

    final spans = <InlineSpan>[];
    int start = 0;

    TextStyle styleForIndex(int i) {
      var s = baseStyle;
      if (bold[i]) s = s.copyWith(fontWeight: FontWeight.w600);
      if (italic[i]) s = s.copyWith(fontStyle: FontStyle.italic);
      final decos = <TextDecoration>[];
      if (underline[i]) decos.add(TextDecoration.underline);
      if (strike[i]) decos.add(TextDecoration.lineThrough);
      if (decos.isNotEmpty) {
        s = s.copyWith(decoration: TextDecoration.combine(decos));
      }
      return s;
    }

    while (start < text.length) {
      int end = start + 1;
      final base = styleForIndex(start);
      while (end < text.length && styleForIndex(end) == base) {
        end++;
      }
      spans.add(TextSpan(text: text.substring(start, end), style: base));
      start = end;
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}

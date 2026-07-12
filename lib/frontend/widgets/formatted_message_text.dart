import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/utils/link_opener.dart';
import '../../core/utils/text_format.dart';
import 'link_text.dart';
import 'lottie_image.dart';

class FormattedMessageText extends StatefulWidget {
  final String text;
  final List<FormatRange> ranges;
  final TextStyle style;
  final TextAlign textAlign;

  const FormattedMessageText({
    super.key,
    required this.text,
    required this.ranges,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  static bool isFormatted(String? text, List<FormatRange> ranges) =>
      text != null &&
      text.isNotEmpty &&
      (ranges.isNotEmpty || LinkText.hasLinks(text));

  static TextSpan buildInlineSpan(
    String text,
    List<FormatRange> ranges,
    TextStyle style,
  ) {
    final quoteColor = style.color?.withValues(alpha: 0.85);
    final segments = segmentizeFormats(text, ranges);
    return TextSpan(
      style: style,
      children: [
        for (final segment in segments)
          TextSpan(
            text: text.substring(segment.start, segment.end),
            style: applyTextFormats(
              style,
              segment.formats,
              quoteColor: quoteColor,
            ),
          ),
      ],
    );
  }

  @override
  State<FormattedMessageText> createState() => _FormattedMessageTextState();
}

class _FormattedMessageTextState extends State<FormattedMessageText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  List<FormatRange> _withAutoLinks() {
    final ranges = List<FormatRange>.from(widget.ranges);
    final hasExplicitLink = ranges.any((r) => r.format == TextFormat.link);
    if (hasExplicitLink) return ranges;
    for (final match in linkPattern.allMatches(widget.text)) {
      final raw = match.group(0)!;
      final target = raw.startsWith('www.') ? 'https://$raw' : raw;
      ranges.add(
        FormatRange(
          format: TextFormat.link,
          start: match.start,
          length: match.end - match.start,
          attributes: {'url': target},
        ),
      );
    }
    return ranges;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final segments = segmentizeFormats(widget.text, _withAutoLinks());
    final baseColor = widget.style.color ?? Theme.of(context).colorScheme.onSurface;
    final barColor = baseColor.withValues(alpha: 0.4);
    final quoteColor = baseColor.withValues(alpha: 0.85);

    final spans = <InlineSpan>[];
    var prevQuote = false;
    for (final segment in segments) {
      final isQuote = segment.formats.contains(TextFormat.quote);
      if (isQuote && !prevQuote) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 3,
              height: (widget.style.fontSize ?? 16) * 1.15,
              margin: const EdgeInsets.only(right: 6, left: 1),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }
      prevQuote = isQuote;

      final style = applyTextFormats(
        widget.style,
        segment.formats,
        quoteColor: quoteColor,
      );
      final content = widget.text.substring(segment.start, segment.end);
      if (segment.animojiUrl != null) {
        final fontSize = widget.style.fontSize ?? 16;
        final box = fontSize * 1.5;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(
              width: box,
              height: box,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    content,
                    style: widget.style.copyWith(fontSize: fontSize * 1.15),
                  ),
                  LottieImage(
                    lottieUrl: segment.animojiUrl,
                    size: box,
                    memCacheWidth: 120,
                    shimmer: false,
                    eager: true,
                  ),
                ],
              ),
            ),
          ),
        );
        continue;
      }
      if (segment.url != null) {
        final url = segment.url!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => openExternalUrl(context, url);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(text: content, style: style, recognizer: recognizer),
        );
      } else {
        spans.add(TextSpan(text: content, style: style));
      }
    }

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      textAlign: widget.textAlign,
    );
  }
}

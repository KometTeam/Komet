import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../backend/modules/messages.dart' show ContactCache;
import '../../core/utils/link_opener.dart';
import '../../core/utils/text_entities.dart';
import '../../core/utils/text_format.dart';
import '../screens/contacts/open_contact_profile.dart';
import 'link_text.dart';
import 'lottie_image.dart';
import 'text_entity_actions.dart';

Color mentionTextColor(ColorScheme cs) => cs.primary;

enum TextEntityMode { menu, copy }

class FormattedMessageText extends StatefulWidget {
  final String text;
  final List<FormatRange> ranges;
  final TextStyle style;
  final TextAlign textAlign;
  final TextEntityMode entityMode;
  final int? maxLines;
  final TextOverflow? overflow;

  const FormattedMessageText({
    super.key,
    required this.text,
    required this.ranges,
    required this.style,
    this.textAlign = TextAlign.start,
    this.entityMode = TextEntityMode.menu,
    this.maxLines,
    this.overflow,
  });

  static bool isFormatted(String? text, List<FormatRange> ranges) =>
      text != null &&
      text.isNotEmpty &&
      (ranges.isNotEmpty || LinkText.hasLinks(text) || hasTextEntities(text));

  static TextSpan buildInlineSpan(
    String text,
    List<FormatRange> ranges,
    TextStyle style, {
    Color? mentionColor,
  }) {
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
              mentionColor: mentionColor,
            ),
          ),
      ],
    );
  }

  @override
  State<FormattedMessageText> createState() => _FormattedMessageTextState();
}

class _FormattedMessageTextState extends State<FormattedMessageText> {
  final List<GestureRecognizer> _recognizers = [];

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

  void _openMention(int userId) {
    unawaited(
      openContactDialogProfile(
        context,
        contactId: userId,
        name: ContactCache.get(userId) ?? 'User #$userId',
        avatarUrl: ContactCache.getAvatar(userId),
      ),
    );
  }

  T _track<T extends GestureRecognizer>(T recognizer) {
    _recognizers.add(recognizer);
    return recognizer;
  }

  GestureRecognizer? _entityRecognizer(TextEntity entity) {
    switch (entity.kind) {
      case TextEntityKind.mention:
        return _track(
          TapGestureRecognizer()
            ..onTap = () =>
                unawaited(openMentionProfile(context, entity.value)),
        );
      case TextEntityKind.phone:
        if (widget.entityMode == TextEntityMode.copy) {
          return _track(
            TapGestureRecognizer()
              ..onTap = () => unawaited(
                copyTextEntity(context, entity.value, 'Номер скопирован'),
              ),
          );
        }
        return _track(
          LongPressGestureRecognizer()
            ..onLongPressStart = (details) => showPhoneEntityMenu(
              context,
              entity.value,
              at: details.globalPosition,
            ),
        );
      case TextEntityKind.card:
        if (widget.entityMode == TextEntityMode.copy) {
          return _track(
            TapGestureRecognizer()
              ..onTap = () => unawaited(
                copyTextEntity(context, entity.value, 'Номер карты скопирован'),
              ),
          );
        }
        return _track(
          LongPressGestureRecognizer()
            ..onLongPressStart = (details) => showCardEntityMenu(
              context,
              entity.value,
              at: details.globalPosition,
            ),
        );
    }
  }

  List<TextSpanRange> _claimedRanges(List<FormatRange> ranges) => [
    for (final range in ranges)
      if (range.format == TextFormat.link ||
          range.format == TextFormat.userMention)
        (start: range.start, end: range.end),
  ];

  TextEntity? _entityAt(List<TextEntity> entities, int start, int end) {
    for (final entity in entities) {
      if (entity.start <= start && entity.end >= end) return entity;
    }
    return null;
  }

  List<({int start, int end})> _splitByEntities(
    int start,
    int end,
    List<TextEntity> entities,
  ) {
    final points = <int>{start, end};
    for (final entity in entities) {
      if (entity.end <= start || entity.start >= end) continue;
      if (entity.start > start) points.add(entity.start);
      if (entity.end < end) points.add(entity.end);
    }
    final sorted = points.toList()..sort();
    return [
      for (var i = 0; i < sorted.length - 1; i++)
        (start: sorted[i], end: sorted[i + 1]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final ranges = _withAutoLinks();
    final entities = detectTextEntities(
      widget.text,
      skip: _claimedRanges(ranges),
    );
    final segments = segmentizeFormats(widget.text, ranges);
    final cs = Theme.of(context).colorScheme;
    final baseColor = widget.style.color ?? cs.onSurface;
    final barColor = baseColor.withValues(alpha: 0.4);
    final quoteColor = baseColor.withValues(alpha: 0.85);
    final mentionColor = mentionTextColor(cs);

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
        mentionColor: mentionColor,
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
      final mentionId = segment.mentionId;
      if (mentionId != null && mentionId != 0) {
        spans.add(
          TextSpan(
            text: content,
            style: style,
            recognizer: _track(
              TapGestureRecognizer()..onTap = () => _openMention(mentionId),
            ),
          ),
        );
        continue;
      }

      final mentionName = segment.mentionName;
      if (mentionName != null) {
        spans.add(
          TextSpan(
            text: content,
            style: style,
            recognizer: _track(
              TapGestureRecognizer()
                ..onTap = () =>
                    unawaited(openMentionProfile(context, mentionName)),
            ),
          ),
        );
        continue;
      }

      if (segment.url != null) {
        final url = segment.url!;
        spans.add(
          TextSpan(
            text: content,
            style: style,
            recognizer: _track(
              TapGestureRecognizer()
                ..onTap = () => openExternalUrl(context, url),
            ),
          ),
        );
        continue;
      }

      for (final piece in _splitByEntities(
        segment.start,
        segment.end,
        entities,
      )) {
        final entity = _entityAt(entities, piece.start, piece.end);
        spans.add(
          TextSpan(
            text: widget.text.substring(piece.start, piece.end),
            style: entity == null ? style : style.copyWith(color: mentionColor),
            recognizer: entity == null ? null : _entityRecognizer(entity),
          ),
        );
      }
    }

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}

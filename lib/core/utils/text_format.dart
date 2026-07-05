import 'package:flutter/material.dart';

enum TextFormat {
  strong,
  emphasized,
  underline,
  strikethrough,
  monospaced,
  quote,
  link,
}

const Map<TextFormat, String> _formatToServer = {
  TextFormat.strong: 'STRONG',
  TextFormat.emphasized: 'EMPHASIZED',
  TextFormat.underline: 'UNDERLINE',
  TextFormat.strikethrough: 'STRIKETHROUGH',
  TextFormat.monospaced: 'MONOSPACED',
  TextFormat.quote: 'QUOTE',
  TextFormat.link: 'LINK',
};

final Map<String, TextFormat> _serverToFormat = {
  for (final e in _formatToServer.entries) e.value: e.key,
};

String textFormatToServer(TextFormat format) => _formatToServer[format]!;

TextFormat? textFormatFromServer(String? raw) =>
    raw == null ? null : _serverToFormat[raw];

class FormatRange {
  final TextFormat format;
  final int start;
  final int length;
  final Map<String, dynamic>? attributes;

  const FormatRange({
    required this.format,
    required this.start,
    required this.length,
    this.attributes,
  });

  int get end => start + length;

  String? get url {
    final value = attributes?['url'];
    return value is String ? value : null;
  }

  Map<String, dynamic> toServer() => {
    'type': textFormatToServer(format),
    'from': start,
    'length': length,
    if (attributes != null) 'attributes': attributes,
  };
}

List<FormatRange> parseFormatElements(dynamic raw) {
  if (raw is! List) return const [];
  final result = <FormatRange>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final format = textFormatFromServer(item['type']?.toString());
    if (format == null) continue;
    final from = _asInt(item['from']);
    final length = _asInt(item['length']);
    if (length <= 0) continue;
    final attrsRaw = item['attributes'];
    final attributes = attrsRaw is Map
        ? Map<String, dynamic>.from(attrsRaw)
        : null;
    result.add(
      FormatRange(
        format: format,
        start: from,
        length: length,
        attributes: attributes,
      ),
    );
  }
  return result;
}

List<Map<String, dynamic>> serializeFormatElements(
  Iterable<FormatRange> ranges,
) => [for (final range in ranges) range.toServer()];

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class FormatSegment {
  final int start;
  final int end;
  final Set<TextFormat> formats;
  final String? url;

  const FormatSegment({
    required this.start,
    required this.end,
    required this.formats,
    this.url,
  });
}

List<FormatSegment> segmentizeFormats(String text, List<FormatRange> ranges) {
  if (text.isEmpty) return const [];
  final length = text.length;
  final clamped = <FormatRange>[];
  for (final range in ranges) {
    final start = range.start.clamp(0, length);
    final end = range.end.clamp(0, length);
    if (end <= start) continue;
    clamped.add(
      FormatRange(
        format: range.format,
        start: start,
        length: end - start,
        attributes: range.attributes,
      ),
    );
  }
  if (clamped.isEmpty) {
    return [FormatSegment(start: 0, end: length, formats: const {})];
  }

  final boundaries = <int>{0, length};
  for (final range in clamped) {
    boundaries.add(range.start);
    boundaries.add(range.end);
  }
  final points = boundaries.toList()..sort();

  final segments = <FormatSegment>[];
  for (var i = 0; i < points.length - 1; i++) {
    final start = points[i];
    final end = points[i + 1];
    if (end <= start) continue;
    final formats = <TextFormat>{};
    String? url;
    for (final range in clamped) {
      if (range.start <= start && range.end >= end) {
        formats.add(range.format);
        if (range.format == TextFormat.link) url ??= range.url;
      }
    }
    segments.add(
      FormatSegment(start: start, end: end, formats: formats, url: url),
    );
  }
  return segments;
}

TextStyle applyTextFormats(
  TextStyle base,
  Set<TextFormat> formats, {
  Color? quoteColor,
}) {
  if (formats.isEmpty) return base;

  final decorations = <TextDecoration>[];
  if (formats.contains(TextFormat.underline) ||
      formats.contains(TextFormat.link)) {
    decorations.add(TextDecoration.underline);
  }
  if (formats.contains(TextFormat.strikethrough)) {
    decorations.add(TextDecoration.lineThrough);
  }

  final isItalic = formats.contains(TextFormat.emphasized) ||
      formats.contains(TextFormat.quote);

  return base.copyWith(
    fontWeight: formats.contains(TextFormat.strong) ? FontWeight.w700 : null,
    fontStyle: isItalic ? FontStyle.italic : null,
    fontFamily: formats.contains(TextFormat.monospaced) ? 'monospace' : null,
    color: formats.contains(TextFormat.quote) ? quoteColor : null,
    decoration: decorations.isEmpty
        ? null
        : TextDecoration.combine(decorations),
  );
}

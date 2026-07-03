import 'package:flutter/material.dart';

import '../../core/utils/text_format.dart';

const List<TextFormat> composerFormats = [
  TextFormat.strong,
  TextFormat.emphasized,
  TextFormat.underline,
  TextFormat.strikethrough,
  TextFormat.quote,
];

class _Interval {
  int start;
  int end;
  _Interval(this.start, this.end);
}

class RichMessageController extends TextEditingController {
  final Map<TextFormat, List<_Interval>> _intervals = {};

  RichMessageController({super.text});

  @override
  set value(TextEditingValue newValue) {
    final oldText = value.text;
    final newText = newValue.text;
    if (oldText != newText) {
      _remap(oldText, newText);
    }
    super.value = newValue;
  }

  bool get hasFormatting =>
      _intervals.values.any((list) => list.isNotEmpty);

  void clearFormatting() {
    if (_intervals.isEmpty) return;
    _intervals.clear();
    notifyListeners();
  }

  void setFormatRanges(Iterable<FormatRange> ranges) {
    _intervals.clear();
    for (final range in ranges) {
      if (!composerFormats.contains(range.format)) continue;
      _intervals.putIfAbsent(range.format, () => []).add(
        _Interval(range.start, range.end),
      );
    }
    for (final list in _intervals.values) {
      _normalize(list);
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> elementsForSend() {
    final ranges = <FormatRange>[];
    _intervals.forEach((format, list) {
      for (final interval in list) {
        ranges.add(
          FormatRange(
            format: format,
            start: interval.start,
            length: interval.end - interval.start,
          ),
        );
      }
    });
    return serializeFormatElements(ranges);
  }

  bool isFormatActive(TextFormat format) {
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return false;
    return _isCovered(_intervals[format], selection.start, selection.end);
  }

  void toggleFormat(TextFormat format) {
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final start = selection.start;
    final end = selection.end;
    final list = _intervals.putIfAbsent(format, () => []);
    if (_isCovered(list, start, end)) {
      _subtract(list, start, end);
    } else {
      _add(list, start, end);
    }
    if (list.isEmpty) _intervals.remove(format);
    notifyListeners();
  }

  void _remap(String oldText, String newText) {
    if (_intervals.isEmpty) return;
    final oldLen = oldText.length;
    final newLen = newText.length;

    var prefix = 0;
    final maxPrefix = oldLen < newLen ? oldLen : newLen;
    while (prefix < maxPrefix && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < maxPrefix - prefix &&
        oldText[oldLen - 1 - suffix] == newText[newLen - 1 - suffix]) {
      suffix++;
    }

    final changeStart = prefix;
    final oldChangeEnd = oldLen - suffix;
    final delta = newLen - oldLen;

    int mapStart(int offset) {
      if (offset < changeStart) return offset;
      if (offset >= oldChangeEnd) return offset + delta;
      return changeStart;
    }

    int mapEnd(int offset) {
      if (offset <= changeStart) return offset;
      if (offset >= oldChangeEnd) return offset + delta;
      return changeStart;
    }

    final empty = <TextFormat>[];
    _intervals.forEach((format, list) {
      for (final interval in list) {
        interval.start = mapStart(interval.start);
        interval.end = mapEnd(interval.end);
      }
      list.removeWhere((interval) => interval.end <= interval.start);
      _normalize(list);
      if (list.isEmpty) empty.add(format);
    });
    for (final format in empty) {
      _intervals.remove(format);
    }
  }

  static bool _isCovered(List<_Interval>? list, int start, int end) {
    if (list == null || list.isEmpty) return false;
    var cursor = start;
    final sorted = [...list]..sort((a, b) => a.start.compareTo(b.start));
    for (final interval in sorted) {
      if (interval.start > cursor) return false;
      if (interval.end > cursor) cursor = interval.end;
      if (cursor >= end) return true;
    }
    return cursor >= end;
  }

  static void _add(List<_Interval> list, int start, int end) {
    list.add(_Interval(start, end));
    _normalize(list);
  }

  static void _subtract(List<_Interval> list, int start, int end) {
    final result = <_Interval>[];
    for (final interval in list) {
      if (interval.end <= start || interval.start >= end) {
        result.add(interval);
        continue;
      }
      if (interval.start < start) {
        result.add(_Interval(interval.start, start));
      }
      if (interval.end > end) {
        result.add(_Interval(end, interval.end));
      }
    }
    list
      ..clear()
      ..addAll(result);
    _normalize(list);
  }

  static void _normalize(List<_Interval> list) {
    if (list.length < 2) return;
    list.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_Interval>[list.first];
    for (var i = 1; i < list.length; i++) {
      final current = list[i];
      final last = merged.last;
      if (current.start <= last.end) {
        if (current.end > last.end) last.end = current.end;
      } else {
        merged.add(current);
      }
    }
    list
      ..clear()
      ..addAll(merged);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final content = text;
    if (!hasFormatting || content.isEmpty) {
      return TextSpan(style: baseStyle, text: content);
    }

    final ranges = <FormatRange>[];
    _intervals.forEach((format, list) {
      for (final interval in list) {
        ranges.add(
          FormatRange(
            format: format,
            start: interval.start,
            length: interval.end - interval.start,
          ),
        );
      }
    });

    final baseColor = baseStyle.color;
    final quoteColor = baseColor?.withValues(alpha: 0.85);
    final segments = segmentizeFormats(content, ranges);
    final spans = <InlineSpan>[
      for (final segment in segments)
        TextSpan(
          text: content.substring(segment.start, segment.end),
          style: applyTextFormats(
            baseStyle,
            segment.formats,
            quoteColor: quoteColor,
          ),
        ),
    ];
    return TextSpan(style: baseStyle, children: spans);
  }
}

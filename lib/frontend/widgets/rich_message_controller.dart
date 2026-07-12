import 'package:flutter/material.dart';

import '../../core/utils/text_format.dart';
import '../../models/animoji.dart';
import 'lottie_image.dart';

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

class _AnimojiEntity {
  final int uid;
  int offset;
  final String emoji;
  final String lottieUrl;
  final int entityId;

  _AnimojiEntity({
    required this.uid,
    required this.offset,
    required this.emoji,
    required this.lottieUrl,
    required this.entityId,
  });
}

class RichMessageController extends TextEditingController {
  static const String _animojiPlaceholder = '￼';

  final Map<TextFormat, List<_Interval>> _intervals = {};
  final List<_AnimojiEntity> _animoji = [];
  int _entitySeq = 0;

  RichMessageController({super.text});

  void insertAnimoji(Animoji animoji) {
    final lottie = animoji.lottieUrl ?? animoji.lottiePlayUrl;
    if (lottie == null || lottie.isEmpty) return;

    final selection = value.selection;
    final oldText = value.text;
    final start = selection.isValid ? selection.start : oldText.length;
    final end = selection.isValid ? selection.end : oldText.length;
    final newText = oldText.replaceRange(start, end, _animojiPlaceholder);

    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + _animojiPlaceholder.length,
      ),
    );

    _animoji.add(
      _AnimojiEntity(
        uid: _entitySeq++,
        offset: start,
        emoji: animoji.emoji,
        lottieUrl: lottie,
        entityId: animoji.id,
      ),
    );
    _animoji.sort((a, b) => a.offset.compareTo(b.offset));
    notifyListeners();
  }

  ({String text, List<Map<String, dynamic>> elements}) buildContent() {
    final src = value.text;
    if (_animoji.isEmpty) {
      return (text: src, elements: elementsForSend());
    }

    final entities = [..._animoji]..sort((a, b) => a.offset.compareTo(b.offset));

    final sb = StringBuffer();
    var last = 0;
    for (final e in entities) {
      if (e.offset < last || e.offset >= src.length) continue;
      sb.write(src.substring(last, e.offset));
      sb.write(e.emoji);
      last = e.offset + _animojiPlaceholder.length;
    }
    sb.write(src.substring(last));
    final glyphText = sb.toString();

    int glyphOffset(int p) {
      var shift = 0;
      for (final e in entities) {
        if (e.offset < p && e.offset < src.length) {
          shift += e.emoji.length - _animojiPlaceholder.length;
        }
      }
      return p + shift;
    }

    final elements = <Map<String, dynamic>>[];
    for (final e in entities) {
      if (e.offset >= src.length) continue;
      elements.add({
        'type': 'ANIMOJI',
        'from': glyphOffset(e.offset),
        'length': e.emoji.length,
        'entityId': e.entityId,
        'attributes': {'animojiLottieUrl': e.lottieUrl},
      });
    }
    for (final range in _toFormatRanges()) {
      final from = glyphOffset(range.start);
      final to = glyphOffset(range.end);
      if (to <= from) continue;
      elements.add({
        'type': textFormatToServer(range.format),
        'from': from,
        'length': to - from,
      });
    }
    return (text: glyphText, elements: elements);
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = value.text;
    final newText = newValue.text;
    if (oldText != newText) {
      _remap(oldText, newText);
    }
    super.value = newValue;
  }

  bool get hasFormatting => _intervals.values.any((list) => list.isNotEmpty);

  void clearFormatting() {
    if (_intervals.isEmpty) return;
    _intervals.clear();
    notifyListeners();
  }

  void setFormatRanges(Iterable<FormatRange> ranges) {
    _intervals.clear();
    for (final range in ranges) {
      if (!composerFormats.contains(range.format)) continue;
      _intervals
          .putIfAbsent(range.format, () => [])
          .add(_Interval(range.start, range.end));
    }
    for (final list in _intervals.values) {
      _normalize(list);
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> elementsForSend() {
    return serializeFormatElements(_toFormatRanges());
  }

  List<FormatRange> _toFormatRanges() {
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
    return ranges;
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
    if (_intervals.isEmpty && _animoji.isEmpty) return;
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

    if (_animoji.isNotEmpty) {
      _animoji.removeWhere(
        (e) => e.offset >= changeStart && e.offset < oldChangeEnd,
      );
      for (final e in _animoji) {
        if (e.offset >= oldChangeEnd) e.offset += delta;
      }
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
    if ((!hasFormatting && _animoji.isEmpty) || content.isEmpty) {
      return TextSpan(style: baseStyle, text: content);
    }

    final ranges = _toFormatRanges();
    final baseColor = baseStyle.color;
    final quoteColor = baseColor?.withValues(alpha: 0.85);
    final segments = segmentizeFormats(content, ranges);
    final entityByOffset = {for (final e in _animoji) e.offset: e};
    final box = (baseStyle.fontSize ?? 16) * 1.4;

    final spans = <InlineSpan>[];
    for (final segment in segments) {
      final segStyle = applyTextFormats(
        baseStyle,
        segment.formats,
        quoteColor: quoteColor,
      );
      var runStart = segment.start;
      var i = segment.start;
      while (i < segment.end) {
        final entity = entityByOffset[i];
        if (entity == null) {
          i++;
          continue;
        }
        if (runStart < i) {
          spans.add(
            TextSpan(text: content.substring(runStart, i), style: segStyle),
          );
        }
        spans.add(_animojiSpan(entity, box));
        i += _animojiPlaceholder.length;
        runStart = i;
      }
      if (runStart < segment.end) {
        spans.add(
          TextSpan(
            text: content.substring(runStart, segment.end),
            style: segStyle,
          ),
        );
      }
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  WidgetSpan _animojiSpan(_AnimojiEntity entity, double box) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SizedBox(
        key: ValueKey('composer-animoji-${entity.uid}'),
        width: box,
        height: box,
        child: LottieImage(
          lottieUrl: entity.lottieUrl,
          size: box,
          memCacheWidth: 120,
        ),
      ),
    );
  }
}

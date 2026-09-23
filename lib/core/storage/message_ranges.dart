import 'dart:math' as math;

class MessageRange {
  const MessageRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int time) => start <= time && time <= end;

  bool touches(MessageRange other) => start <= other.end && other.start <= end;

  MessageRange union(MessageRange other) =>
      MessageRange(math.min(start, other.start), math.max(end, other.end));

  @override
  bool operator ==(Object other) =>
      other is MessageRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MessageRange($start, $end)';
}

class MessageRanges {
  MessageRanges(Iterable<MessageRange> ranges)
    : ranges = List.unmodifiable(
        [...ranges]..sort((a, b) => a.start.compareTo(b.start)),
      );

  static final MessageRanges none = MessageRanges(const []);

  final List<MessageRange> ranges;

  bool get isEmpty => ranges.isEmpty;

  MessageRange? at(int time) {
    for (final range in ranges) {
      if (range.contains(time)) return range;
    }
    return null;
  }

  MessageRange? get newest => ranges.isEmpty ? null : ranges.last;

  static List<MessageRange> merge(
    List<MessageRange> existing,
    MessageRange added,
  ) {
    var merged = added;
    final kept = <MessageRange>[];
    for (final range in existing) {
      if (range.touches(merged)) {
        merged = merged.union(range);
      } else {
        kept.add(range);
      }
    }
    return [...kept, merged]..sort((a, b) => a.start.compareTo(b.start));
  }

  static MessageRange? coverageOfFetch({
    required int? fromTime,
    required int forward,
    required int backward,
    required List<int> times,
  }) {
    if (times.isEmpty && fromTime == null) return null;
    final from = fromTime;
    final oldest = times.isEmpty ? from! : times.reduce(math.min);
    final newest = times.isEmpty ? from! : times.reduce(math.max);

    var start = oldest;
    if (backward > 0) {
      final older = from == null
          ? times.length
          : times.where((t) => t <= from).length;
      if (older < backward) start = 0;
    } else if (from != null) {
      start = math.min(oldest, from);
    }

    var end = newest;
    if (forward <= 0 && from != null) end = math.max(newest, from);

    return MessageRange(start, end);
  }

  List<T> clipOlder<T>(
    List<T> olderDesc,
    int edgeTime,
    int Function(T) timeOf,
  ) {
    final range = at(edgeTime);
    if (range == null) return const [];
    return [
      for (final item in olderDesc)
        if (timeOf(item) >= range.start) item,
    ];
  }

  List<T> clipNewer<T>(List<T> newerAsc, int edgeTime, int Function(T) timeOf) {
    final range = at(edgeTime);
    if (range == null) return const [];
    return [
      for (final item in newerAsc)
        if (timeOf(item) <= range.end) item,
    ];
  }

  bool coversOlderPage({
    required int edgeTime,
    required List<int> pageTimes,
    required int limit,
  }) {
    final range = at(edgeTime);
    if (range == null) return false;
    if (pageTimes.any((t) => t < range.start)) return false;
    return pageTimes.length >= limit || range.start == 0;
  }

  bool coversNewerPage({
    required int edgeTime,
    required List<int> pageTimes,
    required int limit,
    required int? newestKnownTime,
  }) {
    final range = at(edgeTime);
    if (range == null) return false;
    if (pageTimes.any((t) => t > range.end)) return false;
    if (pageTimes.length >= limit) return true;
    return newestKnownTime != null && range.end >= newestKnownTime;
  }

  bool coversWindow({
    required int centerTime,
    required List<int> windowTimes,
    required int before,
    required int after,
    required int? newestKnownTime,
  }) {
    final range = at(centerTime);
    if (range == null) return false;
    if (windowTimes.any((t) => !range.contains(t))) return false;
    final older = windowTimes.where((t) => t <= centerTime).length;
    final newer = windowTimes.length - older;
    final olderComplete = older >= before || range.start == 0;
    final newerComplete =
        newer >= after ||
        (newestKnownTime != null && range.end >= newestKnownTime);
    return olderComplete && newerComplete;
  }

  List<T> clipAround<T>(List<T> items, int centerTime, int Function(T) timeOf) {
    final range = at(centerTime);
    if (range == null) return items;
    return [
      for (final item in items)
        if (range.contains(timeOf(item))) item,
    ];
  }

  List<T> clipLatest<T>(List<T> latest, int Function(T) timeOf) {
    final range = newest;
    if (range == null) return latest;
    return [
      for (final item in latest)
        if (timeOf(item) >= range.start) item,
    ];
  }

  bool coversNewest(int newestTime) {
    final range = newest;
    return range != null && range.end >= newestTime;
  }
}

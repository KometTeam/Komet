class ReactionCounter {
  final String reaction;
  final int count;
  const ReactionCounter({required this.reaction, required this.count});
}

class ReactionInfo {
  final List<ReactionCounter> counters;
  final String? yourReaction;
  final int totalCount;

  const ReactionInfo({
    this.counters = const [],
    this.yourReaction,
    this.totalCount = 0,
  });

  static ReactionInfo? fromMap(Map? map) {
    if (map == null) return null;
    final rawCounters = map['counters'];
    if (rawCounters is! List || rawCounters.isEmpty) return null;
    final counters = <ReactionCounter>[];
    for (final c in rawCounters) {
      if (c is! Map) continue;
      final reaction = c['reaction']?.toString();
      if (reaction == null || reaction.isEmpty) continue;
      final rawCount = c['count'];
      counters.add(
        ReactionCounter(
          reaction: reaction,
          count: rawCount is int ? rawCount : 0,
        ),
      );
    }
    if (counters.isEmpty) return null;
    final total = map['totalCount'];
    return ReactionInfo(
      counters: counters,
      yourReaction: map['yourReaction']?.toString(),
      totalCount: total is int ? total : 0,
    );
  }

  bool get isEmpty => counters.isEmpty;
}

class PollAnswer {
  final int answerId;
  final String text;
  final int voteCount;
  final double rate;
  final List<int> votes;

  const PollAnswer({
    required this.answerId,
    required this.text,
    this.voteCount = 0,
    this.rate = 0,
    this.votes = const [],
  });
}

class Poll {
  final int pollId;
  final String title;
  final int settings;
  final int version;
  final int total;
  final List<PollAnswer> answers;
  final List<int> voterPreviewIds;

  const Poll({
    required this.pollId,
    required this.title,
    this.settings = 0,
    this.version = 0,
    this.total = 0,
    this.answers = const [],
    this.voterPreviewIds = const [],
  });

  bool get isMultiple => settings & 0x1 != 0;

  bool votedBy(int userId) =>
      answers.any((a) => a.votes.contains(userId));

  factory Poll.fromServerMap(Map<dynamic, dynamic> map) {
    final state = map['state'];
    final stateMap = state is Map ? state : const {};

    final resultsById = <int, Map>{};
    final result = stateMap['result'];
    if (result is List) {
      for (final r in result) {
        if (r is Map && r['answerId'] is int) {
          resultsById[r['answerId'] as int] = r;
        }
      }
    }

    final answers = <PollAnswer>[];
    final rawAnswers = map['answers'];
    if (rawAnswers is List) {
      for (final a in rawAnswers) {
        if (a is! Map) continue;
        final id = a['answerId'] as int? ?? 0;
        final res = resultsById[id];
        answers.add(PollAnswer(
          answerId: id,
          text: a['text']?.toString() ?? '',
          voteCount: (res?['voteCount'] as num?)?.toInt() ?? 0,
          rate: (res?['rate'] as num?)?.toDouble() ?? 0,
          votes: (res?['votes'] as List?)
                  ?.whereType<int>()
                  .toList() ??
              const [],
        ));
      }
    }

    return Poll(
      pollId: map['pollId'] as int? ?? 0,
      title: map['title']?.toString() ?? '',
      settings: map['settings'] as int? ?? 0,
      version: map['version'] as int? ?? 0,
      total: (stateMap['total'] as num?)?.toInt() ?? 0,
      answers: answers,
      voterPreviewIds:
          (stateMap['voterPreviewIds'] as List?)?.whereType<int>().toList() ??
              const [],
    );
  }
}

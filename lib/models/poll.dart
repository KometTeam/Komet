class PollAnswer {
  final int answerId;
  final String text;
  final int voteCount;
  final double rate;
  final List<int> votes;
  final bool mine;

  const PollAnswer({
    required this.answerId,
    required this.text,
    this.voteCount = 0,
    this.rate = 0,
    this.votes = const [],
    this.mine = false,
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

  bool get hasMyVote => answers.any((a) => a.mine);

  bool votedBy(int userId) =>
      answers.any((a) => a.mine || a.votes.contains(userId));

  static List<int> _parseVoterIds(dynamic votes) {
    if (votes is! List) return const [];
    final ids = <int>[];
    for (final v in votes) {
      if (v is int) {
        ids.add(v);
      } else if (v is Map && v['userId'] is int) {
        ids.add(v['userId'] as int);
      }
    }
    return ids;
  }

  Poll withStateMap(Map<dynamic, dynamic> stateMap) {
    return _buildFromState(
      pollId: pollId,
      title: title,
      settings: settings,
      version: version,
      answerIdsAndTexts: [for (final a in answers) (a.answerId, a.text)],
      stateMap: stateMap,
    );
  }

  factory Poll.fromServerMap(Map<dynamic, dynamic> map) {
    final state = map['state'];
    final stateMap = state is Map ? state : const {};

    final answerIdsAndTexts = <(int, String)>[];
    final rawAnswers = map['answers'];
    if (rawAnswers is List) {
      for (final a in rawAnswers) {
        if (a is! Map) continue;
        answerIdsAndTexts.add((
          a['answerId'] as int? ?? 0,
          a['text']?.toString() ?? '',
        ));
      }
    }

    return _buildFromState(
      pollId: map['pollId'] as int? ?? 0,
      title: map['title']?.toString() ?? '',
      settings: map['settings'] as int? ?? 0,
      version: map['version'] as int? ?? 0,
      answerIdsAndTexts: answerIdsAndTexts,
      stateMap: stateMap,
    );
  }

  static Poll _buildFromState({
    required int pollId,
    required String title,
    required int settings,
    required int version,
    required List<(int, String)> answerIdsAndTexts,
    required Map<dynamic, dynamic> stateMap,
  }) {
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
    for (final (id, text) in answerIdsAndTexts) {
      final res = resultsById[id];
      answers.add(
        PollAnswer(
          answerId: id,
          text: text,
          voteCount: (res?['voteCount'] as num?)?.toInt() ?? 0,
          rate: (res?['rate'] as num?)?.toDouble() ?? 0,
          votes: _parseVoterIds(res?['votes']),
          mine: ((res?['options'] as num?)?.toInt() ?? 0) & 0x1 != 0,
        ),
      );
    }

    return Poll(
      pollId: pollId,
      title: title,
      settings: settings,
      version: version,
      total: (stateMap['total'] as num?)?.toInt() ?? 0,
      answers: answers,
      voterPreviewIds:
          (stateMap['voterPreviewIds'] as List?)?.whereType<int>().toList() ??
          const [],
    );
  }
}

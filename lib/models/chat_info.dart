class ChatInfo {
  final Map<String, dynamic> raw;
  final List<int> participantIds;
  final Set<int> adminIds;
  final int? owner;

  const ChatInfo({
    required this.raw,
    required this.participantIds,
    required this.adminIds,
    required this.owner,
  });

  factory ChatInfo.fromMap(Map<String, dynamic> map) {
    return ChatInfo(
      raw: map,
      participantIds: _idKeys(map['participants']),
      adminIds: _idKeys(map['adminParticipants']).toSet(),
      owner: map['owner'] as int?,
    );
  }

  bool isAdmin(int id) => adminIds.contains(id);
  bool isOwner(int id) => owner != null && id == owner;

  int? get participantsCount => raw['participantsCount'] as int?;
  int? get blockedParticipantsCount => raw['blockedParticipantsCount'] as int?;
  String? get link => raw['link'] as String?;
  String? get description => raw['description'] as String?;

  static List<int> _idKeys(Object? source) {
    if (source is! Map) return const [];
    final out = <int>[];
    for (final key in source.keys) {
      final id = key is int ? key : int.tryParse(key.toString());
      if (id != null) out.add(id);
    }
    return out;
  }
}

import 'admin_rights.dart';

// #***! расширенная карточка чата
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

  // #***! участники приходят картой, нам чаще нужны id
  factory ChatInfo.fromMap(Map<String, dynamic> map) {
    return ChatInfo(
      raw: map,
      participantIds: _idKeys(map['participants']),
      adminIds: _idKeys(map['adminParticipants']).toSet(),
      owner: map['owner'] as int?,
    );
  }

  // #***! админ или владелец
  bool isAdmin(int id) => adminIds.contains(id);
  bool isOwner(int id) => owner != null && id == owner;

  // #***! булев флаг из options
  bool option(String name) {
    final opts = raw['options'];
    return opts is Map && opts[name] == true;
  }

  // #***! ссылку видят админы или все если настроено
  bool canSeeInviteLink(int id) =>
      isAdmin(id) || isOwner(id) || option('MEMBERS_CAN_SEE_PRIVATE_LINK');

  bool get isPublic => raw['access'] == 'PUBLIC';

  bool canSeeLink(int id) => isPublic || canSeeInviteLink(id);

  // #***! у админа бывает подпись должность
  String? adminAlias(int id) {
    final entry = _adminEntry(id);
    if (entry == null) return null;
    final alias = entry['alias'];
    if (alias is String && alias.trim().isNotEmpty) return alias.trim();
    return null;
  }

  AdminRights rightsOf(int id) {
    if (isOwner(id)) {
      return const AdminRights(AdminRights.ownerBits);
    }
    final permissions = _adminEntry(id)?['permissions'];
    return AdminRights(permissions is int ? permissions : 0);
  }

  bool can(int id, AdminRight right) =>
      isOwner(id) || (isAdmin(id) && rightsOf(id).has(right));

  Map<dynamic, dynamic>? _adminEntry(int id) {
    final source = raw['adminParticipants'];
    if (source is! Map) return null;
    final entry = source[id.toString()] ?? source[id];
    return entry is Map ? entry : null;
  }

  int? get participantsCount => raw['participantsCount'] as int?;
  int? get blockedParticipantsCount => raw['blockedParticipantsCount'] as int?;
  // #***! счётчик заявок на вступление, приходит в объекте чата
  int get pendingJoinRequestsCount =>
      (raw['pendingJoinRequestsCount'] as int?) ?? 0;
  String? get link => raw['link'] as String?;
  bool get joinRequests => option('JOIN_REQUEST');
  bool get commentsEnabled => option('COMMENTS');
  String? get title => raw['title'] as String?;
  String? get iconUrl => raw['baseIconUrl'] as String?;
  AdminChatKind get adminKind =>
      raw['type'] == 'CHANNEL' ? AdminChatKind.channel : AdminChatKind.group;
  String? get description => raw['description'] as String?;

  // #***! ключи то int то строка, приводим к int
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

import 'per_chat_json_store.dart';

class GhostRead {
  final int mark;
  final int serverUnread;
  final int serverOwnMark;
  final int baseUnread;
  final int left;

  const GhostRead({
    required this.mark,
    required this.serverUnread,
    required this.serverOwnMark,
    required this.baseUnread,
    required this.left,
  });

  int unreadFor(int serverUnread, {int? lastMessageTime}) {
    if (lastMessageTime != null && lastMessageTime <= mark) return 0;
    return (serverUnread - baseUnread + left).clamp(0, serverUnread);
  }

  GhostRead withServer({int? unread, int? ownMark}) => GhostRead(
    mark: mark,
    serverUnread: unread ?? serverUnread,
    serverOwnMark: ownMark ?? serverOwnMark,
    baseUnread: baseUnread,
    left: left,
  );
}

class GhostReadStore extends PerChatJsonStore<GhostRead> {
  GhostReadStore._()
    : super(
        prefsKey: 'ghost_reads',
        fromJson: _fromJson,
        toJson: (value) => {
          'mark': value.mark,
          'unread': value.serverUnread,
          'ownMark': value.serverOwnMark,
          'base': value.baseUnread,
          'left': value.left,
        },
      );

  static final GhostReadStore instance = GhostReadStore._();

  static GhostRead? _fromJson(Object? raw) {
    if (raw is! Map) return null;
    final mark = raw['mark'];
    final unread = raw['unread'];
    final ownMark = raw['ownMark'];
    if (mark is! int || unread is! int || ownMark is! int) return null;
    final base = raw['base'];
    final left = raw['left'];
    return GhostRead(
      mark: mark,
      serverUnread: unread,
      serverOwnMark: ownMark,
      baseUnread: base is int ? base : unread,
      left: left is int ? left : 0,
    );
  }

  GhostRead? of(int accountId, int chatId) => read(accountId, chatId);

  Future<void> noteLocalRead(
    int accountId,
    int chatId, {
    required int mark,
    required int left,
    required int serverUnread,
    required int serverOwnMark,
  }) {
    final prev = read(accountId, chatId);
    final known = prev?.serverUnread ?? serverUnread;
    return write(
      accountId,
      chatId,
      GhostRead(
        mark: prev == null || mark > prev.mark ? mark : prev.mark,
        serverUnread: known,
        serverOwnMark: prev?.serverOwnMark ?? serverOwnMark,
        baseUnread: known,
        left: left,
      ),
    );
  }

  Future<void> noteServer(
    int accountId,
    int chatId, {
    int? unread,
    int? ownMark,
  }) {
    final prev = read(accountId, chatId);
    if (prev == null) return Future.value();
    if ((unread == null || unread == prev.serverUnread) &&
        (ownMark == null || ownMark == prev.serverOwnMark)) {
      return Future.value();
    }
    return write(
      accountId,
      chatId,
      prev.withServer(unread: unread, ownMark: ownMark),
    );
  }

  Future<void> forget(int accountId, int chatId) =>
      write(accountId, chatId, null);

  List<({int accountId, int chatId, GhostRead read})> snapshot() {
    final out = <({int accountId, int chatId, GhostRead read})>[];
    for (final entry in allEntries) {
      final parts = entry.key.split('/');
      if (parts.length != 2) continue;
      final accountId = int.tryParse(parts[0]);
      final chatId = int.tryParse(parts[1]);
      if (accountId == null || chatId == null) continue;
      out.add((accountId: accountId, chatId: chatId, read: entry.value));
    }
    return out;
  }
}

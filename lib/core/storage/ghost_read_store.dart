import 'per_chat_json_store.dart';

class GhostRead {
  final int mark;
  final int unread;
  final int ownMark;

  const GhostRead({required this.mark, required this.unread, required this.ownMark});
}

class GhostReadStore extends PerChatJsonStore<GhostRead> {
  GhostReadStore._()
    : super(
        prefsKey: 'ghost_reads',
        fromJson: _fromJson,
        toJson: (value) => {
          'mark': value.mark,
          'unread': value.unread,
          'ownMark': value.ownMark,
        },
      );

  static final GhostReadStore instance = GhostReadStore._();

  static GhostRead? _fromJson(Object? raw) {
    if (raw is! Map) return null;
    final mark = raw['mark'];
    final unread = raw['unread'];
    final ownMark = raw['ownMark'];
    if (mark is! int || unread is! int || ownMark is! int) return null;
    return GhostRead(mark: mark, unread: unread, ownMark: ownMark);
  }

  Future<void> remember(
    int accountId,
    int chatId, {
    required int mark,
    required int unread,
    required int ownMark,
  }) {
    final prev = read(accountId, chatId);
    return write(
      accountId,
      chatId,
      GhostRead(
        mark: mark,
        unread: prev?.unread ?? unread,
        ownMark: prev?.ownMark ?? ownMark,
      ),
    );
  }

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

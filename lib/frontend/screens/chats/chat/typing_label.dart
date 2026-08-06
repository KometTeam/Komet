import '../../../../backend/modules/messages.dart';
import '../../../../core/storage/chat_activity_store.dart';

String chatActivityLabel(
  ChatActivitySnapshot snapshot, {
  bool withNames = false,
}) {
  if (!withNames) return snapshot.activity.label;

  final names = <String>[];
  for (final id in snapshot.userIds) {
    final name = ContactCache.get(id);
    if (name == null || name.trim().isEmpty) continue;
    names.add(_shortName(name));
  }
  if (names.isEmpty) return snapshot.activity.label;

  final many = names.length > 1;
  final verb = switch (snapshot.activity) {
    ChatActivity.typing => many ? 'печатают' : 'печатает',
    ChatActivity.sticker => many ? 'выбирают стикеры' : 'выбирает стикер',
  };
  if (!many) return '${names.first} $verb...';
  if (names.length == 2) return '${names[0]} и ${names[1]} $verb...';
  return '${names[0]} и ещё ${names.length - 1} $verb...';
}

String _shortName(String name) {
  final trimmed = name.trim();
  final space = trimmed.indexOf(' ');
  return space > 0 ? trimmed.substring(0, space) : trimmed;
}

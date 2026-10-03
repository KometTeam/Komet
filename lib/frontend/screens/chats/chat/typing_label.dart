import '../../../../backend/modules/messages.dart';
import '../../../../core/storage/chat_activity_store.dart';
import '../../../../l10n/app_localizations.dart';

extension ChatActivityLabel on ChatActivity {
  String label(AppLocalizations l10n) => switch (this) {
    ChatActivity.typing => l10n.chatActivityTyping,
    ChatActivity.sticker => l10n.chatActivityChoosingSticker,
  };
}

String chatActivityLabel(
  AppLocalizations l10n,
  ChatActivitySnapshot snapshot, {
  bool withNames = false,
}) {
  final plain = snapshot.activity.label(l10n);
  if (!withNames) return plain;

  final names = <String>[];
  for (final id in snapshot.userIds) {
    final name = ContactCache.get(id);
    if (name == null || name.trim().isEmpty) continue;
    names.add(_shortName(name));
  }
  if (names.isEmpty) return plain;

  return switch (snapshot.activity) {
    ChatActivity.typing => switch (names.length) {
      1 => l10n.chatActivityTypingOne(names[0]),
      2 => l10n.chatActivityTypingTwo(names[0], names[1]),
      _ => l10n.chatActivityTypingMany(names[0], names.length - 1),
    },
    ChatActivity.sticker => switch (names.length) {
      1 => l10n.chatActivityStickerOne(names[0]),
      2 => l10n.chatActivityStickerTwo(names[0], names[1]),
      _ => l10n.chatActivityStickerMany(names[0], names.length - 1),
    },
  };
}

String _shortName(String name) {
  final trimmed = name.trim();
  final space = trimmed.indexOf(' ');
  return space > 0 ? trimmed.substring(0, space) : trimmed;
}

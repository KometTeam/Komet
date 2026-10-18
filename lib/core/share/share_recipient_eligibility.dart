import 'share_account_snapshot.dart';

String? shareRecipientDisabledReason({
  required bool requiresEncryption,
  required bool isChannel,
  required bool canPostToChannel,
}) {
  if (requiresEncryption) {
    return 'Зашифрованный чат — отправляйте из Komet';
  }
  if (isChannel && !canPostToChannel) {
    return 'Нет права отправлять сообщения в этот канал';
  }
  return null;
}

List<ShareRecipientSnapshot> withStoryRecipient({
  required List<ShareRecipientSnapshot> recipients,
  required bool storiesEnabled,
}) {
  if (!storiesEnabled) return recipients;
  return [
    ...recipients,
    const ShareRecipientSnapshot(id: -1, title: 'Сторис', type: 'STORY'),
  ];
}

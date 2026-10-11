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

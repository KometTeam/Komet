import '../crypto/e2ee_service.dart';

String? shareRecipientDisabledReason({
  required bool legacyEncryptionEnabled,
  required E2eePhase e2eePhase,
  required bool isChannel,
  required bool canPostToChannel,
}) {
  if (legacyEncryptionEnabled || e2eePhase != E2eePhase.none) {
    return 'Зашифрованный чат — отправляйте из Komet';
  }
  if (isChannel && !canPostToChannel) {
    return 'Нет права отправлять сообщения в этот канал';
  }
  return null;
}

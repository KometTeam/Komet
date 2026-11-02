import '../storage/chat_encryption_store.dart';
import 'e2ee_service.dart';

class UnencryptedSendException implements Exception {
  const UnencryptedSendException();
  @override
  String toString() =>
      'Этот способ отправки не поддерживает шифрование. Откройте чат и отправьте сообщение из него.';
}

class OutgoingMessagePolicy {
  OutgoingMessagePolicy._();

  static const List<String> _encryptionControlPrefixes = [
    kE2eeOfferPrefix,
    kE2eeAnswerPrefix,
    kE2eeOfferDonePrefix,
  ];

  static bool requiresEncryption(int accountId, int chatId) =>
      ChatEncryptionStore.instance.isEnabled(accountId, chatId) ||
      E2eeService.instance.isActive(accountId, chatId);

  static bool isEncryptionControl(String text) =>
      _encryptionControlPrefixes.any(text.startsWith);

  static Future<void> load(int accountId) async {
    await ChatEncryptionStore.instance.load();
    await E2eeService.instance.ensureLoaded(accountId);
  }

  static void requireSupported(
    int accountId,
    int chatId, {
    bool encryptedPayload = false,
  }) {
    if (!encryptedPayload && requiresEncryption(accountId, chatId)) {
      throw const UnencryptedSendException();
    }
  }
}

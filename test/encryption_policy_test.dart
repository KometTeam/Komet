import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/crypto/encryption_policy.dart';

void main() {
  test('channels never allow encryption', () {
    expect(chatAllowsEncryption(chatType: 'CHANNEL'), isFalse);
    expect(chatAllowsEncryption(chatType: 'CHANNEL', peerIsBot: true), isFalse);
  });

  test('dialogs with bots do not allow encryption', () {
    expect(chatAllowsEncryption(chatType: 'DIALOG', peerIsBot: true), isFalse);
  });

  test('dialogs with people and group chats keep encryption', () {
    expect(chatAllowsEncryption(chatType: 'DIALOG'), isTrue);
    expect(chatAllowsEncryption(chatType: 'CHAT'), isTrue);
  });
}

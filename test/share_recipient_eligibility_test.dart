import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/crypto/e2ee_service.dart';
import 'package:komet/core/share/share_account_snapshot.dart';
import 'package:komet/core/share/share_recipient_eligibility.dart';

String? _reason({
  E2eePhase e2ee = E2eePhase.none,
  bool legacy = false,
  bool channel = false,
  bool canPost = false,
}) => shareRecipientDisabledReason(
  legacyEncryptionEnabled: legacy,
  e2eePhase: e2ee,
  isChannel: channel,
  canPostToChannel: canPost,
);

void main() {
  for (final phase in E2eePhase.values.where(
    (phase) => phase != E2eePhase.none,
  )) {
    test(
      'native share prevents plaintext sending while E2EE is ${phase.name}',
      () {
        final reason = _reason(e2ee: phase);
        expect(reason, isNotNull);
        final recipient = ShareRecipientSnapshot(
          id: 202,
          title: 'Synthetic encrypted chat',
          type: 'DIALOG',
          disabledReason: reason,
        );
        final exported = jsonDecode(jsonEncode(recipient.toMap())) as Map;
        expect(exported['disabledReason'], reason);
      },
    );
  }

  test('legacy encrypted chats remain blocked without an E2EE session', () {
    expect(_reason(legacy: true), _reason(e2ee: E2eePhase.established));
    expect(_reason(legacy: true, channel: true, canPost: true), isNotNull);
  });

  test('ordinary dialogs and writable channels remain available', () {
    expect(_reason(), isNull);
    expect(_reason(channel: true, canPost: true), isNull);
    expect(_reason(channel: true), isNotNull);
  });
}

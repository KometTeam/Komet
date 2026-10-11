import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/share/share_account_snapshot.dart';
import 'package:komet/core/share/share_recipient_eligibility.dart';

String? _reason({
  bool encrypted = false,
  bool channel = false,
  bool canPost = false,
}) => shareRecipientDisabledReason(
  requiresEncryption: encrypted,
  isChannel: channel,
  canPostToChannel: canPost,
);

void main() {
  test('native share prevents plaintext sending into encrypted chats', () {
    final reason = _reason(encrypted: true);
    expect(reason, isNotNull);
    final recipient = ShareRecipientSnapshot(
      id: 202,
      title: 'Synthetic encrypted chat',
      type: 'DIALOG',
      disabledReason: reason,
    );
    final exported = jsonDecode(jsonEncode(recipient.toMap())) as Map;
    expect(exported['disabledReason'], reason);
  });

  test('encrypted writable channels remain blocked', () {
    expect(_reason(encrypted: true, channel: true, canPost: true), isNotNull);
  });

  test('ordinary dialogs and writable channels remain available', () {
    expect(_reason(), isNull);
    expect(_reason(channel: true, canPost: true), isNull);
    expect(_reason(channel: true), isNotNull);
  });
}

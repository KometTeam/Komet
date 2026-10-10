import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/protocol/chat_cache_fingerprint.dart';
import 'package:komet/core/share/share_account_snapshot.dart';

void main() {
  final vectors =
      jsonDecode(
            File(
              'test/fixtures/share_fingerprint_vectors.json',
            ).readAsStringSync(),
          )
          as List<dynamic>;

  for (final raw in vectors) {
    final vector = raw as Map<String, dynamic>;
    test(
      'native share fingerprint matches ${vector['arch']} preLogin=${vector['pre_login']}',
      () {
        final arch = vector['arch'] as String;
        final preLogin = vector['pre_login'] as bool;
        final digests = ChatCacheFingerprint.exportDigests(
          arch: arch,
          preLogin: preLogin,
        );
        expect(digests, vector['digests']);
        final computed = ChatCacheFingerprint.compute(
          vector['seed'] as int,
          vector['device_id'] as String,
          arch: arch,
          preLogin: preLogin,
        );
        expect(
          computed.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
          vector['fingerprint'],
        );
        final snapshot = ShareAccountSnapshot(
          accountId: 101,
          accountName: 'Synthetic Account',
          token: 'synthetic-token',
          session: {'fingerprint_digests': digests, 'arch': arch},
          login: {'chatCacheFingerprint': computed},
          chats: const [],
        );
        final exported = jsonDecode(jsonEncode(snapshot.toMap())) as Map;
        expect(
          (exported['session'] as Map)['fingerprint_digests'],
          vector['digests'],
        );
        expect(
          (exported['login'] as Map).containsKey('chatCacheFingerprint'),
          isFalse,
        );
      },
    );
  }
}

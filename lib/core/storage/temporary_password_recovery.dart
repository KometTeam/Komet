import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'token_storage.dart';

class TemporaryPasswordRecovery {
  const TemporaryPasswordRecovery({
    required this.accountId,
    required this.operationId,
    required this.password,
  });

  static final Map<int, Future<void>> _pending = {};

  static Future<T> _serialized<T>(int accountId, Future<T> Function() action) {
    final next = (_pending[accountId] ?? Future<void>.value()).then(
      (_) => action(),
    );
    final settled = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending[accountId] = settled;
    unawaited(
      settled.whenComplete(() {
        if (identical(_pending[accountId], settled)) _pending.remove(accountId);
      }),
    );
    return next;
  }

  final int accountId;
  final String operationId;
  final String password;

  static String _key(int accountId) => 'temporary_2fa_recovery_$accountId';

  static Future<TemporaryPasswordRecovery?> read(int accountId) async {
    final raw = await TokenStorage.readSecure(_key(accountId));
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['accountId'] != accountId) {
      throw const FormatException('Invalid recovery account');
    }
    return TemporaryPasswordRecovery(
      accountId: accountId,
      operationId: data['operationId'] as String,
      password: data['password'] as String,
    );
  }

  static Future<TemporaryPasswordRecovery> save(
    int accountId,
    String password,
  ) => _serialized(accountId, () async {
    if (await read(accountId) != null) {
      throw StateError(
        'Сначала восстановите прежний временный пароль в настройках безопасности',
      );
    }
    final random = Random.secure();
    final operationId = base64UrlEncode(
      List<int>.generate(24, (_) => random.nextInt(256)),
    );
    final recovery = TemporaryPasswordRecovery(
      accountId: accountId,
      operationId: operationId,
      password: password,
    );
    await TokenStorage.writeSecure(
      _key(accountId),
      jsonEncode({
        'accountId': accountId,
        'operationId': operationId,
        'password': password,
      }),
    );
    return recovery;
  });

  Future<void> clearAfterRollback() => _serialized(accountId, () async {
    if ((await read(accountId))?.operationId == operationId) {
      await TokenStorage.deleteSecure(_key(accountId));
    }
  });
}

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../utils/logger.dart';
import 'share_account_snapshot.dart';

class NativeShareAccountChannel {
  NativeShareAccountChannel({
    this.channel = const MethodChannel('ru.komet.app/share'),
    bool? enabled,
  }) : enabled = enabled ?? (!kIsWeb && Platform.isIOS);

  static final instance = NativeShareAccountChannel();

  final MethodChannel channel;
  final bool enabled;
  final Map<int, int> _generations = {};
  Future<void> _tail = Future.value();

  int generation(int accountId) => _generations[accountId] ?? 0;

  Future<String?> renewedToken(int accountId, String knownToken) async {
    if (!enabled) return null;
    try {
      return await channel.invokeMethod<String>('readShareToken', {
        'accountId': accountId.toString(),
        'knownToken': knownToken,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> publish(ShareAccountSnapshot snapshot, int generation) {
    if (!enabled) return Future.value();
    return _enqueue(() async {
      if (this.generation(snapshot.accountId) != generation) return;
      await channel.invokeMethod<void>('syncShareAccount', snapshot.toMap());
    });
  }

  Future<void> remove(int accountId) {
    _generations[accountId] = generation(accountId) + 1;
    if (!enabled) return Future.value();
    return _enqueue(() async {
      await channel.invokeMethod<void>('clearShareAccount', {
        'accountId': accountId.toString(),
      });
    }).catchError((Object error) {
      logger.w('Share account removal failed: ${error.runtimeType}');
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}

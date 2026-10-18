import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';

import '../utils/logger.dart';
import 'share_account_snapshot.dart';

class NativeShareAccountChannel {
  NativeShareAccountChannel({
    this.channel = const MethodChannel('ru.komet.app/share'),
    bool? enabled,
  }) : enabled = enabled ?? (!kIsWeb && Platform.isIOS);

  static final instance = NativeShareAccountChannel();

  static const _donationThrottle = Duration(minutes: 15);
  static String? _resolvedShareDirectory;

  @visibleForTesting
  static void resetForTesting() => _resolvedShareDirectory = null;

  final MethodChannel channel;
  final bool enabled;
  final Map<int, int> _generations = {};
  final Map<int, int> _donationTimes = {};
  Future<void> _tail = Future.value();

  int generation(int accountId) => _generations[accountId] ?? 0;

  Future<String?> shareDirectory() async {
    final resolved = _resolvedShareDirectory;
    if (resolved != null) return resolved;
    if (!enabled) return null;
    try {
      final directory = await channel.invokeMethod<String>('shareDirectory');
      if (directory == null || directory.isEmpty) return null;
      _resolvedShareDirectory = directory;
      return directory;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> donateShareContact({
    required int accountId,
    required int chatId,
    required String title,
    String? avatarPath,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _donationTimes[chatId];
    if (last != null && now - last < _donationThrottle.inMilliseconds) return;
    _donationTimes[chatId] = now;
    if (!enabled) return;
    try {
      await channel.invokeMethod<void>('donateShareContact', {
        'accountId': accountId.toString(),
        'chatId': chatId.toString(),
        'title': title,
        'avatarPath': ?avatarPath,
      });
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

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
    _generations.putIfAbsent(snapshot.accountId, () => 0);
    if (!enabled) return Future.value();
    return _enqueue(() async {
      if (this.generation(snapshot.accountId) != generation) return;
      await channel.invokeMethod<void>('syncShareAccount', snapshot.toMap());
    });
  }

  Future<void> invalidateAll() {
    for (final accountId in _generations.keys.toList()) {
      _generations[accountId] = generation(accountId) + 1;
    }
    if (!enabled) return Future.value();
    return _enqueue(
      () => channel.invokeMethod<void>('invalidateShareAccounts'),
    );
  }

  Future<void> invalidate(int accountId) {
    _generations[accountId] = generation(accountId) + 1;
    if (!enabled) return Future.value();
    return _enqueue(() async {
      await channel.invokeMethod<void>('invalidateShareAccount', {
        'accountId': accountId.toString(),
      });
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

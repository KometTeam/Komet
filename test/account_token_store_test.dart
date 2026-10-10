import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/account_token_store.dart';

class _TokenBackend {
  final stored = <int, String>{
    101: 'synthetic-original-101',
    202: 'synthetic-original-202',
  };
  final events = <String>[];
  Future<String?> Function(int, String)? renewal;
  Future<void> Function(int, String)? beforeWrite;
  Future<void> Function(int)? beforeClear;

  late final store = AccountTokenStore(
    readStored: (accountId) async {
      events.add('read:$accountId');
      return stored[accountId];
    },
    writeStored: (accountId, token) async {
      await beforeWrite?.call(accountId, token);
      events.add('write:$accountId:$token');
      stored[accountId] = token;
    },
    deleteStored: (accountId) async {
      events.add('delete:$accountId');
      stored.remove(accountId);
    },
    readRenewed: (accountId, token) async {
      events.add('renew:$accountId:$token');
      return renewal?.call(accountId, token);
    },
    clearShared: (accountId) async {
      await beforeClear?.call(accountId);
      events.add('clear:$accountId');
    },
  );
}

void main() {
  test('logout cannot be undone by a delayed native token renewal', () async {
    final backend = _TokenBackend();
    final requested = Completer<void>();
    final renewed = Completer<String?>();
    backend.renewal = (_, _) {
      requested.complete();
      return renewed.future;
    };
    final read = backend.store.read(101);
    await requested.future;
    final logout = backend.store.delete(101);
    renewed.complete('synthetic-renewed-101');
    expect(await read, 'synthetic-renewed-101');
    await logout;
    expect(backend.events, [
      'read:101',
      'renew:101:synthetic-original-101',
      'write:101:synthetic-renewed-101',
      'clear:101',
      'delete:101',
    ]);
    expect(await backend.store.read(101), isNull);
    expect(backend.stored.containsKey(101), isFalse);
    expect(backend.stored[202], 'synthetic-original-202');
  });

  test('a fresh login saved during renewal keeps the newer token', () async {
    final backend = _TokenBackend();
    final requested = Completer<void>();
    final renewed = Completer<String?>();
    final observed = <String>[];
    backend.renewal = (_, token) {
      observed.add(token);
      if (observed.length == 1) {
        requested.complete();
        return renewed.future;
      }
      return Future.value(null);
    };
    final oldRead = backend.store.read(101);
    await requested.future;
    final freshLogin = backend.store.save(101, 'synthetic-fresh-login');
    renewed.complete('synthetic-old-renewal');
    await oldRead;
    await freshLogin;
    expect(await backend.store.read(101), 'synthetic-fresh-login');
    expect(observed, ['synthetic-original-101', 'synthetic-fresh-login']);
    expect(backend.stored[101], 'synthetic-fresh-login');
  });

  test(
    'another account can save and log out while renewal is pending',
    () async {
      final backend = _TokenBackend();
      final requested = Completer<void>();
      final renewed = Completer<String?>();
      backend.renewal = (accountId, _) {
        expect(accountId, 101);
        requested.complete();
        return renewed.future;
      };
      final pending = backend.store.read(101);
      await requested.future;
      await backend.store.save(202, 'synthetic-fresh-202');
      expect(backend.stored[202], 'synthetic-fresh-202');
      await backend.store.delete(202);
      expect(backend.stored.containsKey(202), isFalse);
      expect(backend.stored[101], 'synthetic-original-101');
      renewed.complete('synthetic-renewed-101');
      expect(await pending, 'synthetic-renewed-101');
    },
  );

  test(
    'a failed renewal does not block an already queued fresh save',
    () async {
      final backend = _TokenBackend();
      final requested = Completer<void>();
      final renewal = Completer<String?>();
      backend.renewal = (_, _) {
        requested.complete();
        return renewal.future;
      };
      final failure = expectLater(backend.store.read(101), throwsStateError);
      await requested.future;
      final save = backend.store.save(101, 'synthetic-recovery-token');
      renewal.completeError(StateError('synthetic native failure'));
      await failure;
      await save;
      backend.renewal = null;
      expect(await backend.store.read(101), 'synthetic-recovery-token');
    },
  );

  test(
    'a failed renewal write still allows a queued logout to clear access',
    () async {
      final backend = _TokenBackend();
      final writeStarted = Completer<void>();
      final writeFinished = Completer<void>();
      backend.renewal = (_, _) async => 'synthetic-renewed-101';
      backend.beforeWrite = (_, _) {
        writeStarted.complete();
        return writeFinished.future;
      };
      final failure = expectLater(backend.store.read(101), throwsStateError);
      await writeStarted.future;
      final logout = backend.store.delete(101);
      writeFinished.completeError(StateError('synthetic storage failure'));
      await failure;
      await logout;
      expect(backend.stored.containsKey(101), isFalse);
      expect(backend.events.sublist(backend.events.length - 2), [
        'clear:101',
        'delete:101',
      ]);
    },
  );

  test(
    'shared-clear failure is reported and the next logout can recover',
    () async {
      final backend = _TokenBackend();
      backend.beforeClear = (_) async =>
          throw StateError('synthetic clear failure');
      await expectLater(backend.store.delete(101), throwsStateError);
      expect(backend.stored[101], 'synthetic-original-101');
      expect(backend.events, isNot(contains('delete:101')));
      backend.beforeClear = null;
      await backend.store.delete(101);
      expect(await backend.store.read(101), isNull);
    },
  );
}

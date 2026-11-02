import 'dart:async';

class AccountTokenStore {
  AccountTokenStore({
    required this.readStored,
    required this.writeStored,
    required this.deleteStored,
    required this.readRenewed,
    required this.clearShared,
  });

  final Future<String?> Function(int accountId) readStored;
  final Future<void> Function(int accountId, String token) writeStored;
  final Future<void> Function(int accountId) deleteStored;
  final Future<String?> Function(int accountId, String token) readRenewed;
  final Future<void> Function(int accountId) clearShared;
  final Map<int, Future<void>> _operations = {};

  Future<String?> read(int accountId) => _run(accountId, () async {
    final stored = await readStored(accountId);
    if (stored == null) return null;
    final renewed = await readRenewed(accountId, stored);
    if (renewed == null || renewed.isEmpty || renewed == stored) return stored;
    await writeStored(accountId, renewed);
    return renewed;
  });

  Future<void> save(int accountId, String token) =>
      _run(accountId, () => writeStored(accountId, token));

  Future<void> delete(int accountId) => _run(accountId, () async {
    await clearShared(accountId);
    await deleteStored(accountId);
  });

  Future<T> _run<T>(int accountId, Future<T> Function() action) {
    final result = (_operations[accountId] ?? Future<void>.value()).then(
      (_) => action(),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _operations[accountId] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_operations[accountId], tail)) {
          _operations.remove(accountId);
        }
      }),
    );
    return result;
  }
}

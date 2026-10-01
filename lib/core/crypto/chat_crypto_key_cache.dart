import 'dart:typed_data';

class ChatCryptoKeyCache {
  ChatCryptoKeyCache(this._derive);

  final Future<Uint8List?> Function(int accountId, int chatId) _derive;
  final Map<String, Uint8List> _keys = {};
  final Map<String, Future<Uint8List?>> _pending = {};
  int _generation = 0;

  void clear() {
    _generation++;
    _keys.clear();
    _pending.clear();
  }

  Future<Uint8List?> keyFor(int accountId, int chatId) {
    final cacheKey = '$accountId/$chatId';
    final generation = _generation;
    final cached = _keys[cacheKey];
    if (cached != null) {
      return Future.value(
        cached,
      ).then((key) => generation == _generation ? key : null);
    }
    final existing = _pending[cacheKey];
    if (existing != null) return existing;
    late final Future<Uint8List?> pending;
    pending = _deriveKey(accountId, chatId, cacheKey, generation).whenComplete(
      () {
        if (identical(_pending[cacheKey], pending)) {
          _pending.remove(cacheKey);
        }
      },
    );
    return _pending[cacheKey] = pending;
  }

  Future<Uint8List?> _deriveKey(
    int accountId,
    int chatId,
    String cacheKey,
    int generation,
  ) async {
    final key = await _derive(accountId, chatId);
    if (generation != _generation) return null;
    if (key != null) _keys[cacheKey] = key;
    return key;
  }
}

import 'dart:typed_data';

// #***! кэш ключей чатов: clear сдвигает поколение, и вывод, начатый до сброса,
// #***! в кэш уже не попадает
class ChatCryptoKeyCache {
  ChatCryptoKeyCache(this._derive, {required void Function(Uint8List key) wipe})
    : _wipe = wipe;

  final Future<Uint8List?> Function(int accountId, int chatId) _derive;
  final void Function(Uint8List key) _wipe;
  final Map<String, Uint8List> _keys = {};
  final Map<String, Future<Uint8List?>> _pending = {};
  int _generation = 0;

  void clear() {
    _generation++;
    for (final key in _keys.values) {
      _wipe(key);
    }
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
        if (identical(_pending[cacheKey], pending)) _pending.remove(cacheKey);
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
    if (key == null) return null;
    if (generation != _generation) {
      _wipe(key);
      return null;
    }
    return _keys[cacheKey] = key;
  }
}

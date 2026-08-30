import 'app_database.dart';
import 'token_storage.dart';

// #***! куда мини аппа кладёт данные, база или защищённое хранилище
enum WebAppStorageBackend { device, secure }

class WebAppStorage {
  // #***! лимиты ключей на бота чтоб не забил всё
  static const int deviceKeyLimit = 512;
  static const int secureKeyLimit = 128;

  static String _securePrefix(int accountId, int botId) =>
      'webapp_ss_${accountId}_${botId}_';

  static String _secureKey(int accountId, int botId, String key) =>
      '${_securePrefix(accountId, botId)}$key';

  static String _biometryTokenKey(int accountId, int botId) =>
      'webapp_bio_${accountId}_$botId';

  // #***! secure в keychain, device в базу
  static Future<String?> read(
    int accountId,
    int botId,
    WebAppStorageBackend backend,
    String key,
  ) {
    if (backend == WebAppStorageBackend.secure) {
      return TokenStorage.readSecure(_secureKey(accountId, botId, key));
    }
    return AppDatabase.getWebAppValue(accountId, botId, key);
  }

  // #***! новый ключ сверяем с лимитом, перезапись лимит не трогает
  static Future<bool> save(
    int accountId,
    int botId,
    WebAppStorageBackend backend,
    String key,
    String value,
  ) async {
    if (await read(accountId, botId, backend, key) == null &&
        await _count(accountId, botId, backend) >= _limit(backend)) {
      return false;
    }
    if (backend == WebAppStorageBackend.secure) {
      await TokenStorage.writeSecure(_secureKey(accountId, botId, key), value);
    } else {
      await AppDatabase.saveWebAppValue(accountId, botId, key, value);
    }
    return true;
  }

  static Future<void> remove(
    int accountId,
    int botId,
    WebAppStorageBackend backend,
    String key,
  ) async {
    if (backend == WebAppStorageBackend.secure) {
      await TokenStorage.deleteSecure(_secureKey(accountId, botId, key));
      return;
    }
    await AppDatabase.removeWebAppValue(accountId, botId, key);
  }

  static Future<void> clear(
    int accountId,
    int botId,
    WebAppStorageBackend backend,
  ) async {
    if (backend == WebAppStorageBackend.secure) {
      final keys = await TokenStorage.secureKeysWithPrefix(
        _securePrefix(accountId, botId),
      );
      for (final key in keys) {
        await TokenStorage.deleteSecure(key);
      }
      return;
    }
    await AppDatabase.clearWebAppValues(accountId, botId);
  }

  // #***! токен биометрии только в защищённом
  static Future<String?> biometryToken(int accountId, int botId) =>
      TokenStorage.readSecure(_biometryTokenKey(accountId, botId));

  static Future<void> saveBiometryToken(
    int accountId,
    int botId,
    String token,
  ) => TokenStorage.writeSecure(_biometryTokenKey(accountId, botId), token);

  static Future<void> removeBiometryToken(int accountId, int botId) =>
      TokenStorage.deleteSecure(_biometryTokenKey(accountId, botId));

  // #***! флаги про доступ это обычные данные, держим в базе
  static Future<(bool, bool)> biometryAccess(int accountId, int botId) =>
      AppDatabase.getWebAppBiometryAccess(accountId, botId);

  static Future<void> setBiometryAccess(
    int accountId,
    int botId, {
    required bool requested,
    required bool granted,
  }) => AppDatabase.setWebAppBiometryAccess(
    accountId,
    botId,
    requested: requested,
    granted: granted,
  );

  static int _limit(WebAppStorageBackend backend) =>
      backend == WebAppStorageBackend.secure ? secureKeyLimit : deviceKeyLimit;

  static Future<int> _count(
    int accountId,
    int botId,
    WebAppStorageBackend backend,
  ) async {
    if (backend == WebAppStorageBackend.secure) {
      final keys = await TokenStorage.secureKeysWithPrefix(
        _securePrefix(accountId, botId),
      );
      return keys.length;
    }
    return AppDatabase.countWebAppValues(accountId, botId);
  }
}

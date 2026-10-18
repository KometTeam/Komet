import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show
        ContentType,
        Directory,
        File,
        HttpClient,
        HttpClientResponse,
        Platform,
        SecurityContext;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:komet_crypto/komet_crypto.dart' hide ContentType;

import '../config/build_profile.dart';
import '../storage/app_database.dart';
import '../storage/device_identity.dart';
import '../storage/token_storage.dart';
import '../utils/logger.dart';

class AccountPushState {
  final bool bound;
  final bool active;
  final String accountName;
  final String cipherHash;

  const AccountPushState({
    required this.bound,
    required this.active,
    required this.accountName,
    required this.cipherHash,
  });
}

class PushProxyClient {
  // #***! APNs-прокси живёт на iOS и macOS: токены с нативной регистрации
  static bool get _pushSupported => Platform.isIOS || Platform.isMacOS;
  PushProxyClient._();
  static final PushProxyClient instance = PushProxyClient._();

  static const _endpoint = String.fromEnvironment(
    'PUSH_PROXY_URL',
    defaultValue: 'https://push.komet.purpline.online:18029',
  );

  static const _caAssetPath = 'assets/ca_purple_tree_services.pem';
  static const _bindFingerprintPrefix = 'push_bind_fp_';
  static const _bindAad = 'komet-push-bind-v1';

  HttpClient? _httpClient;

  String? _apnsToken;
  String? _voipToken;
  String? _deviceId;
  bool _isDevelopment = false;
  bool _registered = false;

  final List<Completer<String?>> _voipWaiters = [];

  String? get apnsToken => _apnsToken;
  String? get voipToken => _voipToken;
  bool get registered => _registered;

  Future<String?> waitForVoipToken(Duration timeout) async {
    final token = _voipToken;
    if (token != null && token.isNotEmpty) return token;

    final completer = Completer<String?>();
    _voipWaiters.add(completer);
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () => _voipToken,
      );
    } finally {
      _voipWaiters.remove(completer);
    }
  }

  Timer? _syncTimer;
  bool _syncing = false;
  bool _reregistered = false;

  void setApnsToken(String token) {
    _apnsToken = token;
    if (kDebugMode) {
      logger.i('PushProxy: APNs token установлен (${token.length} симв.)');
    }
    _notifyNativePushProxy();
    _scheduleSync();
  }

  void _notifyNativePushProxy() {
    if (!_pushSupported) return;
    const MethodChannel(
      'ru.komet.app/notifications',
    ).invokeMethod<void>('setPushProxyUrl', {'url': _endpoint});
  }

  Future<void> requestVoipRegistration() async {
    if (!Platform.isIOS) return;
    try {
      await const MethodChannel(
        'ru.komet.app/notifications',
      ).invokeMethod<void>('requestVoipRegistration');
    } catch (e) {
      logger.w('PushProxy: requestVoipRegistration: $e');
    }
  }

  void setVoipToken(String token) {
    _voipToken = token;
    if (kDebugMode) {
      logger.i('PushProxy: VoIP token установлен (${token.length} симв.)');
    }
    final waiters = List.of(_voipWaiters);
    _voipWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete(token);
    }
    _scheduleSync();
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 500), () {
      _syncTimer = null;
      unawaited(verifyAndSync());
    });
  }

  Future<HttpClient> _client() async {
    if (_httpClient != null) return _httpClient!;

    final caPem = await _loadCaCert();
    if (caPem == null || caPem.isEmpty) {
      logger.e('PushProxy: CA сертификат сервера уведомлений недоступен');
      throw const PushProxyTlsException();
    }
    final ctx = SecurityContext(withTrustedRoots: true);
    final tmp = await _writeTempCa(caPem);
    ctx.setTrustedCertificates(tmp);
    _httpClient = HttpClient(context: ctx)
      ..connectionTimeout = const Duration(seconds: 10);
    return _httpClient!;
  }

  Future<String> _writeTempCa(String pem) async {
    final dir = await _tempDir();
    final path = '$dir/push_proxy_ca.pem';
    await File(path).writeAsString(pem);
    return path;
  }

  Future<String> _tempDir() async {
    try {
      return Directory.systemTemp.path;
    } catch (_) {
      return '/tmp';
    }
  }

  Future<String?> _loadCaCert() async {
    try {
      return await rootBundle.loadString(_caAssetPath);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _prepareCredentials() async {
    if (!_pushSupported) return false;
    if (_apnsToken == null || _apnsToken!.isEmpty) {
      logger.w('PushProxy: нет APNs-токена, регистрация пропущена');
      return false;
    }
    _deviceId = await DeviceIdentity.deviceId();
    // #***! dev-подписанный мак всегда в sandbox-окружении APNs
    _isDevelopment =
        kDebugMode || (Platform.isMacOS && !BuildProfile.isAppStoreBuild);
    return true;
  }

  Future<void> registerTokens() async {
    if (!await _prepareCredentials()) return;
    try {
      final response = await post('/register', {
        'apns_token': _apnsToken,
        'voip_token': _voipToken,
        'device_id': _deviceId,
        'is_development': _isDevelopment,
      });
      if (response.statusCode == 200) {
        _registered = true;
        logger.i('PushProxy: токены обновлены');
      } else {
        final body = await response.transform(utf8.decoder).join();
        logger.w(
          'PushProxy: обновление токенов не удалось (${response.statusCode}) $body',
        );
      }
    } catch (e) {
      logger.w('PushProxy: ошибка обновления токенов: $e');
    }
  }

  String _scrambleMaterial(int accountId, int phone) {
    final phoneDigits = phone.toString().split('').reversed.join();
    final idDigits = accountId.toString();
    final sb = StringBuffer();
    final length = phoneDigits.length > idDigits.length
        ? phoneDigits.length
        : idDigits.length;
    for (var i = 0; i < length; i++) {
      if (i < phoneDigits.length) sb.write(phoneDigits[i]);
      if (i < idDigits.length) sb.write(idDigits[i]);
    }
    return sb.toString();
  }

  Uint8List _deriveAccountKey(int accountId, int phone) {
    final digest = crypto.sha256.convert(
      utf8.encode('komet-push-account-v1:$_scrambleMaterial(accountId, phone)'),
    );
    return Uint8List.fromList(digest.bytes);
  }

  Future<String> _accountName(ProfileData? profile) async {
    if (profile == null) return '';
    return [
      profile.firstName,
      profile.lastName,
    ].whereType<String>().join(' ').trim();
  }

  Future<AccountPushState?> prepareAccount(int accountId) async {
    if (!await _prepareCredentials()) return null;
    try {
      final response = await post('/activate/prepare', {
        'apns_token': _apnsToken,
        'account_id': accountId,
      });
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(await response.transform(utf8.decoder).join());
      if (decoded is! Map) return null;
      final data = decoded.cast<String, dynamic>();
      return AccountPushState(
        bound: data['bound'] == true,
        active: data['active'] == true,
        accountName: data['account_name'] as String? ?? '',
        cipherHash: data['cipher_hash'] as String? ?? '',
      );
    } catch (e) {
      logger.w('PushProxy: prepareAccount($accountId): $e');
      return null;
    }
  }

  Future<bool> attachAccount(int accountId) async {
    if (!await _prepareCredentials()) return false;
    final profile = await AppDatabase.loadProfile(accountId);
    try {
      final response = await post('/bind', {
        'apns_token': _apnsToken,
        'voip_token': _voipToken ?? '',
        'device_id': _deviceId,
        'account_id': accountId,
        'account_name': await _accountName(profile),
        'is_development': _isDevelopment,
      });
      if (response.statusCode == 200) {
        logger.i('PushProxy: устройство привязано к аккаунту $accountId');
        return true;
      }
      final body = await response.transform(utf8.decoder).join();
      logger.w(
        'PushProxy: привязка к аккаунту $accountId не удалась '
        '(${response.statusCode}) $body',
      );
      return false;
    } catch (e) {
      logger.w('PushProxy: ошибка привязки аккаунта $accountId: $e');
      return false;
    }
  }

  Future<bool> registerAccountToken(int accountId, String loginToken) async {
    if (!await _prepareCredentials()) return false;
    if (!KometCrypto.isAvailable) {
      logger.w('PushProxy: крипто-ядро недоступно, привязка не завершена');
      return false;
    }
    if (loginToken.isEmpty) {
      logger.w('PushProxy: пустой токен сессии аккаунта $accountId');
      return false;
    }
    final profile = await AppDatabase.loadProfile(accountId);
    if (profile == null) {
      logger.w('PushProxy: профиль аккаунта $accountId не найден');
      return false;
    }
    final key = _deriveAccountKey(accountId, profile.phone);
    final plaintext = Uint8List.fromList(utf8.encode(loginToken));
    final blob = KometCrypto.localSeal(
      key: key,
      plaintext: plaintext,
      aad: Uint8List.fromList(utf8.encode(_bindAad)),
    );
    final fingerprint = base64Encode(crypto.sha256.convert(blob).bytes);
    try {
      final response = await post('/bind', {
        'apns_token': _apnsToken,
        'voip_token': _voipToken ?? '',
        'device_id': _deviceId,
        'account_id': accountId,
        'account_name': await _accountName(profile),
        'is_development': _isDevelopment,
        'blob': base64Encode(blob),
      });
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        logger.w(
          'PushProxy: регистрация аккаунта $accountId не удалась '
          '(${response.statusCode}) $body',
        );
        return false;
      }
      await TokenStorage.writeSecure(
        '$_bindFingerprintPrefix$accountId',
        fingerprint,
      );
      logger.i('PushProxy: сессия уведомлений аккаунта $accountId запечатана');
      unawaited(_activateAccount(accountId));
      return true;
    } catch (e) {
      logger.w('PushProxy: ошибка регистрации аккаунта $accountId: $e');
      return false;
    } finally {
      KometCrypto.wipe(plaintext);
      KometCrypto.wipe(blob);
    }
  }

  Future<void> activatePushSession() async {
    if (!await _prepareCredentials()) return;
    final profiles = await AppDatabase.loadAllProfiles();
    for (final profile in profiles) {
      await _activateAccount(profile.id);
    }
  }

  Future<void> _activateAccount(int accountId) async {
    if (!await _prepareCredentials()) return;
    try {
      final prepare = await post('/activate/prepare', {
        'apns_token': _apnsToken,
        'account_id': accountId,
      });
      if (prepare.statusCode != 200) return;
      final decoded = jsonDecode(await prepare.transform(utf8.decoder).join());
      if (decoded is! Map) return;
      final data = decoded.cast<String, dynamic>();
      if (data['active'] == true) {
        logger.i(
          'PushProxy: аккаунт $accountId уже активен, ключ не отправляется',
        );
        return;
      }
      if (data['bound'] != true) {
        return;
      }
      final profile = await AppDatabase.loadProfile(accountId);
      if (profile == null) {
        logger.w('PushProxy: профиль аккаунта $accountId не найден');
        return;
      }
      final stored = await TokenStorage.readSecure(
        '$_bindFingerprintPrefix$accountId',
      );
      final cipherHash = data['cipher_hash'] as String? ?? '';
      // #***! несовпадение — штатно после ротации токена: сервер перезапечатывает
      // blob тем же ключом, поэтому активации не мешает, только логируем
      if (stored != null && stored.isNotEmpty && stored != cipherHash) {
        logger.w(
          'PushProxy: отпечаток шифротекста аккаунта $accountId не совпал '
          '— продолжаю активацию (сервер мог перезапечатать токен)',
        );
      }
      final key = _deriveAccountKey(accountId, profile.phone);
      final response = await post('/activate', {
        'apns_token': _apnsToken,
        'account_id': accountId,
        'voip_token': _voipToken ?? '',
        'device_id': _deviceId,
        'is_development': _isDevelopment,
        'key': base64Encode(key),
      });
      if (response.statusCode == 200) {
        logger.i(
          'PushProxy: аккаунт $accountId активирован, уведомления включены',
        );
        await _refreshBindFingerprint(accountId);
      } else {
        final body = await response.transform(utf8.decoder).join();
        logger.w(
          'PushProxy: активация аккаунта $accountId не удалась '
          '(${response.statusCode}) $body',
        );
        if (body.contains('auth rejected') ||
            body.contains('неверный ключ привязки')) {
          await TokenStorage.deleteSecure('$_bindFingerprintPrefix$accountId');
          logger.w(
            'PushProxy: привязка аккаунта $accountId недействительна, '
            'требуется повторная регистрация',
          );
        }
      }
    } catch (e) {
      logger.w('PushProxy: ошибка активации аккаунта $accountId: $e');
    }
  }

  Future<void> _refreshBindFingerprint(int accountId) async {
    try {
      final prepare = await post('/activate/prepare', {
        'apns_token': _apnsToken,
        'account_id': accountId,
      });
      if (prepare.statusCode != 200) return;
      final decoded = jsonDecode(await prepare.transform(utf8.decoder).join());
      if (decoded is! Map) return;
      final cipherHash =
          (decoded.cast<String, dynamic>())['cipher_hash'] as String? ?? '';
      if (cipherHash.isEmpty) return;
      await TokenStorage.writeSecure(
        '$_bindFingerprintPrefix$accountId',
        cipherHash,
      );
    } catch (e) {
      logger.w(
        'PushProxy: не удалось обновить отпечаток аккаунта $accountId: $e',
      );
    }
  }

  Future<Map<int, bool>> serverAccountStates() async {
    if (!await _prepareCredentials()) return {};
    try {
      final response = await post('/verify', {
        'apns_token': _apnsToken,
        'voip_token': _voipToken,
        'device_id': _deviceId,
        'is_development': _isDevelopment,
      });
      if (response.statusCode != 200) return {};
      final decoded = jsonDecode(await response.transform(utf8.decoder).join());
      if (decoded is! Map) return {};
      final data = decoded.cast<String, dynamic>();
      if (data['registered'] != true) return {};
      final accounts = data['accounts'];
      final states = <int, bool>{};
      if (accounts is List) {
        for (final item in accounts) {
          if (item is! Map) continue;
          final id = (item['account_id'] as num?)?.toInt();
          if (id != null && id != 0) {
            states[id] = item['active'] == true;
          }
        }
      }
      return states;
    } catch (e) {
      logger.w('PushProxy: serverAccountStates: $e');
      return {};
    }
  }

  Future<void> verifyAndSync() async {
    if (!_pushSupported) return;
    if (_syncing) return;
    if (!await _prepareCredentials()) return;
    _syncing = true;
    try {
      final response = await post('/verify', {
        'apns_token': _apnsToken,
        'voip_token': _voipToken,
        'device_id': _deviceId,
        'is_development': _isDevelopment,
      });
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        logger.w('PushProxy: verify статус ${response.statusCode} $body');
        return;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) return;
      final data = decoded.cast<String, dynamic>();
      _registered = data['registered'] == true;
      final apnsMatches = data['apns_token_matches'] == true;
      final tokenRejected = data['token_rejected'] == true;
      logger.i(
        'PushProxy: verify — registered=$_registered, apnsMatches=$apnsMatches, '
        'tokenRejected=$tokenRejected, аккаунтов=${(data['accounts'] as List?)?.length ?? 0}',
      );
      if (tokenRejected) {
        unawaited(_reRegisterApnsToken());
        return;
      }
      final voipPresent = data['voip_token_present'] == true;
      final voipMatches = data['voip_token_matches'] == true;
      final deviceMatches = data['device_id_matches'] == true;
      final devMatches = data['is_development_matches'] == true;
      final hasVoip = _voipToken != null && _voipToken!.isNotEmpty;
      var mismatch = false;
      if (_registered && !apnsMatches) {
        // #***! токен перевыпущен — сервер перезапишет его по device_id
        mismatch = true;
      }
      if (hasVoip && (!voipPresent || !voipMatches)) mismatch = true;
      if (!deviceMatches) mismatch = true;
      if (!devMatches) mismatch = true;
      if (mismatch) {
        logger.i('PushProxy: verify — рассинхрон, обновляю токены');
        await registerTokens();
      }
      final profiles = await AppDatabase.loadAllProfiles();
      for (final profile in profiles) {
        final state = await prepareAccount(profile.id);
        if (state == null || state.bound) continue;
        await attachAccount(profile.id);
      }
      final states = await serverAccountStates();
      _registered = states.isNotEmpty;
      unawaited(activatePushSession());
    } catch (e) {
      logger.w('PushProxy: ошибка verify: $e');
    } finally {
      _syncing = false;
    }
  }

  // #***! чистая перерегистрация APNs, раз на запуск — иначе цикл на мёртвом токене
  Future<void> _reRegisterApnsToken() async {
    if (_reregistered || !_pushSupported) return;
    _reregistered = true;
    logger.i('PushProxy: токен отвергнут Apple, чистая перерегистрация');
    try {
      await const MethodChannel(
        'ru.komet.app/notifications',
      ).invokeMethod<void>('reregisterApns');
    } catch (e) {
      logger.w('PushProxy: reregisterApns: $e');
    }
  }

  Future<void> setAvatarColors({
    required String lightBg,
    required String lightFg,
    required String darkBg,
    required String darkFg,
  }) async {
    if (!_pushSupported) return;
    final token = _apnsToken;
    if (token == null || token.isEmpty) return;
    try {
      await post('/avatar-colors', {
        'apns_token': token,
        'light_bg': lightBg,
        'light_fg': lightFg,
        'dark_bg': darkBg,
        'dark_fg': darkFg,
      });
    } catch (e) {
      logger.w('PushProxy: setAvatarColors: $e');
    }
  }

  Future<void> syncUnread(Map<String, int> chats, int accountId) async {
    if (!_pushSupported) return;
    final token = _apnsToken;
    if (token == null || token.isEmpty) return;
    try {
      await post('/badge', {
        'apns_token': token,
        'account_id': accountId,
        'chats': chats,
      });
    } catch (e) {
      logger.w('PushProxy: syncUnread: $e');
    }
  }

  Future<void> setForeground(bool foreground) async {
    if (!_registered || _apnsToken == null) return;
    try {
      await post('/state', {
        'apns_token': _apnsToken,
        'foreground': foreground,
      });
      if (kDebugMode) {
        logger.i(
          'PushProxy: state → ${foreground ? 'foreground' : 'background'}',
        );
      }
      if (foreground) {
        unawaited(activatePushSession());
      }
    } catch (e) {
      logger.w('PushProxy: ошибка state: $e');
    }
  }

  Future<void> unregisterAccount(int accountId) async {
    if (!Platform.isIOS) return;
    final token = _apnsToken;
    if (token == null || token.isEmpty) return;
    try {
      await post('/unregister', {'apns_token': token, 'account_id': accountId});
      logger.i('PushProxy: аккаунт $accountId отвязан');
    } catch (e) {
      logger.w('PushProxy: ошибка отвязки аккаунта $accountId: $e');
    }
    await TokenStorage.deleteSecure('$_bindFingerprintPrefix$accountId');
  }

  Future<void> unregisterActiveAccount() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null || accountId == 0) return;
    await unregisterAccount(accountId);
  }

  Future<HttpClientResponse> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = await _client();
    final uri = Uri.parse('$_endpoint$path');
    return _doPost(client, uri, body);
  }

  Future<HttpClientResponse> _doPost(
    HttpClient client,
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode(body)));
    return request.close();
  }
}

class PushProxyTlsException implements Exception {
  const PushProxyTlsException();

  @override
  String toString() =>
      'PushProxyTlsException: CA сервера уведомлений недоступен, '
      'строгая проверка TLS невозможна';
}

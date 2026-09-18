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

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/device_identity.dart';
import '../utils/logger.dart';

class PushProxyClient {
  PushProxyClient._();
  static final PushProxyClient instance = PushProxyClient._();

  static const _endpoint = String.fromEnvironment(
    'PUSH_PROXY_URL',
    defaultValue: 'https://push.komet.purpline.online:18029',
  );

  static const _caAssetPath = 'assets/ca_purple_tree_services.pem';

  static const _prefLinked = 'push_proxy_linked';

  HttpClient? _httpClient;

  String? _apnsToken;
  String? _voipToken;
  String? _deviceId;
  bool _isDevelopment = false;
  bool _registered = false;

  String? get apnsToken => _apnsToken;
  String? get voipToken => _voipToken;
  bool get registered => _registered;

  Timer? _syncTimer;
  bool _syncing = false;

  Future<bool> isLinked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefLinked) ?? false;
  }

  void setLinked(bool value) {
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setBool(_prefLinked, value),
      ),
    );
  }

  void setApnsToken(String token) {
    _apnsToken = token;
    if (kDebugMode) {
      logger.i('PushProxy: APNs token установлен (${token.length} симв.)');
    }
    _notifyNativePushProxy();
    _scheduleSync();
  }

  void _notifyNativePushProxy() {
    if (!Platform.isIOS) return;
    const MethodChannel(
      'ru.komet.app/notifications',
    ).invokeMethod<void>('setPushProxyUrl', {'url': _endpoint});
  }

  void setVoipToken(String token) {
    _voipToken = token;
    if (kDebugMode) {
      logger.i('PushProxy: VoIP token установлен (${token.length} симв.)');
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
    if (caPem != null) {
      try {
        final ctx = SecurityContext(withTrustedRoots: true);
        final tmp = await _writeTempCa(caPem);
        ctx.setTrustedCertificates(tmp);
        _httpClient = HttpClient(context: ctx)
          ..connectionTimeout = const Duration(seconds: 10);
        logger.i('PushProxy: TLS — CA из ассета загружен');
      } catch (e) {
        logger.w('PushProxy: CA-загрузка не удалась ($e), host-pin fallback');
        _httpClient = _hostPinnedClient();
      }
    } else {
      _httpClient = _hostPinnedClient();
      if (kDebugMode) {
        logger.w('PushProxy: TLS — CA не найден, debug-режим');
      }
    }
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

  HttpClient _hostPinnedClient() {
    return HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (cert, host, port) {
        final expected = Uri.tryParse(_endpoint)?.host;
        if (host == expected) return true;
        if (kDebugMode) return true;
        return false;
      };
  }

  Future<String?> _loadCaCert() async {
    try {
      return await rootBundle.loadString(_caAssetPath);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _prepareCredentials() async {
    if (!Platform.isIOS) return false;
    if (_apnsToken == null || _apnsToken!.isEmpty) {
      logger.w('PushProxy: нет APNs-токена, регистрация пропущена');
      return false;
    }
    _deviceId = await DeviceIdentity.deviceId();
    _isDevelopment = kDebugMode;
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
        setLinked(true);
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

  Future<void> setAvatarColors({
    required String lightBg,
    required String lightFg,
    required String darkBg,
    required String darkFg,
  }) async {
    if (!Platform.isIOS) return;
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

  Future<void> syncUnread(Map<String, int> chats) async {
    if (!Platform.isIOS) return;
    final token = _apnsToken;
    if (token == null || token.isEmpty) return;
    try {
      await post('/badge', {'apns_token': token, 'chats': chats});
    } catch (e) {
      logger.w('PushProxy: syncUnread: $e');
    }
  }

  Future<void> verifyAndSync() async {
    if (!Platform.isIOS) return;
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
      final registered = data['registered'] == true;
      if (!registered) {
        if (await isLinked()) {
          logger.i('PushProxy: verify — привязки нет, сбрасываю статус');
          setLinked(false);
        }
        _registered = false;
        return;
      }
      _registered = true;
      setLinked(true);
      final voipPresent = data['voip_token_present'] == true;
      final voipMatches = data['voip_token_matches'] == true;
      final deviceMatches = data['device_id_matches'] == true;
      final devMatches = data['is_development_matches'] == true;
      final hasVoip = _voipToken != null && _voipToken!.isNotEmpty;
      bool mismatch = false;
      if (hasVoip && (!voipPresent || !voipMatches)) mismatch = true;
      if (!deviceMatches) mismatch = true;
      if (!devMatches) mismatch = true;
      if (mismatch) {
        logger.i('PushProxy: verify — рассинхрон, обновляю токены');
        await registerTokens();
      } else if (kDebugMode) {
        logger.i('PushProxy: verify — регистрация актуальна');
      }
    } catch (e) {
      logger.w('PushProxy: ошибка verify: $e');
    } finally {
      _syncing = false;
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
    } catch (e) {
      logger.w('PushProxy: ошибка state: $e');
    }
  }

  Future<void> unregister() async {
    if (!Platform.isIOS) return;
    final token = _apnsToken;
    if (token == null || token.isEmpty) return;
    _registered = false;
    _syncTimer?.cancel();
    _syncTimer = null;
    _syncing = false;
    setLinked(false);
    try {
      await post('/unregister', {'apns_token': token});
      logger.i('PushProxy: привязка отключена');
    } catch (e) {
      logger.w('PushProxy: ошибка unregister: $e');
    }
  }

  Future<HttpClientResponse> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = await _client();
    final uri = Uri.parse('$_endpoint$path');
    try {
      return await _doPost(client, uri, body);
    } catch (e) {
      if (kDebugMode && _httpClient != null) {
        logger.w('PushProxy: TLS handshake не удался ($e), retry без проверки');
        _httpClient = _hostPinnedClient();
        return await _doPost(_httpClient!, uri, body);
      }
      rethrow;
    }
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

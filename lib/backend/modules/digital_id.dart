import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:device_info_plus/device_info_plus.dart';

import '../../core/storage/app_database.dart';
import '../../core/storage/spoofing_service.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import '../../models/digital_id.dart';
import 'webapp.dart';

// #***! ошибка цифрового ID, отдельно нет авторизации и нет госуслуг
class DigitalIdException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const DigitalIdException(this.code, this.message, {this.statusCode});

  bool get isUnauthorized => code == 'UNAUTHORIZED';
  bool get isNoGosuslugiLink => code == 'NO_GOSUSLUGI_LINK';

  @override
  String toString() => message;
}

// #***! нативный цифровой ID, ходит в HTTP мимо вебвью
class DigitalIdModule {
  // #***! отдельный хост, к сокету отношения не имеет
  static const String _baseUrl = 'https://ext-api.max.ru';
  static const String _deviceIdKey = 'digital_id_device_id';
  static const String _tokenKey = 'digital_id_biometry_token';

  final WebAppModule _webApp;
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);

  // #***! авторизация это WebAppData из адреса мини аппы
  String? _webAppData;
  String? _deviceId;
  String? _realUserAgent;

  DigitalIdModule(this._webApp);

  // #***! берём и кэшируем WebAppData
  Future<String> _ensureWebAppData({bool forceRefresh = false}) async {
    if (!forceRefresh && _webAppData != null) return _webAppData!;
    final launch = await _webApp.fetchDigitalId();
    final data = _extractWebAppData(launch.url);
    if (data == null) {
      throw const DigitalIdException(
        'NO_INIT_DATA',
        'Не удалось получить данные авторизации Цифрового ID',
      );
    }
    _webAppData = data;
    return data;
  }

  // #***! WebAppData во фрагменте и закодирован целиком, серверу нужен раскодированный
  String? _extractWebAppData(String url) {
    final hashIndex = url.indexOf('#');
    if (hashIndex < 0) return null;
    final fragment = url.substring(hashIndex + 1);
    final match = RegExp(
      r'WebAppData=([^&]*(?:&(?!WebApp)[^&]*)*)',
    ).firstMatch(fragment);
    final raw = match?.group(1);
    if (raw == null || raw.isEmpty) return null;
    // Фрагмент несёт WebAppData полностью percent-encoded (hash%3D…%26…);
    // сервер ждёт канонический initDataRaw (hash=…&…) — как шлёт web-страница
    // после decodeURIComponent. Декодируем один раз (фолбэк — сырое значение).
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      return raw;
    }
  }

  // #***! device_id должен совпасть с хэндшейком иначе device_mismatch
  Future<String> deviceId() async {
    // Тот же device_id, что уходит в handshake (опкод 6) — иначе сервер вернёт
    // device_mismatch. Сессия обычно уже поднята к моменту открытия Цифрового ID.
    final session = _webApp.sessionDeviceId;
    if (session != null && session.isNotEmpty) return session;
    if (_deviceId != null) return _deviceId!;
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId != null) {
      final stored = await AppDatabase.getSyncValue(accountId, _deviceIdKey);
      if (stored != null && stored.isNotEmpty) {
        _deviceId = stored;
        return stored;
      }
    }
    final generated = await _generateDeviceId();
    if (accountId != null) {
      await AppDatabase.setSyncValue(accountId, _deviceIdKey, generated);
    }
    _deviceId = generated;
    return generated;
  }

  // #***! запасной device_id пока нет сессии
  Future<String> _generateDeviceId() async {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return '${android.id}_$hex';
      }
    } catch (_) {}
    return hex;
  }

  // #***! представляемся тем же браузером что и вебвью
  Future<String> _resolveUserAgent() async {
    final spoofed = await SpoofingService.getWebViewUserAgent();
    if (spoofed != null && spoofed.isNotEmpty) return spoofed;
    return _realUserAgent ??= await _buildRealUserAgent();
  }

  Future<String> _buildRealUserAgent() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return 'Mozilla/5.0 (Linux; Android ${android.version.release}; '
            '${android.model}) AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/124.0.0.0 Mobile Safari/537.36';
      }
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        final version = ios.systemVersion.replaceAll('.', '_');
        return 'Mozilla/5.0 (iPhone; CPU iPhone OS $version like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
            'Mobile/15E148 Safari/604.1';
      }
    } catch (_) {}
    return 'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  }

  // #***! все HTTP запросы тут, заголовки повтор после 401 и ошибки
  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    bool retry = true,
  }) async {
    final webAppData = await _ensureWebAppData();
    final uri = Uri.parse('$_baseUrl$path');
    final request = await _http.openUrl(method, uri);
    request.headers.set('Authorization', '#WebAppData=$webAppData');
    request.headers.set('Origin', 'https://digital-id.max.ru');
    request.headers.set('Referer', 'https://digital-id.max.ru/');
    request.headers.set('x-requested-with', 'ru.oneme.app');
    request.headers.set('Accept', 'application/json');
    request.headers.set('User-Agent', await _resolveUserAgent());
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (kDebugMode) {
      logger.i('[DID-native] $method $path -> ${response.statusCode}');
    }

    // #***! 401 значит WebAppData протух, обновляем и повторяем один раз
    if (response.statusCode == 401 && retry) {
      await _ensureWebAppData(forceRefresh: true);
      return _send(method, path, body: body, retry: false);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFor(response.statusCode, text);
    }
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }

  // #***! код и текст ошибки из тела если оно похоже на джейсон
  DigitalIdException _errorFor(int statusCode, String body) {
    String code = 'HTTP_$statusCode';
    String message = 'Ошибка Цифрового ID ($statusCode)';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final rawCode =
            decoded['code'] ?? decoded['error'] ?? decoded['status'];
        if (rawCode is String && rawCode.isNotEmpty) code = rawCode;
        final rawMessage = decoded['message'] ?? decoded['error_description'];
        if (rawMessage is String && rawMessage.isNotEmpty) message = rawMessage;
      }
    } catch (_) {}
    if (statusCode == 401) code = 'UNAUTHORIZED';
    return DigitalIdException(code, message, statusCode: statusCode);
  }

  // #***! ответы то в data то нет
  Map _unwrapData(dynamic decoded) {
    if (decoded is Map && decoded['data'] is Map) {
      return decoded['data'] as Map;
    }
    return decoded is Map ? decoded : const {};
  }

  // #***! дальше по методу на эндпоинт
  Future<DigitalIdBiometryStatus> biometryStatus() async {
    final decoded = await _send('GET', '/v2/digital-id/biometry-status');
    return DigitalIdBiometryStatus.fromMap(_unwrapData(decoded));
  }

  Future<String> createBiometryToken({
    required String deviceId,
    String? photoHash,
  }) async {
    final decoded = await _send(
      'POST',
      '/v3/digital-id/create-biometry-token',
      body: {'device_id': deviceId, 'photo_hash': ?photoHash},
    );
    return _unwrapData(decoded)['token'] as String? ?? '';
  }

  // #***! документы асинхронно, refresh даёт state и по нему опрашиваем
  Future<String> refreshUserDocs(String token) async {
    final decoded = await _send(
      'POST',
      '/v3/digital-id/refresh-user-docs',
      body: {'token': token},
    );
    return _unwrapData(decoded)['state'] as String? ?? '';
  }

  Future<DigitalIdUserDocs?> getUserDocs(String state) async {
    final decoded = await _send(
      'POST',
      '/v2/digital-id/get-user-docs',
      body: {'state': state},
    );
    if (decoded is Map && decoded['status'] == 'done') {
      final data = decoded['data'];
      if (data is Map) return DigitalIdUserDocs.fromMap(data);
    }
    return null;
  }

  Future<DigitalIdEsiaLink> createEsiaLink() async {
    final decoded = await _send('GET', '/v2/digital-id/create-esia-link');
    return DigitalIdEsiaLink.fromMap(decoded is Map ? decoded : const {});
  }

  Future<DigitalIdVerification> verifyPhoto({
    required String deviceId,
    String? photoHash,
  }) async {
    final decoded = await _send(
      'POST',
      '/digital-id-verify-photo',
      body: {'device_id': deviceId, 'photo_hash': ?photoHash},
    );
    final status = decoded is Map ? decoded['status'] as String? : null;
    return DigitalIdVerification.fromValue(status);
  }

  // #***! shadow-mode, 404 значит фича выключена а не ошибка
  Future<bool> shadowMode(String deviceId) async {
    try {
      final decoded = await _send(
        'POST',
        '/v3/digital-id/shadow-mode',
        body: {'device_id': deviceId},
      );
      return _unwrapData(decoded)['shadow_mode'] == true;
    } on DigitalIdException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  Future<void> updateGuHashes() async {
    await _send('POST', '/v2/digital-id/update-gu-hashes', body: const {});
  }

  Future<DigitalIdUniversalQr> userQr(String token) async {
    final decoded = await _send(
      'POST',
      '/v3/digital-id/user-qr',
      body: {'token': token},
    );
    return DigitalIdUniversalQr.fromMap(_unwrapData(decoded));
  }

  Future<DigitalIdQr> generateQr({
    required String photo,
    required String token,
    required DigitalIdQrType qrType,
    String? kidAct,
  }) async {
    final decoded = await _send(
      'POST',
      '/v3/digital-id/generate-qr',
      body: {
        'photo': photo,
        'token': token,
        'qr_type': qrType.code,
        'kid_act': ?kidAct,
      },
    );
    return DigitalIdQr.fromMap(_unwrapData(decoded));
  }

  Future<List<DigitalIdAcmsCard>> getCardsList({
    String? passStatus,
    String? inn,
  }) async {
    final query = <String, String>{'pass_status': ?passStatus, 'inn': ?inn};
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final decoded = await _send('GET', '/v2/digital-id/get-cards-list$suffix');
    final cards = _unwrapData(decoded)['acms_cards'];
    if (cards is! List) return const [];
    return cards
        .whereType<Map>()
        .map(DigitalIdAcmsCard.fromMap)
        .toList(growable: false);
  }

  Future<void> activateAcms({required String id, required String inn}) async {
    await _send(
      'POST',
      '/v2/digital-id/activate-acms',
      body: {'id': id, 'inn': inn, 'pass_status': 'active'},
    );
  }

  Future<void> createLiteProfile(String deviceId) async {
    await _send(
      'POST',
      '/v2/digital-id/create-lite-profile',
      body: {'device_id': deviceId},
    );
  }

  // #***! удалили профиль, стираем и токен биометрии
  Future<void> deleteProfile() async {
    await _send('DELETE', '/v3/digital-id/delete-profile');
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId != null) {
      await TokenStorage.deleteSecure('${_tokenKey}_$accountId');
      await AppDatabase.setSyncValue(accountId, _tokenKey, '');
    }
  }

  // #***! токен биометрии в защищённом хранилище, старый переносим
  Future<String?> _storedToken() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return null;
    final secureKey = '${_tokenKey}_$accountId';
    final secured = await TokenStorage.readSecure(secureKey);
    if (secured != null && secured.isNotEmpty) return secured;

    final legacy = await AppDatabase.getSyncValue(accountId, _tokenKey);
    if (legacy != null && legacy.isNotEmpty) {
      await TokenStorage.writeSecure(secureKey, legacy);
      await AppDatabase.setSyncValue(accountId, _tokenKey, '');
      return legacy;
    }
    return null;
  }

  Future<void> _saveToken(String token) async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId != null) {
      await TokenStorage.writeSecure('${_tokenKey}_$accountId', token);
    }
  }

  // #***! токен создаём один раз
  Future<String> ensureBiometryToken({String? photoHash}) async {
    final existing = await _storedToken();
    if (existing != null) return existing;
    final id = await deviceId();
    final token = await createBiometryToken(deviceId: id, photoHash: photoHash);
    if (token.isNotEmpty) await _saveToken(token);
    return token;
  }

  // #***! пять попыток по 2 секунды пока сервер готовит документы
  Future<DigitalIdUserDocs?> loadDocuments({
    bool createIfMissing = false,
    int attempts = 5,
  }) async {
    var token = await _storedToken();
    if (token == null) {
      if (!createIfMissing) return null;
      final id = await deviceId();
      token = await createBiometryToken(deviceId: id);
      if (token.isEmpty) return null;
      await _saveToken(token);
    }
    final state = await refreshUserDocs(token);
    if (state.isEmpty) return null;
    for (var attempt = 0; attempt < attempts; attempt++) {
      final docs = await getUserDocs(state);
      if (docs != null) return docs;
      await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  // #***! качаем страницу проверки из QR, разбирает вызывающий
  Future<Map<String, dynamic>?> fetchMobileIdVerification(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return null;
    try {
      final request = await _http.getUrl(uri);
      request.followRedirects = true;
      final response = await request.close();
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        headers[name] = values.join(',');
      });
      return {
        'statusCode': response.statusCode,
        'headers': headers,
        'data': base64Encode(builder.takeBytes()),
      };
    } catch (_) {
      return null;
    }
  }

  // #***! сброс при смене аккаунта
  void reset() {
    _webAppData = null;
    _deviceId = null;
    _realUserAgent = null;
  }
}

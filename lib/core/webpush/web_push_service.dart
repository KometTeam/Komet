import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:device_info_plus/device_info_plus.dart';

import '../protocol/opcode_map.dart';
import '../storage/token_storage.dart';
import '../utils/ids.dart';
import '../utils/logger.dart';
import 'max_web_socket.dart';

class WebPushSubscription {
  final String endpoint;
  final String publicKey;
  final String authKey;

  const WebPushSubscription({
    required this.endpoint,
    required this.publicKey,
    required this.authKey,
  });
}

class WebPushQrTrack {
  final String trackId;
  final String qrLink;
  final Duration pollInterval;
  final Duration lifetime;

  const WebPushQrTrack({
    required this.trackId,
    required this.qrLink,
    required this.pollInterval,
    required this.lifetime,
  });
}

class WebPushPasswordChallenge {
  final String trackId;
  final String? hint;

  const WebPushPasswordChallenge({required this.trackId, this.hint});
}

class WebPushAuthStep {
  final String? loginToken;
  final WebPushPasswordChallenge? passwordChallenge;

  const WebPushAuthStep({this.loginToken, this.passwordChallenge});

  bool get needsPassword => loginToken == null && passwordChallenge != null;
}

class WebPushService {
  WebPushService._();

  static final WebPushService instance = WebPushService._();

  static const int _opcodeQrCreate = 288;
  static const int _opcodeQrStatus = 289;
  static const int _opcodeQrFinish = 291;

  static const String _tokenKey = 'webpush_login_token';
  static const String _deviceIdKey = 'webpush_device_id';
  static const String _endpointKey = 'webpush_endpoint';

  static const String _appVersion = '26.8.8';
  static const Duration _defaultPoll = Duration(seconds: 5);
  static const Duration _defaultLifetime = Duration(minutes: 2);

  MaxWebSocketSession? _authSocket;
  MaxWebDevice? _device;

  Future<bool> isAuthorized() async =>
      (await TokenStorage.readSecure(_tokenKey))?.isNotEmpty ?? false;

  Future<String?> linkedEndpoint() => TokenStorage.readSecure(_endpointKey);

  Future<String> deviceId() async {
    final saved = await TokenStorage.readSecure(_deviceIdKey);
    if (saved != null && saved.isNotEmpty) return saved;

    final generated = uuidV4();
    await TokenStorage.writeSecure(_deviceIdKey, generated);
    return generated;
  }

  Future<MaxWebDevice> device() async {
    final cached = _device;
    if (cached != null) return cached;

    final built = MaxWebDevice(
      deviceId: await deviceId(),
      appVersion: _appVersion,
      userAgent: await _safariUserAgent(),
      screen: _browserScreen(),
    );
    _device = built;
    return built;
  }

  Future<WebPushQrTrack> startQrAuth() async {
    await cancelAuth();

    final socket = MaxWebSocketSession(device: await device());
    await socket.connect();
    _authSocket = socket;

    final payload = _asMap(
      await socket.request(_opcodeQrCreate, null),
      'создание QR',
    );

    final trackId = payload['trackId'];
    final qrLink = payload['qrLink'];
    if (trackId is! String || qrLink is! String) {
      throw const MaxWebException('сервер не вернул ссылку для входа');
    }

    return WebPushQrTrack(
      trackId: trackId,
      qrLink: qrLink,
      pollInterval: _durationFrom(payload['pollingInterval'], _defaultPoll),
      lifetime: _durationFrom(payload['ttl'], _defaultLifetime),
    );
  }

  Future<WebPushAuthStep> awaitApproval(WebPushQrTrack track) async {
    final socket = _requireSocket();
    final deadline = DateTime.now().add(track.lifetime);

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(track.pollInterval);

      final payload = _asMap(
        await socket.request(_opcodeQrStatus, <String, Object?>{
          'trackId': track.trackId,
        }),
        'опрос входа',
      );

      final status = payload['status'];
      final available = status is Map ? status['loginAvailable'] : null;
      if (available != true) continue;

      final finish = _asMap(
        await socket.request(_opcodeQrFinish, <String, Object?>{
          'trackId': track.trackId,
        }),
        'завершение входа',
      );
      return _stepFrom(finish);
    }

    throw const MaxWebException('время подтверждения истекло');
  }

  Future<WebPushAuthStep> submitPassword(String trackId, String password) async {
    final socket = _requireSocket();
    final payload = _asMap(
      await socket.request(Opcode.authLoginCheckPassword, <String, Object?>{
        'trackId': trackId,
        'password': password,
      }),
      'проверка пароля',
    );
    return _stepFrom(payload);
  }

  Future<void> finishAuth(String loginToken) async {
    await TokenStorage.writeSecure(_tokenKey, loginToken);
    await cancelAuth();
    logger.i('WebPush: WEB-сессия авторизована по QR');
  }

  Future<void> cancelAuth() async {
    final socket = _authSocket;
    _authSocket = null;
    await socket?.close();
  }

  Future<void> registerSubscription(WebPushSubscription subscription) async {
    final token = await TokenStorage.readSecure(_tokenKey);
    if (token == null || token.isEmpty) {
      throw const MaxWebException('сначала подключите уведомления в настройках');
    }

    final socket = MaxWebSocketSession(device: await device());
    try {
      await socket.connect();
      await socket.request(Opcode.login, <String, Object?>{
        'token': token,
        'chatsCount': 0,
        'interactive': false,
        'chatsSync': 0,
        'contactsSync': 0,
        'presenceSync': -1,
        'draftsSync': 0,
      });
      await socket.request(Opcode.config, <String, Object?>{
        'subscribe': true,
        'pushToken': subscription.endpoint,
        'secretKey': subscription.authKey,
        'publicKey': subscription.publicKey,
      });
      await TokenStorage.writeSecure(_endpointKey, subscription.endpoint);
      logger.i('WebPush: подписка зарегистрирована');
    } finally {
      await socket.close();
    }
  }

  Future<void> signOut() async {
    await cancelAuth();
    await TokenStorage.deleteSecure(_tokenKey);
    await TokenStorage.deleteSecure(_endpointKey);
  }

  MaxWebSocketSession _requireSocket() {
    final socket = _authSocket;
    if (socket == null) {
      throw const MaxWebException('сессия входа потеряна, начните заново');
    }
    return socket;
  }

  WebPushAuthStep _stepFrom(Map<Object?, Object?> payload) {
    final attrs = payload['tokenAttrs'];
    if (attrs is Map) {
      final login = attrs['LOGIN'];
      if (login is Map) {
        final token = login['token'];
        if (token is String && token.isNotEmpty) {
          return WebPushAuthStep(loginToken: token);
        }
      }
    }

    final challenge = payload['passwordChallenge'];
    if (challenge is Map) {
      final trackId = challenge['trackId'];
      if (trackId is String && trackId.isNotEmpty) {
        final hint = challenge['hint'];
        return WebPushAuthStep(
          passwordChallenge: WebPushPasswordChallenge(
            trackId: trackId,
            hint: hint is String && hint.isNotEmpty ? hint : null,
          ),
        );
      }
    }

    throw const MaxWebException('сервер не вернул ни токен, ни запрос пароля');
  }

  Map<Object?, Object?> _asMap(Object? payload, String step) {
    if (payload is Map<Object?, Object?>) return payload;
    throw MaxWebException('$step: неожиданный ответ сервера');
  }

  Duration _durationFrom(Object? value, Duration fallback) {
    if (value is int && value > 0) return Duration(milliseconds: value);
    return fallback;
  }

  Future<String> _safariUserAgent() async {
    var release = '18_5';
    var version = '18.5';

    if (Platform.isIOS) {
      try {
        final info = await DeviceInfoPlugin().iosInfo;
        final systemVersion = info.systemVersion;
        if (systemVersion.isNotEmpty) {
          version = systemVersion;
          release = systemVersion.replaceAll('.', '_');
        }
      } catch (e) {
        logger.w('WebPush: не удалось прочитать версию iOS ($e)');
      }
    }

    return 'Mozilla/5.0 (iPhone; CPU iPhone OS $release like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/$version '
        'Mobile/15E148 Safari/604.1';
  }

  String _browserScreen() {
    final view = PlatformDispatcher.instance.views.first;
    final ratio = view.devicePixelRatio;
    final height = (view.physicalSize.height / ratio).round();
    final width = (view.physicalSize.width / ratio).round();
    return '${height}x$width ${ratio.toStringAsFixed(1)}x';
  }
}

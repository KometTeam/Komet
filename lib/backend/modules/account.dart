import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/utils/logger.dart';

enum AuthRequestType {
  startAuth('START_AUTH'),
  resend('RESEND'),
  checkCode('CHECK_CODE'),
  register('REGISTER');

  const AuthRequestType(this.value);
  final String value;
}

class RequestCodeResult {
  final String token;

  const RequestCodeResult({required this.token});
}

class VerifyCodeResult {
  final Map<dynamic, dynamic> payload;

  const VerifyCodeResult({required this.payload});

  String? get loginToken => _nestedToken('LOGIN');

  String? get registerToken => _nestedToken('REGISTER');

  bool get requiresPassword => payload['passwordChallenge'] != null;

  Map<dynamic, dynamic>? get passwordChallenge {
    final c = payload['passwordChallenge'];
    return c is Map ? c.cast<dynamic, dynamic>() : null;
  }

  String? _nestedToken(String key) {
    final attrs = payload['tokenAttrs'];
    if (attrs is! Map) return null;
    final entry = attrs[key];
    if (entry is! Map) return null;
    return entry['token'] as String?;
  }
}

/// Поток авторизации по номеру телефона:
/// 1. [requestCode] → сервер шлёт SMS, возвращает временный токен.
/// 2. [verifyCode]  → клиент отправляет код + токен, получает токен сессии.
///
/// При необходимости повторной отправки SMS используйте [resendCode].
class AccountModule {
  final Api _api;

  AccountModule(this._api);

  Future<RequestCodeResult> requestCode(
    String phone, {
    String language = 'ru',
  }) =>
      _requestCodeInternal(phone, AuthRequestType.startAuth, language);

  Future<RequestCodeResult> resendCode(
    String phone, {
    String language = 'ru',
  }) =>
      _requestCodeInternal(phone, AuthRequestType.resend, language);

  Future<VerifyCodeResult> verifyCode(String code, String token) async {
    _ensureOnline();

    final payload = <dynamic, dynamic>{
      'token': token,
      'verifyCode': code,
      'authTokenType': AuthRequestType.checkCode.value,
    };

    logger.i('Отправка OTP-кода (opcode=${Opcode.auth})');

    final packet = await _api.sendRequest(Opcode.auth, payload);

    _checkPacketError(packet, 'verifyCode');

    final data = packet.payload;
    if (data is! Map) {
      throw Exception('verifyCode: неожиданный тип payload: ${data.runtimeType}');
    }

    return VerifyCodeResult(payload: data.cast<dynamic, dynamic>());
  }

  Future<RequestCodeResult> _requestCodeInternal(
    String phone,
    AuthRequestType type,
    String language,
  ) async {
    _ensureOnline();

    final payload = <dynamic, dynamic>{
      'phone': phone,
      'type': type.value,
      'language': language,
    };

    logger.i('Запрос OTP-кода: phone=$phone type=${type.value}');

    final packet = await _api.sendRequest(Opcode.authRequest, payload);

    _checkPacketError(packet, 'requestCode');

    final data = packet.payload;
    if (data is! Map) {
      throw Exception('requestCode: неожиданный тип payload: ${data.runtimeType}');
    }

    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw Exception('requestCode: отсутствует token в ответе сервера');
    }

    logger.i('OTP-код запрошен, получен временный токен');
    return RequestCodeResult(token: token);
  }

  void _ensureOnline() {
    if (_api.state != SessionState.online) {
      throw StateError(
        'AccountModule: сессия не онлайн (текущее состояние: ${_api.state.name})',
      );
    }
  }

  void _checkPacketError(Packet packet, String method) {
    if (packet.isError) {
      final errMsg = packet.payload is Map
          ? (packet.payload as Map)['message'] ?? packet.payload.toString()
          : packet.payload?.toString() ?? 'unknown error';
      throw Exception('$method: ошибка от сервера — $errMsg');
    }
  }
}

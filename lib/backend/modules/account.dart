import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import 'chats.dart';

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

  /// trackId из passwordChallenge — передаётся в [AccountModule.checkPassword].
  String? get challengeTrackId => passwordChallenge?['trackId'] as String?;

  /// Подсказка к паролю из passwordChallenge.
  String? get challengeHint => passwordChallenge?['hint'] as String?;

  int? get accountId {
    final profileData = payload['profile'];
    if (profileData is! Map) return null;
    final contact = profileData['contact'];
    if (contact is! Map) return null;
    return contact['id'] as int?;
  }

  String? _nestedToken(String key) {
    final attrs = payload['tokenAttrs'];
    if (attrs is! Map) return null;
    final entry = attrs[key];
    if (entry is! Map) return null;
    return entry['token'] as String?;
  }
}

class TwoFactorResult {
  final String loginToken;

  const TwoFactorResult({required this.loginToken});
}

/// При отсутствии [LoginSyncParams] в [AccountModule.login] сервер вернёт
/// полный снимок данных (cold start), иначе только дельту (warm start).
class LoginSyncParams {
  final int chatsSync;
  final int contactsSync;
  final int callsSync;
  final int draftsSync;
  final int bannersSync;
  final int presenceSync;
  final int lastLogin;
  final String? configHash;
  final String? chatCacheFingerprint;

  const LoginSyncParams({
    required this.chatsSync,
    required this.contactsSync,
    required this.callsSync,
    required this.draftsSync,
    required this.bannersSync,
    required this.presenceSync,
    required this.lastLogin,
    this.configHash,
    this.chatCacheFingerprint,
  });

  static Future<LoginSyncParams?> fromDatabase(int accountId) async {
    final values = await AppDatabase.getAllSyncValues(accountId);
    final lastLogin = values[SyncKey.lastLogin];
    if (lastLogin == null) return null;

    return LoginSyncParams(
      chatsSync: int.tryParse(values[SyncKey.chatsSync] ?? '') ?? 0,
      contactsSync: int.tryParse(values[SyncKey.contactsSync] ?? '') ?? 0,
      callsSync: int.tryParse(values[SyncKey.callsSync] ?? '') ?? 0,
      draftsSync: int.tryParse(values[SyncKey.draftsSync] ?? '') ?? 0,
      bannersSync: int.tryParse(values[SyncKey.bannersSync] ?? '') ?? 0,
      presenceSync: int.tryParse(values[SyncKey.presenceSync] ?? '') ?? -1,
      lastLogin: int.parse(lastLogin),
      configHash: values[SyncKey.configHash],
      chatCacheFingerprint: values[SyncKey.chatCacheFingerprint],
    );
  }
}

class LoginResult {
  final ProfileData profile;
  final String? updatedToken;
  final int serverTime;

  const LoginResult({
    required this.profile,
    required this.updatedToken,
    required this.serverTime,
  });
}

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

    final result = VerifyCodeResult(payload: data.cast<dynamic, dynamic>());

    final sessionToken = result.loginToken ?? result.registerToken;
    final accountId = result.accountId;

    if (sessionToken != null && accountId != null) {
      await TokenStorage.saveToken(sessionToken, accountId);
      await TokenStorage.setActiveAccount(accountId);
      logger.i('Токен аккаунта $accountId сохранён, установлен активным');
    }

    return result;
  }

  Future<LoginResult> login({
    int? accountId,
    String? token,
    LoginSyncParams? syncParams,
  }) async {
    _ensureOnline();

    final resolvedAccountId = accountId ?? await TokenStorage.getActiveAccountId();
    if (resolvedAccountId == null) {
      throw StateError('login: нет активного аккаунта');
    }

    final authToken = token ?? await TokenStorage.readToken(resolvedAccountId);
    if (authToken == null) {
      throw StateError('login: нет токена для аккаунта $resolvedAccountId');
    }

    final resolvedSyncParams =
        syncParams ?? await LoginSyncParams.fromDatabase(resolvedAccountId);

    final requestPayload = _buildLoginPayload(authToken, resolvedSyncParams);

    logger.i('LOGIN opcode=${Opcode.login} '
        'account=$resolvedAccountId warm=${resolvedSyncParams != null}');

    final packet = await _api.sendRequest(Opcode.login, requestPayload);

    _checkPacketError(packet, 'login');

    final data = packet.payload;
    if (data is! Map) {
      throw Exception('login: неожиданный тип payload: ${data.runtimeType}');
    }

    return _processLoginResponse(
      data.cast<dynamic, dynamic>(),
      resolvedAccountId,
    );
  }

  Future<ProfileData> switchAccount(int accountId) async {
    final profile = await AppDatabase.loadProfile(accountId);
    if (profile == null) {
      throw StateError('switchAccount: аккаунт $accountId не найден в базе');
    }

    await AppDatabase.setActiveAccount(accountId);
    await TokenStorage.setActiveAccount(accountId);

    logger.i('Активный аккаунт переключён на $accountId');
    return profile;
  }

  Future<void> removeAccount(int accountId) async {
    await AppDatabase.deleteAccount(accountId);
    await TokenStorage.deleteAccount(accountId);
    logger.i('Аккаунт $accountId удалён локально');
  }

  /// Проверяет 2FA-пароль (opcode 115).
  ///
  /// [trackId] — из [VerifyCodeResult.challengeTrackId].
  /// [accountId] — из [VerifyCodeResult.accountId].
  ///
  /// При неверном пароле бросает [Exception].
  /// При успехе сохраняет токен и устанавливает аккаунт активным.
  Future<TwoFactorResult> checkPassword({
    required String password,
    required String trackId,
    required int accountId,
  }) async {
    _ensureOnline();

    final payload = <dynamic, dynamic>{
      'trackId': trackId,
      'password': password,
    };

    logger.i('Проверка 2FA-пароля для аккаунта $accountId');

    final packet = await _api.sendRequest(
      Opcode.authLoginCheckPassword,
      payload,
    );

    _checkPacketError(packet, 'checkPassword');

    final data = packet.payload;
    if (data is! Map) {
      throw Exception('checkPassword: неожиданный тип payload: ${data.runtimeType}');
    }

    if (data['error'] != null) {
      throw Exception('checkPassword: неверный пароль');
    }

    final tokenAttrs = data['tokenAttrs'];
    if (tokenAttrs is! Map) {
      throw Exception('checkPassword: отсутствует tokenAttrs в ответе');
    }

    final loginEntry = tokenAttrs['LOGIN'];
    if (loginEntry is! Map) {
      throw Exception('checkPassword: отсутствует tokenAttrs.LOGIN в ответе');
    }

    final loginToken = loginEntry['token'] as String?;
    if (loginToken == null || loginToken.isEmpty) {
      throw Exception('checkPassword: отсутствует токен в ответе');
    }

    await TokenStorage.saveToken(loginToken, accountId);
    await TokenStorage.setActiveAccount(accountId);
    logger.i('2FA пройдена, токен аккаунта $accountId сохранён');

    return TwoFactorResult(loginToken: loginToken);
  }

  Map<dynamic, dynamic> _buildLoginPayload(
    String token,
    LoginSyncParams? sync,
  ) {
    final payload = <dynamic, dynamic>{
      'token': token,
      'interactive': true,
      'exp': {'chatsCountGroups': '0b32'},
    };

    if (sync != null) {
      payload['presenceSync'] = sync.presenceSync;
      payload['chatsSync'] = sync.chatsSync;
      payload['contactsSync'] = sync.contactsSync;
      payload['callsSync'] = sync.callsSync;
      payload['draftsSync'] = sync.draftsSync;
      payload['bannersSync'] = sync.bannersSync;
      payload['lastLogin'] = sync.lastLogin;
      if (sync.configHash != null) payload['configHash'] = sync.configHash;
      if (sync.chatCacheFingerprint != null) {
        payload['chatCacheFingerprint'] = sync.chatCacheFingerprint;
      }
    } else {
      payload['presenceSync'] = 0;
    }

    return payload;
  }

  Future<LoginResult> _processLoginResponse(
    Map<dynamic, dynamic> data,
    int accountId,
  ) async {
    final serverTime =
        (data['time'] as int?) ?? DateTime.now().millisecondsSinceEpoch;

    final updatedToken = data['token'] as String?;
    if (updatedToken != null) {
      await TokenStorage.saveToken(updatedToken, accountId);
      logger.i('Обновлённый токен аккаунта $accountId сохранён');
    }

    final profileMap = data['profile'];
    if (profileMap is! Map) {
      throw Exception('login: отсутствует profile в ответе');
    }
    final contact = profileMap['contact'];
    if (contact is! Map) {
      throw Exception('login: отсутствует profile.contact в ответе');
    }
    final profile = ProfileData.fromServerMap(contact.cast<dynamic, dynamic>());
    await AppDatabase.saveProfile(profile);
    await AppDatabase.setActiveAccount(profile.id);
    logger.i('Профиль сохранён: id=${profile.id}, name=${profile.firstName}');

    await _saveSyncState(data, serverTime, profile.id);
    await ChatsModule.syncFromLoginPayload(data, profile.id, profile.id);

    return LoginResult(
      profile: profile,
      updatedToken: updatedToken,
      serverTime: serverTime,
    );
  }

  Future<void> _saveSyncState(
    Map<dynamic, dynamic> data,
    int serverTime,
    int accountId,
  ) async {
    final ts = serverTime.toString();

    Future<void> set(String key, String value) =>
        AppDatabase.setSyncValue(accountId, key, value);

    await set(SyncKey.serverTime, ts);
    await set(SyncKey.lastLogin, ts);
    await set(SyncKey.chatsSync, ts);
    await set(SyncKey.contactsSync, ts);
    await set(SyncKey.callsSync, ts);
    await set(SyncKey.draftsSync, ts);
    await set(SyncKey.bannersSync, ts);
    await set(SyncKey.presenceSync, '-1');

    final config = data['config'];
    if (config is Map) {
      final hash = config['hash'] as String?;
      if (hash != null) await set(SyncKey.configHash, hash);
    }
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

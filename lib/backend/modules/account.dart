import 'dart:async';
import 'dart:convert';
import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import 'chats.dart';
import 'contacts.dart';
import 'folders.dart';

class PrivacyConfig {
  final String searchByPhone;
  final String incomingCall;
  final bool doubleTapReactionDisabled;
  final bool safeModeNoPin;
  final String? doubleTapReactionValue;
  final String familyProtection;
  final bool pushDetails;
  final bool hidden;
  final String chatsInvite;
  final bool pushNewContacts;
  final bool unsafeFiles;
  final String inactiveTtl;
  final bool showReadMark;
  final bool altKeyboard;
  final bool contentLevelAccess;
  final String stickersSuggest;
  final bool safeMode;
  final bool audioTranscriptionEnabled;
  final String hash;

  const PrivacyConfig({
    required this.searchByPhone,
    required this.incomingCall,
    required this.doubleTapReactionDisabled,
    required this.safeModeNoPin,
    this.doubleTapReactionValue,
    required this.familyProtection,
    required this.pushDetails,
    required this.hidden,
    required this.chatsInvite,
    required this.pushNewContacts,
    required this.unsafeFiles,
    required this.inactiveTtl,
    required this.showReadMark,
    required this.altKeyboard,
    required this.contentLevelAccess,
    required this.stickersSuggest,
    required this.safeMode,
    required this.audioTranscriptionEnabled,
    required this.hash,
  });

  factory PrivacyConfig.fromMap(Map<dynamic, dynamic> map) {
    return PrivacyConfig(
      searchByPhone: map['SEARCH_BY_PHONE']?.toString() ?? 'ALL',
      incomingCall: map['INCOMING_CALL']?.toString() ?? 'CONTACTS',
      doubleTapReactionDisabled: map['DOUBLE_TAP_REACTION_DISABLED'] ?? false,
      safeModeNoPin: map['SAFE_MODE_NO_PIN'] ?? false,
      doubleTapReactionValue: map['DOUBLE_TAP_REACTION_VALUE']?.toString(),
      familyProtection: map['FAMILY_PROTECTION']?.toString() ?? 'OFF',
      pushDetails: map['PUSH_DETAILS'] ?? false,
      hidden: map['HIDDEN'] ?? true,
      chatsInvite: map['CHATS_INVITE']?.toString() ?? 'CONTACTS',
      pushNewContacts: map['PUSH_NEW_CONTACTS'] ?? false,
      unsafeFiles: map['UNSAFE_FILES'] ?? true,
      inactiveTtl: map['INACTIVE_TTL']?.toString() ?? '6M',
      showReadMark: map['SHOW_READ_MARK'] ?? true,
      altKeyboard: map['ALT_KEYBOARD'] ?? false,
      contentLevelAccess: map['CONTENT_LEVEL_ACCESS'] ?? false,
      stickersSuggest: map['STICKERS_SUGGEST']?.toString() ?? 'ON',
      safeMode: map['SAFE_MODE'] ?? false,
      audioTranscriptionEnabled: map['AUDIO_TRANSCRIPTION_ENABLED'] ?? true,
      hash: map['hash']?.toString() ?? '',
    );
  }

  String toJson() => jsonEncode({
    'SEARCH_BY_PHONE': searchByPhone,
    'INCOMING_CALL': incomingCall,
    'DOUBLE_TAP_REACTION_DISABLED': doubleTapReactionDisabled,
    'SAFE_MODE_NO_PIN': safeModeNoPin,
    'DOUBLE_TAP_REACTION_VALUE': doubleTapReactionValue,
    'FAMILY_PROTECTION': familyProtection,
    'PUSH_DETAILS': pushDetails,
    'HIDDEN': hidden,
    'CHATS_INVITE': chatsInvite,
    'PUSH_NEW_CONTACTS': pushNewContacts,
    'UNSAFE_FILES': unsafeFiles,
    'INACTIVE_TTL': inactiveTtl,
    'SHOW_READ_MARK': showReadMark,
    'ALT_KEYBOARD': altKeyboard,
    'CONTENT_LEVEL_ACCESS': contentLevelAccess,
    'STICKERS_SUGGEST': stickersSuggest,
    'SAFE_MODE': safeMode,
    'AUDIO_TRANSCRIPTION_ENABLED': audioTranscriptionEnabled,
    'hash': hash,
  });

  factory PrivacyConfig.fromJson(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return PrivacyConfig.fromMap(map);
    } catch (_) {
      return PrivacyConfig.empty();
    }
  }

  static PrivacyConfig empty() {
    return const PrivacyConfig(
      searchByPhone: 'ALL',
      incomingCall: 'CONTACTS',
      doubleTapReactionDisabled: false,
      safeModeNoPin: false,
      familyProtection: 'OFF',
      pushDetails: false,
      hidden: true,
      chatsInvite: 'CONTACTS',
      pushNewContacts: false,
      unsafeFiles: true,
      inactiveTtl: '6M',
      showReadMark: true,
      altKeyboard: false,
      contentLevelAccess: false,
      stickersSuggest: 'ON',
      safeMode: false,
      audioTranscriptionEnabled: true,
      hash: '',
    );
  }
}

class BlockedContact {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? baseUrl;
  final int? photoId;
  final String status;
  final int registrationTime;
  final int updateTime;

  const BlockedContact({
    required this.id,
    this.firstName,
    this.lastName,
    this.baseUrl,
    this.photoId,
    required this.status,
    required this.registrationTime,
    required this.updateTime,
  });

  factory BlockedContact.fromMap(Map<dynamic, dynamic> map) {
    String? firstName;
    String? lastName;
    final names = map['names'] as List?;
    if (names != null && names.isNotEmpty) {
      for (final n in names) {
        if (n is Map) {
          firstName = n['firstName'] as String?;
          lastName = n['lastName'] as String?;
          if (n['type'] == 'ONEME') break;
        }
      }
    }

    return BlockedContact(
      id: map['id'] as int? ?? 0,
      firstName: firstName,
      lastName: lastName,
      baseUrl: map['baseUrl'] as String?,
      photoId: map['photoId'] as int?,
      status: map['status']?.toString() ?? 'BLOCKED',
      registrationTime: map['registrationTime'] as int? ?? 0,
      updateTime: map['updateTime'] as int? ?? 0,
    );
  }
}

class TwoFactorDetails {
  final bool enabled;
  final String? email;
  final String? hint;

  const TwoFactorDetails({required this.enabled, this.email, this.hint});
}

enum AuthRequestType {
  startAuth('START_AUTH'),
  resend('RESEND'),
  checkCode('CHECK_CODE'),
  register('REGISTER');

  const AuthRequestType(this.value);
  final String value;
}

enum LoginStatus { idle, loading, success, error }

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

  String? get challengeTrackId => passwordChallenge?['trackId'] as String?;

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

class SessionInfo {
  final int? id;
  final String client;
  final String location;
  final bool current;
  final int time;
  final String info;

  const SessionInfo({
    this.id,
    required this.client,
    required this.location,
    required this.current,
    required this.time,
    required this.info,
  });

  factory SessionInfo.fromMap(Map<dynamic, dynamic> map) {
    return SessionInfo(
      id: map['id'] is int
          ? map['id']
          : (int.tryParse(map['id']?.toString() ?? '')),
      client: map['client'] ?? '',
      location: map['location'] ?? '',
      current: map['current'] ?? false,
      time: map['time'] ?? 0,
      info: map['info'] ?? '',
    );
  }

  int get uniqueId => Object.hash(id, client, time, info);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          client == other.client &&
          location == other.location &&
          current == other.current &&
          time == other.time &&
          info == other.info;

  @override
  int get hashCode => Object.hash(id, client, location, current, time, info);
}

class LoginResult {
  final ProfileData profile;
  final String? updatedToken;
  final int serverTime;
  final Map<dynamic, dynamic> raw;

  const LoginResult({
    required this.profile,
    required this.updatedToken,
    required this.serverTime,
    required this.raw,
  });
}

class AccountModule {
  final Api _api;
  final _loginStatusController = StreamController<LoginStatus>.broadcast();

  AccountModule(this._api);

  Stream<LoginStatus> get loginStatusStream => _loginStatusController.stream;

  Future<PrivacyConfig> getPrivacyConfig() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId != null) {
      final saved = await AppDatabase.getPrivacyConfig(accountId);
      if (saved != null) {
        return PrivacyConfig.fromJson(saved);
      }
    }
    return PrivacyConfig.empty();
  }

  Future<List<BlockedContact>> getBlockedContacts() async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.contactList, {
      'status': 'BLOCKED',
      'count': 100,
      'from': 0,
    });
    _checkPacketError(packet, 'getBlockedContacts');
    final data = packet.payload;
    if (data is! Map) {
      throw Exception(
        'getBlockedContacts: неожиданный тип payload: ${data.runtimeType}',
      );
    }
    final contacts = data['contacts'] as List?;
    if (contacts == null) return [];
    return contacts
        .whereType<Map>()
        .map((c) => BlockedContact.fromMap(c.cast<dynamic, dynamic>()))
        .toList();
  }

  Future<PrivacyConfig> updatePrivacyConfig(
    Map<String, dynamic> settings,
  ) async {
    _ensureOnline();
    final payload = <dynamic, dynamic>{
      'settings': {'user': settings},
    };
    final packet = await _api.sendRequest(Opcode.config, payload);
    _checkPacketError(packet, 'updatePrivacyConfig');
    final data = packet.payload;
    if (data is! Map) {
      throw Exception(
        'updatePrivacyConfig: неожиданный тип payload: ${data.runtimeType}',
      );
    }
    final user = data['user'];
    if (user is! Map) {
      throw Exception('updatePrivacyConfig: отсутствует user в payload');
    }
    final config = PrivacyConfig.fromMap(user.cast<dynamic, dynamic>());
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId != null) {
      await AppDatabase.savePrivacyConfig(accountId, config.toJson());
    }
    return config;
  }

  // 2FA Creation (when not set)
  Future<String> create2faTrack() async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.authCreateTrack, {'type': 0});
    _checkPacketError(packet, 'create2faTrack');
    final data = packet.payload;
    if (data is! Map) {
      throw Exception(
        'create2faTrack: неожиданный тип payload: ${data.runtimeType}',
      );
    }
    final trackId = data['trackId'] as String?;
    if (trackId == null) {
      throw Exception('create2faTrack: отсутствует trackId');
    }
    return trackId;
  }

  Future<void> set2faPassword(String trackId, String password) async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.authValidatePassword, {
      'trackId': trackId,
      'password': password,
    });
    _checkPacketError(packet, 'set2faPassword');
    if (packet.payload != null && packet.payload is! Map) {
      throw Exception('set2faPassword: неожиданный ответ');
    }
  }

  Future<void> set2faHint(String trackId, String hint) async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.authValidateHint, {
      'trackId': trackId,
      'hint': hint,
    });
    _checkPacketError(packet, 'set2faHint');
    if (packet.payload != null && packet.payload is! Map) {
      throw Exception('set2faHint: неожиданный ответ');
    }
  }

  Future<int> verify2faEmail(String trackId, String email) async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.authVerifyEmail, {
      'trackId': trackId,
      'email': email,
    });
    _checkPacketError(packet, 'verify2faEmail');
    final data = packet.payload;
    if (data is! Map) {
      throw Exception(
        'verify2faEmail: неожиданный тип payload: ${data.runtimeType}',
      );
    }
    final blockingDuration = data['blockingDuration'] as int? ?? 60;
    return blockingDuration;
  }

  Future<String> verify2faCode(String trackId, String code) async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.authCheckEmail, {
      'trackId': trackId,
      'verifyCode': code,
    });
    _checkPacketError(packet, 'verify2faCode');
    final data = packet.payload;
    if (data is! Map) {
      throw Exception(
        'verify2faCode: неожиданный тип payload: ${data.runtimeType}',
      );
    }
    final email = data['email'] as String? ?? '';
    return email;
  }

  Future<ProfileData> confirm2fa({
    required String trackId,
    required String password,
    String? hint,
  }) async {
    _ensureOnline();
    final payload = <dynamic, dynamic>{
      'expectedCapabilities': [0, 3, 4],
      'trackId': trackId,
      'password': password,
    };
    if (hint != null) payload['hint'] = hint;
    final packet = await _api.sendRequest(Opcode.authSet2fa, payload);
    _checkPacketError(packet, 'confirm2fa');
    return _processProfileUpdate(packet);
  }

  // 2FA Management (when already set)
  Future<String> enter2faPanel() async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.authCreateTrack, {'type': 0});
    _checkPacketError(packet, 'enter2faPanel');
    final data = packet.payload;
    if (data is! Map) {
      throw Exception(
        'enter2faPanel: неожиданный тип payload: ${data.runtimeType}',
      );
    }
    final trackId = data['trackId'] as String?;
    if (trackId == null) {
      throw Exception('enter2faPanel: отсутствует trackId');
    }
    return trackId;
  }

  Future<TwoFactorDetails> get2faDetails(String trackId) async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.auth2faDetails, {
      'trackId': trackId,
    });
    _checkPacketError(packet, 'get2faDetails');
    final data = packet.payload;
    if (data is! Map) {
      throw Exception(
        'get2faDetails: неожиданный тип payload: ${data.runtimeType}',
      );
    }
    final password = data['password'] as Map?;
    return TwoFactorDetails(
      enabled: password?['enabled'] ?? false,
      email: password?['email'] as String?,
      hint: password?['hint'] as String?,
    );
  }

  Future<void> check2faPassword(String trackId, String password) async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.authLoginCheckPassword, {
      'trackId': trackId,
      'password': password,
    });
    _checkPacketError(packet, 'check2faPassword');
    final data = packet.payload;
    if (data is Map && data['error'] != null) {
      throw Exception('Неверный пароль');
    }
  }

  Future<ProfileData> update2faPassword({
    required String trackId,
    required String newPassword,
    String? hint,
  }) async {
    _ensureOnline();
    final validatePacket = await _api.sendRequest(Opcode.authValidatePassword, {
      'trackId': trackId,
      'password': newPassword,
    });
    _checkPacketError(validatePacket, 'update2faPassword: validate');
    if (validatePacket.payload != null && validatePacket.payload is! Map) {
      throw Exception('update2faPassword: неожиданный ответ при валидации');
    }

    if (hint != null) {
      final hintPacket = await _api.sendRequest(Opcode.authValidateHint, {
        'trackId': trackId,
        'hint': hint,
      });
      _checkPacketError(hintPacket, 'update2faPassword: hint');
    }

    final payload = <dynamic, dynamic>{
      'expectedCapabilities': [1, 3],
      'trackId': trackId,
      'password': newPassword,
    };
    if (hint != null) payload['hint'] = hint;

    final packet = await _api.sendRequest(Opcode.authSet2fa, payload);
    _checkPacketError(packet, 'update2faPassword');
    return _processProfileUpdate(packet);
  }

  Future<ProfileData> update2faEmail({
    required String trackId,
    required String email,
    required String code,
  }) async {
    _ensureOnline();
    final verifyPacket = await _api.sendRequest(Opcode.authVerifyEmail, {
      'trackId': trackId,
      'email': email,
    });
    _checkPacketError(verifyPacket, 'update2faEmail: verify');

    final codePacket = await _api.sendRequest(Opcode.authCheckEmail, {
      'trackId': trackId,
      'verifyCode': code,
    });
    _checkPacketError(codePacket, 'update2faEmail: code');

    final payload = <dynamic, dynamic>{
      'expectedCapabilities': [4],
      'trackId': trackId,
    };
    final packet = await _api.sendRequest(Opcode.authSet2fa, payload);
    _checkPacketError(packet, 'update2faEmail');
    return _processProfileUpdate(packet);
  }

  Future<ProfileData> remove2fa(String trackId) async {
    _ensureOnline();
    final payload = <dynamic, dynamic>{
      'expectedCapabilities': [5],
      'trackId': trackId,
      'remove2fa': true,
    };
    final packet = await _api.sendRequest(Opcode.authSet2fa, payload);
    _checkPacketError(packet, 'remove2fa');
    return _processProfileUpdate(packet);
  }

  Future<ProfileData> _processProfileUpdate(Packet packet) async {
    _api.registerPushHandler(Opcode.notifProfile, (p) {});
    await for (final push in _api.pushStream.where(
      (p) => p.opcode == Opcode.notifProfile,
    )) {
      final payload = push.payload;
      if (payload is Map) {
        final profile = payload['profile'];
        if (profile is Map) {
          final contact = profile['contact'];
          if (contact is Map) {
            return ProfileData.fromServerMap(contact.cast<dynamic, dynamic>());
          }
        }
      }
    }
    throw Exception('Не удалось получить обновлённый профиль');
  }

  Future<RequestCodeResult> requestCode(
    String phone, {
    String language = 'ru',
  }) => _requestCodeInternal(phone, AuthRequestType.startAuth, language);

  Future<RequestCodeResult> resendCode(
    String phone, {
    String language = 'ru',
  }) => _requestCodeInternal(phone, AuthRequestType.resend, language);

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
      throw Exception(
        'verifyCode: неожиданный тип payload: ${data.runtimeType}',
      );
    }

    final result = VerifyCodeResult(payload: data.cast<dynamic, dynamic>());

    final sessionToken = result.loginToken ?? result.registerToken;
    final accountId = result.accountId;

    if (sessionToken != null && accountId != null) {
      await TokenStorage.saveToken(sessionToken, accountId);
      await TokenStorage.setActiveAccount(accountId);
    }

    return result;
  }

  Future<LoginResult> login({
    int? accountId,
    String? token,
    LoginSyncParams? syncParams,
  }) async {
    _ensureOnline();

    final resolvedAccountId =
        accountId ?? await TokenStorage.getActiveAccountId();
    if (resolvedAccountId == null) {
      throw StateError('login: нет активного аккаунта');
    }

    final authToken = token ?? await TokenStorage.readToken(resolvedAccountId);
    if (authToken == null) {
      throw StateError('login: нет токена для аккаунта $resolvedAccountId');
    }

    final requestPayload = _buildLoginPayload(authToken, syncParams);

    _loginStatusController.add(LoginStatus.loading);
    try {
      final packet = await _api.sendRequest(Opcode.login, requestPayload);

      _checkPacketError(packet, 'login');

      final data = packet.payload;
      if (data is! Map) {
        throw Exception('login: неожиданный тип payload: ${data.runtimeType}');
      }

      final result = await _processLoginResponse(
        data.cast<dynamic, dynamic>(),
        resolvedAccountId,
      );
      _loginStatusController.add(LoginStatus.success);
      return result;
    } catch (e) {
      _loginStatusController.add(LoginStatus.error);
      rethrow;
    }
  }

  Future<List<SessionInfo>> getSessions() async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.sessionsInfo, {});
    _checkPacketError(packet, 'getSessions');
    final data = packet.payload;
    if (data is! Map || data['sessions'] is! List) return [];
    final sessions = data['sessions'] as List;
    return sessions
        .map((s) => SessionInfo.fromMap(s as Map<dynamic, dynamic>))
        .toList();
  }

  Future<void> terminateOtherSessions() async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.sessionsClose, {});
    _checkPacketError(packet, 'terminateOtherSessions');
  }

  Future<void> authorizeWebQrLogin(String qrLink) async {
    _ensureOnline();
    final link = qrLink.trim();
    if (link.isEmpty) {
      throw ArgumentError('Пустая ссылка из QR');
    }

    await _api.sendRequest(Opcode.ping, {'interactive': true});
    await _api.sendRequest(Opcode.sessionsInfo, {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final packet = await _api.sendRequest(Opcode.authQrApprove, {
      'qrLink': link,
    });
    _checkPacketError(packet, 'authorizeWebQrLogin');
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

  Future<TwoFactorResult> checkPassword({
    required String password,
    required String trackId,
  }) async {
    _ensureOnline();

    final payload = <dynamic, dynamic>{
      'trackId': trackId,
      'password': password,
    };

    logger.i('Проверка 2FA-пароля');

    final packet = await _api.sendRequest(
      Opcode.authLoginCheckPassword,
      payload,
    );

    _checkPacketError(packet, 'checkPassword');

    final data = packet.payload;
    if (data is! Map) {
      throw Exception(
        'checkPassword: неожиданный тип payload: ${data.runtimeType}',
      );
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

    final profileData = data['profile'];
    int? accountId;
    if (profileData is Map) {
      final contact = profileData['contact'];
      if (contact is Map) {
        accountId = contact['id'] as int?;
      }
    }

    if (accountId != null) {
      await TokenStorage.saveToken(loginToken, accountId);
      await TokenStorage.setActiveAccount(accountId);
      logger.i('2FA пройдена, токен аккаунта $accountId сохранён');
    } else {
      logger.w('2FA пройдена, но accountId не получен из ответа');
    }

    return TwoFactorResult(loginToken: loginToken);
  }

  Map<dynamic, dynamic> _buildLoginPayload(
    String token,
    LoginSyncParams? sync,
  ) {
    final payload = <dynamic, dynamic>{
      'token': token,
      'interactive': true,
      if (_api.userAgent != null) 'userAgent': _api.userAgent,
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

    await _saveSyncState(data, serverTime, profile.id);
    await ContactsModule.syncFromLoginPayload(data, profile.id);
    await ChatsModule.syncFromLoginPayload(data, profile.id, profile.id);

    final config = data['config'];
    if (config is Map) {
      await FoldersModule.applyFromLoginConfig(
        profile.id,
        config.cast<dynamic, dynamic>(),
      );
    }
    try {
      await FoldersModule.syncFromServer(_api, profile.id);
    } catch (e) {
      logger.w('Папки чатов: $e');
    }

    return LoginResult(
      profile: profile,
      updatedToken: updatedToken,
      serverTime: serverTime,
      raw: data,
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
      throw Exception(
        'requestCode: неожиданный тип payload: ${data.runtimeType}',
      );
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
      final payload = packet.payload;
      if (payload is Map && payload['message'] == 'FAIL_LOGIN_TOKEN') {
        throw SessionExpiredException(messageFromErrorPayload(payload));
      }
      throw PacketError(messageFromErrorPayload(payload));
    }
  }
}

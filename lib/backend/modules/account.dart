import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../api.dart';
import '../../core/config/komet_settings.dart';
import '../../core/protocol/chat_cache_fingerprint.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/spoofing_service.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import 'chats.dart';
import 'complaints.dart';
import 'contacts.dart';
import 'folders.dart';
import 'messages.dart';
import 'webapp.dart';

import 'account/account_models.dart';
import 'account/privacy_module.dart';
import 'account/profile_module.dart';
import 'account/sessions_module.dart';
import 'account/two_factor_module.dart';
export 'account/account_models.dart';

String _normalizeAuthPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return '+$digits';
}

String _maskPhone(String phone) {
  if (phone.length <= 5) return '***';
  return '${phone.substring(0, 3)}***${phone.substring(phone.length - 2)}';
}

class AccountModule {
  final Api _api;
  late final SessionsModule _sessions = SessionsModule(_api);
  late final PrivacyModule _privacy = PrivacyModule(_api);
  late final ProfileModule _profile = ProfileModule(_api);
  late final TwoFactorModule _twoFactor = TwoFactorModule(_api, _profile);
  final _loginStatusController = StreamController<LoginStatus>.broadcast();
  bool _loggedIn = false;

  AccountModule(this._api) {
    _api.stateStream.listen((state) {
      if (state != SessionState.online) _loggedIn = false;
    });
  }

  Stream<LoginStatus> get loginStatusStream => _loginStatusController.stream;

  /// `true`, только когда сервер считает сессию ONLINE — после успешного
  /// login (opcode 19), а не просто после хэндшейка (opcode 6).
  bool get isLoggedIn => _loggedIn;

  Future<PrivacyConfig> getPrivacyConfig() => _privacy.getPrivacyConfig();

  Future<List<BlockedContact>> getBlockedContacts() =>
      _privacy.getBlockedContacts();

  Future<PrivacyConfig> updatePrivacyConfig(Map<String, dynamic> settings) =>
      _privacy.updatePrivacyConfig(settings);

  Future<PrivacyConfig> setChatsPushNotification(bool value) =>
      _privacy.setChatsPushNotification(value);

  Future<PrivacyConfig> setMessagePreview(bool value) =>
      _privacy.setMessagePreview(value);

  Future<PrivacyConfig> setNotificationSound(bool value) =>
      _privacy.setNotificationSound(value);

  Future<PrivacyConfig> setCallNotifications(bool value) =>
      _privacy.setCallNotifications(value);

  Future<PrivacyConfig> setNewContacts(bool value) =>
      _privacy.setNewContacts(value);

  Future<void> registerPushToken(String pushToken) =>
      _privacy.registerPushToken(pushToken);

  Future<void> unregisterPushToken(String pushToken) =>
      _privacy.unregisterPushToken(pushToken);

  Future<ProfileData> updateProfileName(String firstName, String? lastName) =>
      _profile.updateProfileName(firstName, lastName);

  Future<ProfileData> updateProfileAvatar(
    String photoToken, {
    String avatarType = 'USER_AVATAR',
  }) => _profile.updateProfileAvatar(photoToken, avatarType: avatarType);

  Future<String> getAvatarUploadUrl() => _profile.getAvatarUploadUrl();

  Future<ProfileData> removeProfilePhoto(int photoId) =>
      _profile.removeProfilePhoto(photoId);

  Future<String> create2faTrack() => _twoFactor.create2faTrack();

  Future<void> set2faPassword(String trackId, String password) =>
      _twoFactor.set2faPassword(trackId, password);

  Future<void> set2faHint(String trackId, String hint) =>
      _twoFactor.set2faHint(trackId, hint);

  Future<int> verify2faEmail(String trackId, String email) =>
      _twoFactor.verify2faEmail(trackId, email);

  Future<String> verify2faCode(String trackId, String code) =>
      _twoFactor.verify2faCode(trackId, code);

  Future<ProfileData> confirm2fa({
    required String trackId,
    required String password,
    String? hint,
    bool withEmail = true,
  }) => _twoFactor.confirm2fa(
    trackId: trackId,
    password: password,
    hint: hint,
    withEmail: withEmail,
  );

  Future<String> enter2faPanel() => _twoFactor.enter2faPanel();

  Future<TwoFactorDetails> get2faDetails(String trackId) =>
      _twoFactor.get2faDetails(trackId);

  Future<TwoFactorDetails> get2faStatus() => _twoFactor.get2faStatus();

  Future<void> check2faPassword(String trackId, String password) =>
      _twoFactor.check2faPassword(trackId, password);

  Future<ProfileData> update2faPassword({
    required String trackId,
    required String newPassword,
    String? hint,
  }) => _twoFactor.update2faPassword(
    trackId: trackId,
    newPassword: newPassword,
    hint: hint,
  );

  Future<ProfileData> commit2faEmailChange(String trackId) =>
      _twoFactor.commit2faEmailChange(trackId);

  Future<ProfileData> remove2fa(String trackId) =>
      _twoFactor.remove2fa(trackId);

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

    final data = _requireMapPayload(packet, 'verifyCode');

    final result = VerifyCodeResult(payload: data.cast<dynamic, dynamic>());

    final sessionToken = result.loginToken ?? result.registerToken;
    final verifiedProfile = _profileFromVerifyPayload(result.payload);
    final accountId = result.accountId ?? verifiedProfile?.id;

    if (sessionToken != null && accountId != null) {
      if (result.loginToken != null && verifiedProfile != null) {
        await AppDatabase.saveProfile(verifiedProfile, isActive: true);
      }
      await TokenStorage.saveToken(sessionToken, accountId);
      await TokenStorage.setActiveAccount(accountId);
      await SpoofingService.commitPendingSpoof(accountId);
    }

    return result;
  }

  ProfileData? _profileFromVerifyPayload(Map<dynamic, dynamic> payload) {
    final profileMap = payload['profile'];
    if (profileMap is! Map) return null;
    return ProfileData.fromServerProfile(profileMap.cast<dynamic, dynamic>());
  }

  Future<int> completeRegistration({
    required String token,
    required String firstName,
    String? lastName,
    int? photoId,
  }) async {
    _ensureOnline();

    final payload = <dynamic, dynamic>{
      'token': token,
      'tokenType': AuthRequestType.register.value,
      'firstName': firstName,
    };
    if (lastName != null && lastName.isNotEmpty) {
      payload['lastName'] = lastName;
    }
    if (photoId != null) {
      payload['photoId'] = photoId;
      payload['avatarType'] = 'PRESET_AVATAR';
    }

    logger.i('Завершение регистрации (opcode=${Opcode.authConfirm})');

    final packet = await _api.sendRequest(Opcode.authConfirm, payload);

    final data = _requireMapPayload(packet, 'completeRegistration');

    final profileMap = data['profile'];
    if (profileMap is! Map) {
      throw Exception('completeRegistration: отсутствует profile в ответе');
    }
    final contact = profileMap['contact'];
    if (contact is! Map) {
      throw Exception('completeRegistration: отсутствует profile.contact');
    }
    final accountId = contact['id'] as int?;
    if (accountId == null) {
      throw Exception('completeRegistration: отсутствует id аккаунта');
    }

    final profile = ProfileData.fromServerProfile(
      profileMap.cast<dynamic, dynamic>(),
    );
    await AppDatabase.saveProfile(profile, isActive: true);
    await TokenStorage.setActiveAccount(accountId);
    await SpoofingService.commitPendingSpoof(accountId);

    logger.i('Регистрация завершена, accountId=$accountId');
    return accountId;
  }

  Future<LoginResult> login({
    int? accountId,
    String? token,
    LoginSyncParams? syncParams,
  }) async {
    _ensureOnline();

    int? resolvedAccountId =
        accountId ?? await TokenStorage.getActiveAccountId();

    String? authToken = token;
    if (authToken == null) {
      if (resolvedAccountId == null) {
        throw StateError('login: нет активного аккаунта');
      }
      authToken = await TokenStorage.readToken(resolvedAccountId);
      if (authToken == null) {
        throw StateError('login: нет токена для аккаунта $resolvedAccountId');
      }
    }

    final requestPayload = buildLoginPayload(authToken, sync: syncParams);

    _loginStatusController.add(LoginStatus.loading);
    try {
      final packet = await _api.sendRequest(Opcode.login, requestPayload);

      final data = _requireMapPayload(packet, 'login');

      final dataMap = data.cast<dynamic, dynamic>();

      if (resolvedAccountId == null) {
        resolvedAccountId = extractAccountId(dataMap);
        if (resolvedAccountId == null) {
          logger.e(
            'login: accountId не найден в ответе; '
            '${describeResponseShape(dataMap)}',
          );
          throw Exception('login: не удалось определить accountId из ответа');
        }
        logger.i('login: accountId=$resolvedAccountId определён из ответа');
        await TokenStorage.saveToken(authToken, resolvedAccountId);
        await TokenStorage.setActiveAccount(resolvedAccountId);
        await SpoofingService.commitPendingSpoof(resolvedAccountId);
      }

      final result = await _processLoginResponse(dataMap, resolvedAccountId);
      _loggedIn = true;
      _loginStatusController.add(LoginStatus.success);
      return result;
    } catch (e) {
      _loginStatusController.add(LoginStatus.error);
      rethrow;
    }
  }

  Future<List<SessionInfo>> getSessions() => _sessions.getSessions();

  Future<void> terminateOtherSessions() => _sessions.terminateOtherSessions();

  Future<void> authorizeWebQrLogin(String qrLink) =>
      _sessions.authorizeWebQrLogin(qrLink);

  Future<void> beginAddAccount() async {
    final existing = await AppDatabase.loadAllProfiles();
    await SpoofingService.prepareNewAccountSpoof(
      existing.map((p) => p.id).toList(growable: false),
    );

    try {
      await _api.disconnect();
    } catch (_) {}

    await TokenStorage.clearActiveAccount();

    ContactCache.clear();
    TranscriptionCache.clear();
    ComplaintsModule.clear();
    chats.resetForAccountSwitch();

    logger.i('Добавление аккаунта: сессия сброшена, активный аккаунт очищен');
  }

  Future<LoginResult> loginWithToken(String token) async {
    await TokenStorage.clearActiveAccount();
    try {
      await _api.disconnect();
    } catch (_) {}

    ContactCache.clear();
    TranscriptionCache.clear();
    ComplaintsModule.clear();
    chats.resetForAccountSwitch();

    await _api.connect();
    if (_api.state != SessionState.online) {
      throw StateError('loginWithToken: нет соединения с сервером');
    }

    logger.i('Вход по токену: сессия поднята со спуфом, выполняю login');
    return login(token: token);
  }

  Future<ProfileData> switchAccount(int accountId) async {
    final profile = await AppDatabase.loadProfile(accountId);
    if (profile == null) {
      throw StateError('switchAccount: аккаунт $accountId не найден в базе');
    }
    final token = await TokenStorage.readToken(accountId);
    if (token == null) {
      throw StateError('switchAccount: нет токена для аккаунта $accountId');
    }

    try {
      await _api.disconnect();
    } catch (_) {}

    await AppDatabase.setActiveAccount(accountId);
    await TokenStorage.setActiveAccount(accountId);

    ContactCache.clear();
    TranscriptionCache.clear();
    ComplaintsModule.clear();
    chats.resetForAccountSwitch();
    await ContactsModule.primeCacheFromDb(accountId);

    try {
      await _api.connect();
    } catch (e) {
      logger.e(
        'switchAccount: ошибка соединения при переключении на $accountId: $e',
      );
      throw StateError('switchAccount: не удалось подключиться к серверу');
    }
    if (_api.state != SessionState.online) {
      logger.w(
        'switchAccount: нет соединения с сервером после переключения на $accountId',
      );
      throw StateError('switchAccount: нет соединения с сервером');
    }

    logger.i('Активный аккаунт переключён на $accountId');
    return profile;
  }

  Future<List<ProfileData>> listAccounts() async {
    return AppDatabase.loadAllProfiles();
  }

  Future<void> removeAccount(int accountId) async {
    await AppDatabase.deleteAccount(accountId);
    await TokenStorage.deleteAccount(accountId);
    await SpoofingService.clearAccountSpoof(accountId);
    logger.i('Аккаунт $accountId удалён локально');
  }

  Future<void> logout() async {
    final accountId = await TokenStorage.getActiveAccountId();
    try {
      await _logoutOnServer(accountId);
    } on SessionExpiredException catch (e) {
      logger.w('logout: сервер отклонил сессию: ${e.message}');
    }
    _loggedIn = false;
    try {
      await _api.disconnect();
    } catch (_) {}
    if (accountId != null) {
      await removeAccount(accountId);
    }
    ContactCache.clear();
    TranscriptionCache.clear();
    ComplaintsModule.clear();
    chats.resetForAccountSwitch();
  }

  Future<void> _logoutOnServer(int? accountId) async {
    await _ensureLogoutSession(accountId);
    await _api.sendRequestOrThrow(Opcode.logout, <dynamic, dynamic>{});
  }

  Future<void> _ensureLogoutSession(int? accountId) async {
    if (_api.state == SessionState.disconnected) {
      await _api.connect();
    }
    if (_api.state != SessionState.online) {
      await _api.stateStream
          .firstWhere((state) => state == SessionState.online)
          .timeout(const Duration(seconds: 20));
    }
    if (_loggedIn) return;
    if (accountId == null) return;
    final token = await TokenStorage.readToken(accountId);
    if (token == null || token.isEmpty) {
      throw StateError('logout: нет токена для серверного выхода');
    }
    await _api.sendRequestOrThrow(
      Opcode.login,
      buildLoginPayload(token, interactive: false),
    );
    _loggedIn = true;
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

    final data = _requireMapPayload(packet, 'checkPassword');

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

    final accountId = extractAccountId(data);
    if (accountId == null) {
      throw Exception('checkPassword: отсутствует accountId в ответе');
    }

    final profileMap = data['profile'];
    if (profileMap is Map) {
      final profile = ProfileData.fromServerProfile(
        profileMap.cast<dynamic, dynamic>(),
      );
      await AppDatabase.saveProfile(profile, isActive: true);
    }

    await TokenStorage.saveToken(loginToken, accountId);
    await TokenStorage.setActiveAccount(accountId);
    await SpoofingService.commitPendingSpoof(accountId);

    logger.i('2FA пройдена, получен login-токен');
    return TwoFactorResult(loginToken: loginToken, accountId: accountId);
  }

  Map<dynamic, dynamic> buildLoginPayload(
    String token, {
    LoginSyncParams? sync,
    bool? interactive,
  }) {
    final payload = <dynamic, dynamic>{
      'token': token,
      'interactive': interactive ?? !KometSettings.ghostMode.value,
      'exp': {
        'chatsCountGroups': Uint8List.fromList([0x0b, 0x32]),
      },
    };

    final callsSeed = _api.callsSeed;
    final deviceId = _api.deviceId;
    if (callsSeed != null && deviceId != null) {
      payload['chatCacheFingerprint'] = ChatCacheFingerprint.compute(
        callsSeed,
        deviceId,
      );
    }

    if (sync != null) {
      payload['presenceSync'] = sync.presenceSync;
      payload['chatsSync'] = sync.chatsSync;
      payload['contactsSync'] = sync.contactsSync;
      payload['callsSync'] = sync.callsSync;
      payload['draftsSync'] = sync.draftsSync;
      payload['bannersSync'] = sync.bannersSync;
      payload['lastLogin'] = sync.lastLogin;
      if (sync.configHash != null) payload['configHash'] = sync.configHash;
    } else {
      payload['presenceSync'] = -1;
      payload['chatsSync'] = -1;
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

    ProfileData profile;
    final profileMap = data['profile'];
    if (profileMap is Map) {
      final contact = profileMap['contact'];
      if (contact is! Map) {
        throw Exception('login: отсутствует profile.contact в ответе');
      }
      profile = ProfileData.fromServerProfile(
        profileMap.cast<dynamic, dynamic>(),
      );
      await AppDatabase.saveProfile(profile, isActive: true);
    } else {
      final cachedProfile = await AppDatabase.loadProfile(accountId);
      if (cachedProfile == null) {
        throw Exception('login: отсутствует profile в ответе');
      }
      profile = cachedProfile;
    }
    await AppDatabase.setActiveAccount(profile.id);

    await _saveSyncState(data, serverTime, profile.id);
    await ContactsModule.syncFromLoginPayload(data, profile.id);
    await chats.syncFromLoginPayload(data, profile.id, profile.id);
    unawaited(chats.paginateChats(_api, profile.id, profile.id, data));

    try {
      await ContactsModule.syncFromServer(_api, profile.id);
    } catch (e) {
      logger.w('Контакты: $e');
    }

    final config = data['config'];
    if (config is Map) {
      await FoldersModule.applyFromLoginConfig(
        profile.id,
        config.cast<dynamic, dynamic>(),
      );
      final userConfig = config['user'];
      if (userConfig is Map) {
        await AppDatabase.savePrivacyConfig(profile.id, jsonEncode(userConfig));
      }
    }
    try {
      await FoldersModule.syncFromServer(_api, profile.id);
    } catch (e) {
      logger.w('Папки чатов: $e');
    }

    try {
      await _saveLoginInfo(data, profile.id);
    } catch (e) {
      logger.w('Info: $e');
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

  Future<void> _saveLoginInfo(Map<dynamic, dynamic> data, int accountId) async {
    final contact = data['profile']?['contact'] as Map?;
    final videoChatHistory = data['videoChatHistory'];
    final chats = data['chats'] as List?;
    final config = data['config'] as Map?;
    final serverConfig = config?['server'] as Map?;
    final userConfig = config?['user'] as Map?;
    if (serverConfig != null) {
      await _persistEntryBannerApps(accountId, serverConfig);
    }
    final yMap = serverConfig?['y-map'] as Map?;
    final whiteListLinks = serverConfig?['white-list-links'] as List?;
    final fileUploadUnsupported =
        serverConfig?['file-upload-unsupported-types'] as List?;
    final time = data['time'] as int?;

    final info = {
      'registrationTime': contact?['registrationTime'],
      'country': contact?['country'],
      'videoChatHistory': videoChatHistory,
      'updateTime': contact?['updateTime'],
      'id': contact?['id'],
      'chatMarker': chats != null && chats.isNotEmpty
          ? _extractChatMarker(chats.cast<Map>())
          : null,
      'time': time,
      'server': serverConfig != null
          ? _extractServerInfo(
              serverConfig,
              yMap,
              whiteListLinks,
              fileUploadUnsupported,
            )
          : null,
      'user': userConfig != null ? _extractUserConfig(userConfig) : null,
    };

    await AppDatabase.saveLoginInfo(accountId, jsonEncode(info));
  }

  Future<void> _persistEntryBannerApps(int accountId, Map serverConfig) async {
    final banners = serverConfig['settings-entry-banners'];
    if (banners is! List) return;
    final resolved = <String, int>{};
    for (final banner in banners) {
      final items = (banner is Map) ? banner['items'] : null;
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final appId = item['appid'];
        if (appId is! int) continue;
        final icon = item['icon']?.toString().toLowerCase() ?? '';
        for (final entry in EntryBannerApps.iconMatchers.entries) {
          if (!resolved.containsKey(entry.key) && icon.contains(entry.value)) {
            resolved[entry.key] = appId;
          }
        }
      }
    }
    for (final entry in resolved.entries) {
      await AppDatabase.setSyncValue(
        accountId,
        entry.key,
        entry.value.toString(),
      );
    }
  }

  Map<String, dynamic> _extractChatMarker(List<Map> chats) {
    int? latestTime;
    for (final chat in chats) {
      final lastEventTime = chat['lastEventTime'] as int?;
      if (lastEventTime != null &&
          (latestTime == null || lastEventTime > latestTime)) {
        latestTime = lastEventTime;
      }
    }
    return {'chatMarker': latestTime};
  }

  Map<String, dynamic> _extractServerInfo(
    Map serverConfig,
    Map? yMap,
    List? whiteListLinks,
    List? fileUploadUnsupported,
  ) {
    return {
      'account-removal-enabled': serverConfig['account-removal-enabled'],
      'image-size': serverConfig['image-size'],
      'gce': serverConfig['gce'],
      'gcce': serverConfig['gcce'],
      'max-msg-length': serverConfig['max-msg-length'],
      'quotes-enabled': serverConfig['quotes-enabled'],
      'calls-endpoint': serverConfig['calls-endpoint'],
      'send-location-enabled': serverConfig['send-location-enabled'],
      'lgce': serverConfig['lgce'],
      'wud': serverConfig['wud'],
      'video-msg-enabled': serverConfig['video-msg-enabled'],
      'grse': serverConfig['grse'],
      'edit-timeout': serverConfig['edit-timeout'],
      'image-quality': serverConfig['image-quality'],
      'unsafe-files-alert': serverConfig['unsafe-files-alert'],
      'account-nickname-enabled': serverConfig['account-nickname-enabled'],
      'mentions_entity_names_limit':
          serverConfig['mentions_entity_names_limit'],
      'reactions-enabled': serverConfig['reactions-enabled'],
      'y-map': yMap != null
          ? {
              'tile': yMap['tile'],
              'geocoder': yMap['geocoder'],
              'static': yMap['static'],
            }
          : null,
      'white-list-links': whiteListLinks,
      'file-upload-unsupported-types': fileUploadUnsupported,
    };
  }

  Map<String, dynamic> _extractUserConfig(Map userConfig) {
    return {
      'CHATS_PUSH_NOTIFICATION': userConfig['CHATS_PUSH_NOTIFICATION'],
      'PUSH_DETAILS': userConfig['PUSH_DETAILS'],
      'PUSH_SOUND': userConfig['PUSH_SOUND'],
      'PHONE_NUMBER_PRIVACY': userConfig['PHONE_NUMBER_PRIVACY'],
      'INACTIVE_TTL': userConfig['INACTIVE_TTL'],
      'SHOW_READ_MARK': userConfig['SHOW_READ_MARK'],
      'AUDIO_TRANSCRIPTION_ENABLED': userConfig['AUDIO_TRANSCRIPTION_ENABLED'],
      'SEARCH_BY_PHONE': userConfig['SEARCH_BY_PHONE'],
      'INCOMING_CALL': userConfig['INCOMING_CALL'],
      'DOUBLE_TAP_REACTION_DISABLED':
          userConfig['DOUBLE_TAP_REACTION_DISABLED'],
      'SAFE_MODE_NO_PIN': userConfig['SAFE_MODE_NO_PIN'],
      'CHATS_PUSH_SOUND': userConfig['CHATS_PUSH_SOUND'],
      'DOUBLE_TAP_REACTION_VALUE': userConfig['DOUBLE_TAP_REACTION_VALUE'],
      'FAMILY_PROTECTION': userConfig['FAMILY_PROTECTION'],
      'HIDDEN': userConfig['HIDDEN'],
      'CHATS_INVITE': userConfig['CHATS_INVITE'],
      'PUSH_NEW_CONTACTS': userConfig['PUSH_NEW_CONTACTS'],
      'UNSAFE_FILES': userConfig['UNSAFE_FILES'],
      'DONT_DISTURB_UNTIL': userConfig['DONT_DISTURB_UNTIL'],
      'ALT_KEYBOARD': userConfig['ALT_KEYBOARD'],
      'CONTENT_LEVEL_ACCESS': userConfig['CONTENT_LEVEL_ACCESS'],
      'STICKERS_SUGGEST': userConfig['STICKERS_SUGGEST'],
      'SAFE_MODE': userConfig['SAFE_MODE'],
      'M_CALL_PUSH_NOTIFICATION': userConfig['M_CALL_PUSH_NOTIFICATION'],
    };
  }

  Future<RequestCodeResult> _requestCodeInternal(
    String phone,
    AuthRequestType type,
    String language,
  ) async {
    _ensureOnline();

    final normalizedPhone = _normalizeAuthPhone(phone);

    final payload = <dynamic, dynamic>{
      'phone': normalizedPhone,
      'type': type.value,
      'language': language,
    };

    final callsSeed = _api.callsSeed;
    final deviceId = _api.deviceId;
    if (callsSeed != null && deviceId != null) {
      payload['mode'] = ChatCacheFingerprint.compute(callsSeed, deviceId);
    }

    logger.i(
      'Запрос OTP-кода: phone=${_maskPhone(normalizedPhone)} type=${type.value}',
    );

    final packet = await _api.sendRequest(Opcode.authRequest, payload);

    final data = _requireMapPayload(packet, 'requestCode');

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

  Map _requireMapPayload(Packet packet, String method) {
    _checkPacketError(packet, method);
    final data = packet.payload;
    if (data is! Map) {
      throw Exception('$method: неожиданный тип payload: ${data.runtimeType}');
    }
    return data;
  }

  void _checkPacketError(Packet packet, String method) {
    throwIfPacketError(packet);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import '../api.dart';
import '../../core/config/debug_test.dart';
import '../../core/config/komet_settings.dart';
import '../../core/protocol/chat_cache_fingerprint.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/media/media_playback.dart';
import '../../core/crypto/e2ee_service.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/parse.dart';
import '../../core/storage/profile_deletion_store.dart';
import '../../core/storage/spoofing_service.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import '../../models/login_info.dart';
import 'banners.dart';
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

// #***! номер к виду который ждёт сервер
String _normalizeAuthPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return '+$digits';
}

// #***! маскируем номер, в логе ему делать нечего
String _maskPhone(String phone) {
  if (phone.length <= 5) return '***';
  return '${phone.substring(0, 3)}***${phone.substring(phone.length - 2)}';
}

// #***! аккаунт целиком, вход регистрация мультиаккаунт
class AccountModule {
  final Api _api;
  late final SessionsModule _sessions = SessionsModule(_api);
  late final PrivacyModule _privacy = PrivacyModule(_api);
  late final ProfileModule _profile = ProfileModule(_api);
  late final TwoFactorModule _twoFactor = TwoFactorModule(_api, _profile);
  late final BannersModule banners = BannersModule(_api);
  final _loginStatusController = StreamController<LoginStatus>.broadcast();
  final _noticeController = StreamController<AccountNotice>.broadcast();
  bool _loggedIn = false;

  // #***! тяжёлое в подмодулях, тут только оркестрация
  AccountModule(this._api) {
    _api.stateStream.listen((state) {
      if (state != SessionState.online) _loggedIn = false;
    });
  }

  Stream<LoginStatus> get loginStatusStream => _loginStatusController.stream;

  Stream<AccountNotice> get noticeStream => _noticeController.stream;

  /// `true`, только когда сервер считает сессию ONLINE — после успешного
  /// login (opcode 19), а не просто после хэндшейка (opcode 6).
  bool get isLoggedIn => _loggedIn;

  // #***! дальше обёртки над подмодулями, единая точка для юишки
  Future<PrivacyConfig> getPrivacyConfig() => _privacy.getPrivacyConfig();

  Future<List<BlockedContact>> getBlockedContacts() =>
      _privacy.getBlockedContacts();

  Future<PrivacyConfig> updatePrivacyConfig(Map<String, dynamic> settings) =>
      _privacy.updatePrivacyConfig(settings);

  Future<PrivacyConfig> setSafeMode(bool value) => _privacy.setSafeMode(value);

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

  Future<ProfileData> updateProfile(
    String firstName,
    String? lastName, {
    String? description,
  }) => _profile.updateProfile(firstName, lastName, description: description);

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

  // #***! запрос кода, первый и повторный отличаются типом
  Future<RequestCodeResult> requestCode(
    String phone, {
    String language = 'ru',
  }) => _requestCodeInternal(phone, AuthRequestType.startAuth, language);

  Future<RequestCodeResult> resendCode(
    String phone, {
    String language = 'ru',
  }) => _requestCodeInternal(phone, AuthRequestType.resend, language);

  // #***! проверка кода, дальше вход регистрация или 2FA
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

    final loginToken = result.loginToken;
    final verifiedProfile = _profileFromVerifyPayload(result.payload);
    final accountId = result.accountId ?? verifiedProfile?.id;

    // #***! токен сохраняем сразу и переносим спуф профиль
    if (loginToken != null && accountId != null) {
      if (verifiedProfile != null) {
        await AppDatabase.saveProfile(verifiedProfile, isActive: true);
      }
      await TokenStorage.saveToken(loginToken, accountId);
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

  // #***! регистрация после кода
  Future<RegistrationResult> completeRegistration({
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

    final loginToken = data['token'];
    if (loginToken is! String || loginToken.isEmpty) {
      throw Exception('completeRegistration: отсутствует token в ответе');
    }

    final profile = ProfileData.fromServerProfile(
      profileMap.cast<dynamic, dynamic>(),
    );
    await AppDatabase.saveProfile(profile, isActive: true);
    await TokenStorage.saveToken(loginToken, accountId);
    await TokenStorage.setActiveAccount(accountId);
    await SpoofingService.commitPendingSpoof(accountId);

    logger.i('Регистрация завершена, accountId=$accountId');
    return RegistrationResult(loginToken: loginToken, accountId: accountId);
  }

  // #***! основной вход, syncParams говорят серверу что у нас есть
  Future<LoginResult> login({
    int? accountId,
    String? token,
    LoginSyncParams? syncParams,
  }) async {
    _ensureOnline();

    int? resolvedAccountId =
        accountId ?? await TokenStorage.getActiveAccountId();

    String? authToken = token == null || token.isEmpty ? null : token;
    if (authToken == null) {
      if (resolvedAccountId == null) {
        throw StateError('login: нет активного аккаунта');
      }
      authToken = await TokenStorage.readToken(resolvedAccountId);
      if (authToken == null) {
        throw StateError('login: нет токена для аккаунта $resolvedAccountId');
      }
    }

    // #***! сокет мог быть pre-login (прошлая версия): токен шлём только по
    // боевой версии, поэтому при необходимости переподнимаем соединение
    if (!_api.isAuthenticatedHandshake) {
      await _api.reconnectForLogin();
      _ensureOnline();
    }

    final requestPayload = buildLoginPayload(authToken, sync: syncParams);

    _loginStatusController.add(LoginStatus.loading);
    try {
      final packet = await _api.sendRequest(Opcode.login, requestPayload);

      final data = _requireMapPayload(packet, 'login');

      final dataMap = data.cast<dynamic, dynamic>();

      // #***! вошли по чужому токену, id узнаём из ответа
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

  // #***! второй аккаунт, рвём сессию чистим кэши готовим спуф
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
    ContactsModule.clearBlockedCache();
    banners.clear();
    chats.resetForAccountSwitch();

    logger.i('Добавление аккаунта: сессия сброшена, активный аккаунт очищен');
  }

  // #***! вход по чужому токену из дев меню
  Future<LoginResult> loginWithToken(String token) async {
    if (token.isEmpty) {
      throw StateError('loginWithToken: пустой токен');
    }
    await TokenStorage.clearActiveAccount();
    try {
      await _api.disconnect();
    } catch (_) {}

    ContactCache.clear();
    TranscriptionCache.clear();
    ComplaintsModule.clear();
    ContactsModule.clearBlockedCache();
    banners.clear();
    chats.resetForAccountSwitch();

    await _api.connect(authenticated: true);
    if (_api.state != SessionState.online) {
      throw StateError('loginWithToken: нет соединения с сервером');
    }

    logger.i('Вход по токену: сессия поднята со спуфом, выполняю login');
    return login(token: token);
  }

  // #***! Экспериментальный SMS-вход через веб. Веб-клиент MAX всегда шлёт код по
  // SMS, но выдаёт веб-токен. Хитрость: остаёмся залогинены как веб (сессия A —
  // текущий _api), параллельно поднимаем настоящий сокет (сессия B) и просим на
  // нём код — сервер, видя активную веб-сессию, присылает код сообщением в неё.
  // Ловим код, входим на сокете кодом+паролем, получаем сокетовый токен и
  // перезаходим боевой версией. Веб-сессию за собой убираем.
  //
  // Вызывается когда включён "Всегда слать СМС" и первичный веб-вход уже отдал
  // [webToken] (после verifyCode/checkPassword). [existingPassword] != null, если
  // у аккаунта уже была 2FA и пользователь ввёл пароль сам.
  Future<void> completeWebSmsSocketLogin({
    required String phone,
    required int accountId,
    required String webToken,
    String? existingPassword,
  }) async {
    // #***! шаг 1: логинимся на веб-сессии (её НЕ закрываем — в неё придёт код)
    await _bareLogin(webToken);

    // #***! шаг 2: пароль. Есть 2FA — помним введённый; нет — ставим свой рандом.
    // Наш временный пароль ОБЯЗАН быть снят к концу — иначе аккаунт без 2FA
    // останется с паролем, который знаем только мы. Всё, что после установки,
    // обёрнуто в try с откатом.
    final bool weSetPassword = existingPassword == null;
    final String password = existingPassword ?? _generateStrongPassword();
    var passwordCleared = !weSetPassword;

    try {
      if (weSetPassword) {
        final trackId = await create2faTrack();
        await set2faPassword(trackId, password);
        await confirm2fa(
          trackId: trackId,
          password: password,
          hint: null,
          withEmail: false,
        );
        logger.i('SMS-вход: поставлен временный пароль на аккаунт');
      }

      String? socketToken;
      int? socketAccountId;

      // #***! шаг 3: настоящий сокет 26.23.2 — отдельной сессией B
      final apiB = Api();
      final accountB = AccountModule(apiB);
      StreamSubscription<Packet>? codeSub;
      try {
        await apiB.connect(authenticated: false, web: false);
        if (apiB.state != SessionState.online) {
          throw StateError('SMS-вход: не удалось поднять сокет-сессию');
        }

        // #***! шаг 4: слушаем входящий код на веб-сессии ДО запроса на сокете
        final codeCompleter = Completer<String>();
        codeSub = _api.pushStream
            .where((p) => p.opcode == Opcode.notifMessage)
            .listen((p) {
              final code = _extractLoginCode(p.payload);
              if (code != null && !codeCompleter.isCompleted) {
                codeCompleter.complete(code);
              }
            });

        // #***! шаг 5: запрос кода на сокете — сервер шлёт его сообщением в веб
        final req = await accountB.requestCode(phone);

        // #***! шаг 6: ждём код из сообщения (opcode 128) на веб-сессии
        final code = await codeCompleter.future.timeout(
          const Duration(seconds: 90),
          onTimeout: () =>
              throw TimeoutException('SMS-вход: код так и не пришёл'),
        );
        logger.i('SMS-вход: код получен из веб-сессии');

        // #***! шаг 7: код + пароль на сокете → сокетовый токен
        final verify = await accountB.verifyCode(code, req.token);
        if (verify.requiresPassword) {
          final trackId = verify.challengeTrackId;
          if (trackId == null) {
            throw StateError('SMS-вход: нет trackId для ввода пароля');
          }
          final tf = await accountB.checkPassword(
            password: password,
            trackId: trackId,
          );
          socketToken = tf.loginToken;
          socketAccountId = tf.accountId;
        } else {
          socketToken = verify.loginToken;
          socketAccountId = verify.accountId ?? accountId;
        }
      } finally {
        await codeSub?.cancel();
        try {
          await apiB.disconnect();
        } catch (_) {}
        try {
          apiB.dispose();
        } catch (_) {}
      }

      final resolvedToken = socketToken;
      if (resolvedToken == null) {
        throw StateError('SMS-вход: сокетовый токен не получен');
      }
      // #***! socketAccountId тут гарантированно не null (обе ветви его задают)
      final resolvedAccountId = socketAccountId;

      // #***! шаг 8: наш временный пароль снимаем на веб-сессии
      if (weSetPassword) {
        passwordCleared = await _removeTempPassword(password);
      }

      // #***! шаг 9: серверный выход из веб-сессии и разрыв
      try {
        await _api.sendRequestOrThrow(Opcode.logout, <dynamic, dynamic>{});
      } catch (e) {
        logger.w('SMS-вход: серверный выход из веб-сессии не удался: $e');
      }
      _loggedIn = false;
      await _api.disconnect();

      // #***! шаг 10: боевой сокет 26.31.0 + сокетовый токен — финальный вход.
      // Автологин-колбэк сам выполнит login по активному аккаунту.
      await TokenStorage.saveToken(resolvedToken, resolvedAccountId);
      await TokenStorage.setActiveAccount(resolvedAccountId);
      await SpoofingService.commitPendingSpoof(resolvedAccountId);
      await _api.connect(authenticated: true, web: false);
      if (_api.state != SessionState.online) {
        throw StateError('SMS-вход: не удалось поднять боевой сокет');
      }
      if (!_loggedIn) {
        await login(accountId: resolvedAccountId, token: resolvedToken);
      }

      // #***! не сняли на веб-сессии — снимаем на боевой
      if (!passwordCleared) {
        passwordCleared = await _removeTempPassword(password);
      }
      if (!passwordCleared) {
        logger.e('SMS-вход: ВРЕМЕННЫЙ ПАРОЛЬ НЕ СНЯТ. Пароль: $password');
      }
    } catch (e) {
      // #***! любой сбой после установки пароля — откатываем, пока веб-сессия
      // ещё жива; если не вышло, пароль хотя бы попадёт в лог
      if (weSetPassword && !passwordCleared) {
        if (_api.state == SessionState.online) {
          passwordCleared = await _removeTempPassword(password);
        }
        if (!passwordCleared) {
          logger.e(
            'SMS-вход: сбой, ВРЕМЕННЫЙ ПАРОЛЬ НЕ СНЯТ. Пароль: $password',
          );
        }
      }
      rethrow;
    }
  }

  // #***! снятие временного пароля: панель 2FA → проверка пароля → удаление
  Future<bool> _removeTempPassword(String password) async {
    try {
      final trackId = await enter2faPanel();
      await check2faPassword(trackId, password);
      await remove2fa(trackId);
      return true;
    } catch (e) {
      logger.w('SMS-вход: снять временный пароль не удалось: $e');
      return false;
    }
  }

  // #***! логин без полной обработки: веб-сессии нужно лишь быть залогиненной,
  // чтобы принять код и снять/поставить пароль; чаты/пуши тут не поднимаем
  Future<void> _bareLogin(String token) async {
    _ensureOnline();
    final packet = await _api.sendRequest(
      Opcode.login,
      buildLoginPayload(token, interactive: false),
    );
    throwIfPacketError(packet);
  }

  static String _generateStrongPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // #***! код входа приходит сообщением от MAX: чистый код в payload кнопки
  // INLINE_KEYBOARD, дубль — в тексте "Код: 123456"
  static String? _extractLoginCode(dynamic payload) {
    if (payload is! Map) return null;
    final msg = payload['message'];
    if (msg is! Map) return null;
    final text = msg['text'];
    final looksLikeLogin =
        text is String &&
        RegExp(
          r'код|code|войти|профил',
          caseSensitive: false,
        ).hasMatch(text);
    if (!looksLikeLogin) return null;

    final attaches = msg['attaches'];
    if (attaches is List) {
      for (final a in attaches.whereType<Map>()) {
        if (a['_type'] != 'INLINE_KEYBOARD') continue;
        final kb = a['keyboard'];
        if (kb is! Map) continue;
        final buttons = kb['buttons'];
        if (buttons is! List) continue;
        for (final row in buttons.whereType<List>()) {
          for (final btn in row.whereType<Map>()) {
            final p = btn['payload'];
            if (p is String && RegExp(r'^\d{4,8}$').hasMatch(p)) return p;
          }
        }
      }
    }
    final m = RegExp(
      r'(?:код|code)\D{0,4}(\d{4,8})',
      caseSensitive: false,
    ).firstMatch(text);
    if (m != null) return m.group(1);
    return null;
  }

  // #***! переключение аккаунта, реконнект с другим спуфом
  Future<ProfileData> switchAccount(int accountId) async {
    MediaPlayback.instance.closeAudioFile();
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
    ContactsModule.clearBlockedCache();
    banners.clear();
    chats.resetForAccountSwitch();
    await ContactsModule.primeCacheFromDb(accountId);

    try {
      await _api.connect(authenticated: true);
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

  // #***! удаляем локально, база токен спуф и заявка
  Future<void> removeAccount(int accountId) async {
    await E2eeService.instance.eraseAccount(accountId);
    await AppDatabase.deleteAccount(accountId);
    await TokenStorage.deleteAccount(accountId);
    await SpoofingService.clearAccountSpoof(accountId);
    await ProfileDeletionStore.clear(accountId);
    logger.i('Аккаунт $accountId удалён локально');
  }

  Future<DateTime?> profileDeletionScheduledAt() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return null;
    return ProfileDeletionStore.scheduledAt(accountId);
  }

  // #***! заявка на удаление профиля, сервер вернёт дату
  Future<DateTime?> setProfileDeletion(bool delete) async {
    _ensureOnline();

    final packet = await _api.sendRequest(Opcode.profileDelete, {
      'delete': delete,
      'type': 0,
    });
    final data = _requireMapPayload(packet, 'setProfileDeletion');

    final raw = data['timestamp'];
    final millis = raw is int ? raw : 0;

    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId != null) {
      await ProfileDeletionStore.save(accountId, millis);
    }

    logger.i(
      'Профиль: заявка на удаление '
      '${delete ? 'создана' : 'отменена'} (timestamp=$millis)',
    );

    if (millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  // #***! выход, сначала сервер потом чистка
  Future<void> logout() async {
    MediaPlayback.instance.closeAudioFile();
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
    ContactsModule.clearBlockedCache();
    banners.clear();
    chats.resetForAccountSwitch();
  }

  Future<void> _logoutOnServer(int? accountId) async {
    await _ensureLogoutSession(accountId);
    await _api.sendRequestOrThrow(Opcode.logout, <dynamic, dynamic>{});
  }

  // #***! чтоб выйти нужна живая сессия, при чём логинимся заново
  Future<void> _ensureLogoutSession(int? accountId) async {
    if (_api.state == SessionState.disconnected) {
      await _api.connect(authenticated: true);
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

  // #***! второй шаг входа при 2FA
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
      throw const WrongPasswordException();
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

  // #***! тело login, токен невидимка и маркеры синхры
  Map<dynamic, dynamic> buildLoginPayload(
    String token, {
    LoginSyncParams? sync,
    bool? interactive,
  }) {
    final payload = <dynamic, dynamic>{
      'token': token,
      'interactive': interactive ?? !KometSettings.ghostMode.value,
      // #***! exp это экспериментальные фичи которые просим
      'exp': {
        'chatsCountGroups': Uint8List.fromList([0x0b, 0x32]),
      },
    };

    final callsSeed = _api.callsSeed;
    final deviceId = _api.deviceId;
    // #***! без отпечатка сборки сервер не отдаст кэш чатов; у веба нативных
    // либ нет, поэтому в веб-режиме отпечаток не шлём вовсе
    if (!_api.webHandshake && callsSeed != null && deviceId != null) {
      payload['chatCacheFingerprint'] = ChatCacheFingerprint.compute(
        callsSeed,
        deviceId,
        arch: _api.architecture,
        preLogin: !_api.isAuthenticatedHandshake,
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
      if (sync.serverConfigSeen && sync.configHash != null) {
        payload['configHash'] = sync.configHash;
      }
      // #***! нет маркеров, просим всё с нуля
    } else {
      payload['presenceSync'] = -1;
      payload['chatsSync'] = -1;
    }

    return payload;
  }

  // #***! разбор login, профиль чаты контакты папки баннеры
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
    // #***! берсерк ломает профиль специально чтоб проверить восстановление
    if (!DebugTest.berserk &&
        profileMap is Map &&
        profileMap['contact'] is Map) {
      profile = ProfileData.fromServerProfile(
        profileMap.cast<dynamic, dynamic>(),
      );
    } else {
      profile = await _resurrectProfile(accountId);
    }
    await AppDatabase.saveProfile(profile, isActive: true);
    await AppDatabase.setActiveAccount(profile.id);

    await _saveSyncState(data, serverTime, profile.id);
    await ContactsModule.syncFromLoginPayload(data, profile.id);
    await chats.syncFromLoginPayload(data, profile.id, profile.id);
    // #***! остальные страницы чатов в фоне, вход не ждёт
    unawaited(chats.paginateChats(_api, profile.id, profile.id, data));

    // #***! каждый блок в try, упавший кусок не должен ронять вход
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
      await chats.applyFavorites(profile.id);
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
    await chats.applyFavorites(profile.id);

    try {
      await banners.initFromLogin(profile.id, data);
    } catch (e) {
      logger.w('Баннеры: $e');
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

  // #***! профиля нет нигде, тянем через контакт иначе заглушка
  Future<ProfileData> _resurrectProfile(int accountId) async {
    if (DebugTest.berserk) {
      await AppDatabase.deleteAccount(accountId);
      logger.w(
        'login: [BERSERK] профиль удалён из БД, форсирую регенерацию (id=$accountId)',
      );
    } else {
      final cached = await AppDatabase.loadProfile(accountId);
      if (cached != null) return cached;
    }

    _noticeController.add(AccountNotice.resurrectingProfile);

    try {
      final fetched = await ContactsModule.fetchSelfProfile(_api, accountId);
      if (fetched != null) {
        logger.i(
          'login: профиль восстановлен через CONTACT_INFO (id=$accountId)',
        );
        return fetched;
      }
    } catch (e) {
      logger.w(
        'login: восстановление профиля через CONTACT_INFO не удалось: $e',
      );
    }

    logger.w('login: профиль недоступен, использую заглушку (id=$accountId)');
    return ProfileData.stub(accountId);
  }

  // #***! маркеры синхры, считаем что знаем всё до serverTime
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

  // #***! сводка login для отладочного экрана
  Future<void> _saveLoginInfo(Map<dynamic, dynamic> data, int accountId) async {
    final config = data['config'] as Map?;
    final serverConfig = config?['server'] as Map?;
    if (serverConfig != null) {
      await AppDatabase.setSyncValue(
        accountId,
        SyncKey.serverConfigSeen,
        LoginSyncParams.serverConfigRevision,
      );
      await AppDatabase.setSyncValue(
        accountId,
        SyncKey.profileInviteLink,
        serverConfig['invite-link']?.toString().trim() ?? '',
      );
      await AppDatabase.setWelcomeStickerIds(
        accountId,
        parseIntList(serverConfig['welcome-sticker-ids']),
      );
      await _persistEntryBannerApps(accountId, serverConfig);
    }
    final info = LoginInfo.fromPayload(data);

    await AppDatabase.saveLoginInfo(accountId, jsonEncode(info));
  }

  Future<void> _persistEntryBannerApps(int accountId, Map serverConfig) async {
    final resolved = EntryBannerApps.appIdsFrom(serverConfig);
    for (final entry in resolved.entries) {
      await AppDatabase.setSyncValue(
        accountId,
        entry.key,
        entry.value.toString(),
      );
    }
  }

  // #***! общий запрос кода
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
    // #***! веб mode не шлёт — вместе с веб-рукопожатием это и заставляет
    // сервер отдать код по SMS, а не пушем
    if (!_api.webHandshake && callsSeed != null && deviceId != null) {
      payload['mode'] = ChatCacheFingerprint.compute(
        callsSeed,
        deviceId,
        arch: _api.architecture,
        preLogin: !_api.isAuthenticatedHandshake,
      );
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

  // #***! дальше три помощника
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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../api.dart';
import '../../core/protocol/chat_cache_fingerprint.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import 'chats.dart';
import 'contacts.dart';
import 'folders.dart';
import 'messages.dart';
import 'webapp.dart';

String _normalizeAuthPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return '+$digits';
}

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
  final String phoneNumberPrivacy;
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
    required this.phoneNumberPrivacy,
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
      phoneNumberPrivacy: map['PHONE_NUMBER_PRIVACY']?.toString() ?? 'ALL',
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
    'PHONE_NUMBER_PRIVACY': phoneNumberPrivacy,
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
      phoneNumberPrivacy: 'ALL',
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

class WrongDeviceTokenException implements Exception {
  const WrongDeviceTokenException();
  @override
  String toString() => 'WrongDeviceTokenException';
}

class RequestCodeResult {
  final String token;

  const RequestCodeResult({required this.token});
}

class PresetAvatar {
  final int id;
  final String url;

  const PresetAvatar({required this.id, required this.url});
}

class PresetAvatarCategory {
  final String name;
  final List<PresetAvatar> avatars;

  const PresetAvatarCategory({required this.name, required this.avatars});
}

class VerifyCodeResult {
  final Map<dynamic, dynamic> payload;

  const VerifyCodeResult({required this.payload});

  String? get loginToken => _nestedToken('LOGIN');

  String? get registerToken => _nestedToken('REGISTER');

  bool get isRegistration => registerToken != null && loginToken == null;

  List<PresetAvatarCategory> get presetAvatars {
    final raw = payload['presetAvatars'];
    if (raw is! List) return const [];
    final categories = <PresetAvatarCategory>[];
    for (final cat in raw) {
      if (cat is! Map) continue;
      final avatarsRaw = cat['avatars'];
      if (avatarsRaw is! List) continue;
      final avatars = <PresetAvatar>[];
      for (final a in avatarsRaw) {
        if (a is! Map) continue;
        final id = a['id'];
        final url = a['url'];
        if (id is int && url is String && url.isNotEmpty) {
          avatars.add(PresetAvatar(id: id, url: url));
        }
      }
      if (avatars.isNotEmpty) {
        categories.add(
          PresetAvatarCategory(
            name: cat['name']?.toString() ?? '',
            avatars: avatars,
          ),
        );
      }
    }
    return categories;
  }

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
      lastLogin: int.tryParse(lastLogin) ?? 0,
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
      if (saved != null) return PrivacyConfig.fromJson(saved);
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

  Future<void> registerPushToken(String pushToken) async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.config, <dynamic, dynamic>{
      'pushToken': pushToken,
    });
    if (packet.isError) {
      final msg = messageFromErrorPayload(packet.payload).toUpperCase();
      if (msg.contains('WRONG_DEVICE_TOKEN') ||
          msg.contains('WRONG.DEVICE.TOKEN')) {
        throw const WrongDeviceTokenException();
      }
      throw PacketError(messageFromErrorPayload(packet.payload));
    }
  }

  Future<void> unregisterPushToken(String pushToken) async {
    if (_api.state != SessionState.online) return;
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;
    final authToken = await TokenStorage.readToken(accountId);
    if (authToken == null) return;
    await _api.sendRequest(Opcode.logout, <dynamic, dynamic>{
      'token': authToken,
      'pushToken': pushToken,
    });
  }

  Future<ProfileData> updateProfileName(String firstName, String? lastName) async {
    _ensureOnline();
    final payload = <dynamic, dynamic>{
      'firstName': firstName,
    };
    if (lastName != null) payload['lastName'] = lastName;
    final packet = await _api.sendRequest(Opcode.profile, payload);
    if (packet.isError) {
      throw Exception(packet.payload?.toString() ?? 'Server error');
    }
    final data = packet.payload as Map?;
    if (data == null) throw Exception('Empty response');
    final profile = data['profile'] as Map?;
    if (profile == null) throw Exception('No profile in response');
    final contact = profile['contact'] as Map?;
    if (contact == null) throw Exception('No contact in response');
    final newProfile = ProfileData.fromServerMap(contact.cast<dynamic, dynamic>());
    await AppDatabase.saveProfile(newProfile, isActive: true);
    return newProfile;
  }

  Future<ProfileData> updateProfileAvatar(String photoToken, {String avatarType = 'USER_AVATAR'}) async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.profile, {
      'photoToken': photoToken,
      'avatarType': avatarType,
    });
    if (packet.isError) {
      throw Exception(packet.payload?.toString() ?? 'Server error');
    }
    final data = packet.payload as Map?;
    if (data == null) throw Exception('Empty response');
    final profile = data['profile'] as Map?;
    if (profile == null) throw Exception('No profile in response');
    final contact = profile['contact'] as Map?;
    if (contact == null) throw Exception('No contact in response');
    final newProfile = ProfileData.fromServerMap(contact.cast<dynamic, dynamic>());
    await AppDatabase.saveProfile(newProfile, isActive: true);
    return newProfile;
  }

  Future<String> getAvatarUploadUrl() async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.photoUpload, {
      'count': 1,
      'profile': true,
    });
    if (packet.isError) {
      throw Exception(packet.payload?.toString() ?? 'Server error');
    }
    final data = packet.payload as Map?;
    if (data == null) throw Exception('Empty response');
    final url = data['url'] as String?;
    if (url == null) throw Exception('No url in response');
    return url;
  }

  Future<ProfileData> removeProfilePhoto(int photoId) async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.removeContactPhoto, {
      'photoId': photoId,
    });
    if (packet.isError) {
      throw Exception(packet.payload?.toString() ?? 'Server error');
    }
    final data = packet.payload as Map?;
    if (data == null) throw Exception('Empty response');
    final profile = data['profile'] as Map?;
    if (profile == null) throw Exception('No profile in response');
    final contact = profile['contact'] as Map?;
    if (contact == null) throw Exception('No contact in response');
    final newProfile = ProfileData.fromServerMap(contact.cast<dynamic, dynamic>());
    await AppDatabase.saveProfile(newProfile, isActive: true);
    return newProfile;
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
    bool withEmail = true,
  }) async {
    _ensureOnline();
    final capabilities = <int>[0, if (hint != null) 3, if (withEmail) 4];
    final payload = <dynamic, dynamic>{
      'expectedCapabilities': capabilities,
      'trackId': trackId,
      'password': password,
    };
    if (hint != null) payload['hint'] = hint;
    return _processProfileUpdate(
      _api.sendRequest(Opcode.authSet2fa, payload),
      'confirm2fa',
    );
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

  Future<TwoFactorDetails> get2faStatus() async {
    final trackId = await enter2faPanel();
    return get2faDetails(trackId);
  }

  Future<void> check2faPassword(String trackId, String password) async {
    _ensureOnline();
    final packet = await _api.sendRequest(Opcode.authCheckPassword, {
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
      'expectedCapabilities': <int>[1, if (hint != null) 3],
      'trackId': trackId,
      'password': newPassword,
    };
    if (hint != null) payload['hint'] = hint;

    return _processProfileUpdate(
      _api.sendRequest(Opcode.authSet2fa, payload),
      'update2faPassword',
    );
  }

  Future<ProfileData> commit2faEmailChange(String trackId) async {
    _ensureOnline();
    final payload = <dynamic, dynamic>{
      'expectedCapabilities': [4],
      'trackId': trackId,
    };
    return _processProfileUpdate(
      _api.sendRequest(Opcode.authSet2fa, payload),
      'commit2faEmailChange',
    );
  }

  Future<ProfileData> remove2fa(String trackId) async {
    _ensureOnline();
    final payload = <dynamic, dynamic>{
      'expectedCapabilities': [5],
      'trackId': trackId,
      'remove2fa': true,
    };
    return _processProfileUpdate(
      _api.sendRequest(Opcode.authSet2fa, payload),
      'remove2fa',
    );
  }

  Future<ProfileData> _processProfileUpdate(
    Future<Packet> requestFuture,
    String tag,
  ) async {
    final completer = Completer<ProfileData>();
    final sub = _api.pushStream
        .where((p) => p.opcode == Opcode.notifProfile)
        .listen((push) {
      if (completer.isCompleted) return;
      final payload = push.payload;
      if (payload is! Map) return;
      final profile = payload['profile'];
      if (profile is! Map) return;
      final contact = profile['contact'];
      if (contact is! Map) return;
      completer.complete(
        ProfileData.fromServerMap(contact.cast<dynamic, dynamic>()),
      );
    });
    final timer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Таймаут ожидания обновления профиля'),
        );
      }
    });
    try {
      final packet = await requestFuture;
      _checkPacketError(packet, tag);
      return await completer.future;
    } finally {
      timer.cancel();
      await sub.cancel();
    }
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

    _checkPacketError(packet, 'completeRegistration');

    final data = packet.payload;
    if (data is! Map) {
      throw Exception(
        'completeRegistration: неожиданный тип payload: ${data.runtimeType}',
      );
    }

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

    final profile = ProfileData.fromServerMap(contact.cast<dynamic, dynamic>());
    await AppDatabase.saveProfile(profile, isActive: true);
    await TokenStorage.setActiveAccount(accountId);

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

    final requestPayload = _buildLoginPayload(authToken, syncParams);

    _loginStatusController.add(LoginStatus.loading);
    try {
      final packet = await _api.sendRequest(Opcode.login, requestPayload);

      _checkPacketError(packet, 'login');

      final data = packet.payload;
      if (data is! Map) {
        throw Exception('login: неожиданный тип payload: ${data.runtimeType}');
      }

      final dataMap = data.cast<dynamic, dynamic>();

      if (resolvedAccountId == null) {
        final profileMap = dataMap['profile'];
        if (profileMap is Map) {
          final contact = profileMap['contact'];
          if (contact is Map) {
            resolvedAccountId = contact['id'] as int?;
          }
        }
        if (resolvedAccountId == null) {
          throw Exception('login: не удалось определить accountId из ответа');
        }
        await TokenStorage.saveToken(authToken, resolvedAccountId);
        await TokenStorage.setActiveAccount(resolvedAccountId);
      }

      final result = await _processLoginResponse(dataMap, resolvedAccountId);
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

  Future<void> beginAddAccount() async {
    try {
      await _api.disconnect();
    } catch (_) {}

    await TokenStorage.clearActiveAccount();

    ContactCache.clear();
    TranscriptionCache.clear();
    ChatsModule.resetForAccountSwitch();

    logger.i('Добавление аккаунта: сессия сброшена, активный аккаунт очищен');
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
    ChatsModule.resetForAccountSwitch();
    await ContactsModule.primeCacheFromDb(accountId);

    try {
      await _api.connect();
    } catch (_) {}

    logger.i('Активный аккаунт переключён на $accountId');
    return profile;
  }

  Future<List<ProfileData>> listAccounts() async {
    return AppDatabase.loadAllProfiles();
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

    logger.i('2FA пройдена, получен login-токен');
    return TwoFactorResult(loginToken: loginToken);
  }

  Map<dynamic, dynamic> _buildLoginPayload(
    String token,
    LoginSyncParams? sync,
  ) {
    final payload = <dynamic, dynamic>{
      'token': token,
      'interactive': true,
      'exp': {
        'chatsCountGroups': Uint8List.fromList([0x0b, 0x32]),
      },
    };

    final callsSeed = _api.callsSeed;
    final deviceId = _api.deviceId;
    if (callsSeed != null && deviceId != null) {
      payload['chatCacheFingerprint'] =
          ChatCacheFingerprint.compute(callsSeed, deviceId);
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
    await AppDatabase.saveProfile(profile, isActive: true);
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
      final userConfig = config['user'];
      if (userConfig is Map) {
        await AppDatabase.savePrivacyConfig(
          profile.id,
          jsonEncode(userConfig),
        );
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

  Future<void> _saveLoginInfo(
    Map<dynamic, dynamic> data,
    int accountId,
  ) async {
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
    final fileUploadUnsupported = serverConfig?['file-upload-unsupported-types'] as List?;
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
          ? _extractServerInfo(serverConfig, yMap, whiteListLinks, fileUploadUnsupported)
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
      await AppDatabase.setSyncValue(accountId, entry.key, entry.value.toString());
    }
  }

  Map<String, dynamic> _extractChatMarker(List<Map> chats) {
    int? latestTime;
    for (final chat in chats) {
      final lastEventTime = chat['lastEventTime'] as int?;
      if (lastEventTime != null && (latestTime == null || lastEventTime > latestTime)) {
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
      'mentions_entity_names_limit': serverConfig['mentions_entity_names_limit'],
      'reactions-enabled': serverConfig['reactions-enabled'],
      'y-map': yMap != null ? {
        'tile': yMap['tile'],
        'geocoder': yMap['geocoder'],
        'static': yMap['static'],
      } : null,
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
      'DOUBLE_TAP_REACTION_DISABLED': userConfig['DOUBLE_TAP_REACTION_DISABLED'],
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

    logger.i('Запрос OTP-кода: phone=$normalizedPhone type=${type.value}');

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
      if (payload is Map &&
          (payload['message'] == 'FAIL_LOGIN_TOKEN' ||
              payload['message'] == 'FAIL_WRONG_PASSWORD')) {
        throw SessionExpiredException(messageFromErrorPayload(payload));
      }
      throw PacketError(messageFromErrorPayload(payload));
    }
  }
}

import 'dart:convert';

import '../../../core/storage/app_database.dart';

int? _coerceAccountId(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

int? extractAccountId(dynamic response) {
  if (response is! Map) return null;

  final profile = response['profile'];
  if (profile is Map) {
    final contact = profile['contact'];
    if (contact is Map) {
      final cid =
          _coerceAccountId(contact['id']) ??
          _coerceAccountId(contact['contactId']) ??
          _coerceAccountId(contact['accountId']);
      if (cid != null) return cid;
    }
    final pid =
        _coerceAccountId(profile['id']) ??
        _coerceAccountId(profile['accountId']);
    if (pid != null) return pid;
  }

  final contact = response['contact'];
  if (contact is Map) {
    final cid =
        _coerceAccountId(contact['id']) ??
        _coerceAccountId(contact['contactId']);
    if (cid != null) return cid;
  }

  final account = response['account'];
  if (account is Map) {
    final aid =
        _coerceAccountId(account['id']) ??
        _coerceAccountId(account['accountId']);
    if (aid != null) return aid;
  }

  return _coerceAccountId(response['accountId']) ??
      _coerceAccountId(response['account_id']);
}

String describeResponseShape(dynamic response) {
  if (response is! Map) return 'не-Map (${response.runtimeType})';
  final sb = StringBuffer('keys=${response.keys.toList()}');
  final profile = response['profile'];
  if (profile is Map) {
    sb.write(' profile.keys=${profile.keys.toList()}');
    final contact = profile['contact'];
    if (contact is Map) {
      sb.write(' contact.keys=${contact.keys.toList()}');
    } else {
      sb.write(' profile.contact=${contact.runtimeType}');
    }
  } else {
    sb.write(' profile=${profile.runtimeType}');
  }
  return sb.toString();
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
  final String chatsPushNotification;
  final String mCallPushNotification;
  final String pushSound;
  final String chatsPushSound;
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
    required this.chatsPushNotification,
    required this.mCallPushNotification,
    required this.pushSound,
    required this.chatsPushSound,
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
      chatsPushNotification: map['CHATS_PUSH_NOTIFICATION']?.toString() ?? 'ON',
      mCallPushNotification:
          map['M_CALL_PUSH_NOTIFICATION']?.toString() ?? 'ON',
      pushSound: map['PUSH_SOUND']?.toString() ?? 'oki.aiff',
      chatsPushSound: map['CHATS_PUSH_SOUND']?.toString() ?? 'oki.aiff',
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
    'CHATS_PUSH_NOTIFICATION': chatsPushNotification,
    'M_CALL_PUSH_NOTIFICATION': mCallPushNotification,
    'PUSH_SOUND': pushSound,
    'CHATS_PUSH_SOUND': chatsPushSound,
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
      chatsPushNotification: 'ON',
      mCallPushNotification: 'ON',
      pushSound: 'oki.aiff',
      chatsPushSound: 'oki.aiff',
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

  int? get accountId => extractAccountId(payload);

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
  final int accountId;

  const TwoFactorResult({required this.loginToken, required this.accountId});
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

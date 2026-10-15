import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../api.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/logger.dart';
import 'account_base.dart';
import 'account_models.dart';

// #***! приватность и уведомления
class PrivacyModule extends AccountApiBase {
  PrivacyModule(super.api);

  final ValueNotifier<String?> doubleTapReaction = ValueNotifier(
    PrivacyConfig.defaultDoubleTapReaction,
  );
  int _configRevision = 0;
  Future<void> _localQueue = Future.value();

  Future<void> restoreDoubleTapReaction() async {
    final revision = _configRevision;
    final config = await getPrivacyConfig();
    if (revision == _configRevision) {
      doubleTapReaction.value = config.doubleTapReaction;
    }
  }

  Future<void> storeLoginConfig(
    int accountId,
    Map<dynamic, dynamic> user,
  ) async {
    _publish(await _mergeAndSave(accountId, user));
  }

  Future<PrivacyConfig> _mergeAndSave(
    int accountId,
    Map<dynamic, dynamic> user,
  ) async {
    final merged = <String, dynamic>{
      ..._decodeStored(await AppDatabase.getPrivacyConfig(accountId)),
      for (final entry in user.entries) entry.key.toString(): entry.value,
      ...await _loadOverrides(accountId),
    };
    await AppDatabase.savePrivacyConfig(accountId, jsonEncode(merged));
    return PrivacyConfig.fromMap(merged);
  }

  Future<Map<String, dynamic>> _loadOverrides(int accountId) async =>
      _decodeStored(
        await AppDatabase.getSyncValue(accountId, SyncKey.privacyOverrides),
      );

  Future<void> _saveOverrides(int accountId, Map<String, dynamic> overrides) =>
      AppDatabase.setSyncValue(
        accountId,
        SyncKey.privacyOverrides,
        jsonEncode(overrides),
      );

  Map<String, dynamic> _decodeStored(String? json) {
    if (json == null) return const {};
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  void _publish(PrivacyConfig config) {
    _configRevision++;
    doubleTapReaction.value = config.doubleTapReaction;
  }

  // #***! приватность из базы, приходит в login и живёт локально
  Future<PrivacyConfig> getPrivacyConfig() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId != null) {
      final saved = await AppDatabase.getPrivacyConfig(accountId);
      if (saved != null) return PrivacyConfig.fromJson(saved);
    }
    return PrivacyConfig.empty();
  }

  // #***! список заблокированных
  Future<List<BlockedContact>> getBlockedContacts() async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.contactList, {
      'status': 'BLOCKED',
      'count': 100,
      'from': 0,
    });
    final data = requireMapPayload(packet, 'getBlockedContacts');
    final contacts = data['contacts'] as List?;
    if (contacts == null) return [];
    return contacts
        .whereType<Map>()
        .map((c) => BlockedContact.fromMap(c.cast<dynamic, dynamic>()))
        .toList();
  }

  // #***! обновление одним config, ответ в базу
  Future<PrivacyConfig> updatePrivacyConfig(
    Map<String, dynamic> settings,
  ) async {
    final user = await _sendSettings(settings);
    final accountId = await TokenStorage.getActiveAccountId();
    final config = accountId == null
        ? PrivacyConfig.fromMap(user)
        : await _mergeAndSave(accountId, user);
    _publish(config);
    return config;
  }

  Future<Map<dynamic, dynamic>> _sendSettings(
    Map<String, dynamic> settings, {
    bool silent = false,
  }) async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.config, <dynamic, dynamic>{
      'settings': {'user': settings},
    }, silent: silent);
    final data = requireMapPayload(packet, 'updatePrivacyConfig');
    final user = data['user'];
    if (user is! Map) {
      throw Exception('updatePrivacyConfig: отсутствует user в payload');
    }
    return user;
  }

  Future<PrivacyConfig> _applyLocally(Map<String, dynamic> settings) {
    final run = _localQueue.then((_) => _applyLocallyNow(settings));
    _localQueue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<PrivacyConfig> _applyLocallyNow(Map<String, dynamic> settings) async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return PrivacyConfig.empty();

    await _saveOverrides(accountId, {
      ...await _loadOverrides(accountId),
      ...settings,
    });
    var config = await _mergeAndSave(accountId, const {});
    _publish(config);

    final Map<dynamic, dynamic> user;
    try {
      user = await _sendSettings(settings, silent: true);
    } catch (e) {
      final reason = e is PacketError ? e.errorKey ?? e.message : e;
      logger.w(
        'Настройки ${settings.keys.join(', ')} остались локальными: $reason',
      );
      return config;
    }

    final overrides = await _loadOverrides(accountId);
    overrides.removeWhere(
      (key, value) =>
          settings.containsKey(key) &&
          value == settings[key] &&
          user[key] == value,
    );
    await _saveOverrides(accountId, overrides);
    config = await _mergeAndSave(accountId, user);
    _publish(config);
    return config;
  }

  Future<PrivacyConfig> setDoubleTapReaction(String? emoji) =>
      updatePrivacyConfig(
        emoji == null
            ? {'DOUBLE_TAP_REACTION_DISABLED': true}
            : {
                'DOUBLE_TAP_REACTION_DISABLED': false,
                'DOUBLE_TAP_REACTION_VALUE': emoji,
              },
      );

  // #***! безопасный режим это пачка настроек разом
  Future<PrivacyConfig> setSafeMode(bool value) => updatePrivacyConfig(
    value
        ? {
            'INCOMING_CALL': 'CONTACTS',
            'SEARCH_BY_PHONE': 'CONTACTS',
            'SAFE_MODE_NO_PIN': true,
            'CONTENT_LEVEL_ACCESS': true,
            'CHATS_INVITE': 'CONTACTS',
            'SAFE_MODE': true,
          }
        : {'SAFE_MODE_NO_PIN': false, 'SAFE_MODE': false},
  );

  // #***! дальше по методу на каждый переключатель
  Future<PrivacyConfig> setDialogsPushNotification(String mode) =>
      _applyLocally({'DIALOGS_PUSH_NOTIFICATION': mode});

  Future<PrivacyConfig> setChatsPushNotification(String mode) =>
      _applyLocally({'CHATS_PUSH_NOTIFICATION': mode});

  Future<PrivacyConfig> setMessagePreview(bool value) =>
      _applyLocally({'PUSH_DETAILS': value});

  Future<PrivacyConfig> setCallNotifications(bool value) => _applyLocally({
    'M_CALL_PUSH_NOTIFICATION': value
        ? PrivacyConfig.pushOn
        : PrivacyConfig.pushOff,
  });

  Future<PrivacyConfig> setNewContacts(bool value) =>
      _applyLocally({'PUSH_NEW_CONTACTS': value});

  // #***! регистрация push токена, ловим протухший FCM
  Future<void> registerPushToken(String pushToken) async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.config, <dynamic, dynamic>{
      'pushToken': pushToken,
      'pushOptions': 0,
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

  Future<void> unregisterPushToken(String _) async {
    if (api.state != SessionState.online) return;
    final packet = await api.sendRequest(Opcode.logout, <dynamic, dynamic>{});
    throwIfPacketError(packet);
  }
}

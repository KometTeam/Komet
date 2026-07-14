import '../../api.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import 'account_base.dart';
import 'account_models.dart';

class PrivacyModule extends AccountApiBase {
  PrivacyModule(super.api);

  static const String _defaultPushSound = 'oki.aiff';

  Future<PrivacyConfig> getPrivacyConfig() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId != null) {
      final saved = await AppDatabase.getPrivacyConfig(accountId);
      if (saved != null) return PrivacyConfig.fromJson(saved);
    }
    return PrivacyConfig.empty();
  }

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

  Future<PrivacyConfig> updatePrivacyConfig(
    Map<String, dynamic> settings,
  ) async {
    ensureOnline();
    final payload = <dynamic, dynamic>{
      'settings': {'user': settings},
    };
    final packet = await api.sendRequest(Opcode.config, payload);
    final data = requireMapPayload(packet, 'updatePrivacyConfig');
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

  Future<PrivacyConfig> setChatsPushNotification(bool value) =>
      updatePrivacyConfig({'CHATS_PUSH_NOTIFICATION': value ? 'ON' : 'OFF'});

  Future<PrivacyConfig> setMessagePreview(bool value) =>
      updatePrivacyConfig({'PUSH_DETAILS': value});

  Future<PrivacyConfig> setNotificationSound(bool value) =>
      updatePrivacyConfig({
        'PUSH_SOUND': value ? _defaultPushSound : '',
        'CHATS_PUSH_SOUND': value ? _defaultPushSound : '',
      });

  Future<PrivacyConfig> setCallNotifications(bool value) =>
      updatePrivacyConfig({'M_CALL_PUSH_NOTIFICATION': value ? 'ON' : 'OFF'});

  Future<PrivacyConfig> setNewContacts(bool value) =>
      updatePrivacyConfig({'PUSH_NEW_CONTACTS': value});

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

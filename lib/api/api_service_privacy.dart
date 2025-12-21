part of 'api_service.dart';

extension ApiServicePrivacy on ApiService {
  Future<void> updatePrivacySettings({
    String? hidden,
    String? searchByPhone,
    String? incomingCall,
    String? chatsInvite,
    bool? chatsPushNotification,
    String? chatsPushSound,
    String? pushSound,
    bool? mCallPushNotification,
    bool? pushDetails,
    bool? contentLevelAccess,
  }) async {
    print('');

    if (hidden != null) {
      await _updateSinglePrivacySetting({'HIDDEN': hidden == 'true'});
    }
    if (searchByPhone != null) {
      final seq = searchByPhone == 'ALL' ? 37 : 46;
      await _updatePrivacySettingWithSeq({
        'SEARCH_BY_PHONE': searchByPhone,
      }, seq);
    }
    if (incomingCall != null) {
      final seq = incomingCall == 'ALL' ? 30 : 23;
      await _updatePrivacySettingWithSeq({'INCOMING_CALL': incomingCall}, seq);
    }
    if (chatsInvite != null) {
      final seq = chatsInvite == 'ALL' ? 51 : 55;
      await _updatePrivacySettingWithSeq({'CHATS_INVITE': chatsInvite}, seq);
    }
    if (contentLevelAccess != null) {
      final seq = contentLevelAccess ? 70 : 62;
      await _updatePrivacySettingWithSeq({
        'CONTENT_LEVEL_ACCESS': contentLevelAccess,
      }, seq);
    }

    if (chatsPushNotification != null) {
      await _updateSinglePrivacySetting({
        'PUSH_NEW_CONTACTS': chatsPushNotification,
      });
    }
    if (chatsPushSound != null) {
      await _updateSinglePrivacySetting({'PUSH_SOUND': chatsPushSound});
    }
    if (pushSound != null) {
      await _updateSinglePrivacySetting({'PUSH_SOUND_GLOBAL': pushSound});
    }
    if (mCallPushNotification != null) {
      await _updateSinglePrivacySetting({'PUSH_MCALL': mCallPushNotification});
    }
    if (pushDetails != null) {
      await _updateSinglePrivacySetting({'PUSH_DETAILS': pushDetails});
    }
  }

  Future<void> _updateSinglePrivacySetting(Map<String, dynamic> setting) async {
    await waitUntilOnline();

    final payload = {
      'settings': {'user': setting},
    };

    _sendMessage(22, payload);
    print('');
  }

  Future<void> _updatePrivacySettingWithSeq(
    Map<String, dynamic> setting,
    int seq,
  ) async {
    await waitUntilOnline();

    final payload = {
        "settings": {"user": setting},
    };

    _sendMessage(22, payload);
    print('');
  }

  void _processServerPrivacyConfig(Map<String, dynamic>? config) {
    if (config == null) return;

    final userConfig = config['user'] as Map<String, dynamic>?;
    if (userConfig == null) return;

    print('Обработка настроек приватности с сервера: $userConfig');

    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) {
      if (userConfig.containsKey('SEARCH_BY_PHONE')) {
        prefs.setString(
          'privacy_search_by_phone',
          userConfig['SEARCH_BY_PHONE'],
        );
      }
      if (userConfig.containsKey('INCOMING_CALL')) {
        prefs.setString('privacy_incoming_call', userConfig['INCOMING_CALL']);
      }
      if (userConfig.containsKey('CHATS_INVITE')) {
        prefs.setString('privacy_chats_invite', userConfig['CHATS_INVITE']);
      }
      if (userConfig.containsKey('CONTENT_LEVEL_ACCESS')) {
        prefs.setBool(
          'privacy_content_level_access',
          userConfig['CONTENT_LEVEL_ACCESS'],
        );
      }
      if (userConfig.containsKey('HIDDEN')) {
        prefs.setBool('privacy_hidden', userConfig['HIDDEN']);
      }
    });

    _messageController.add({
      'type': 'privacy_settings_updated',
      'settings': {'user': userConfig},
    });
  }
}


import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/models/login_info.dart';

void main() {
  group('LoginInfo', () {
    test('extracts profile, packet, chat, and config data', () {
      final info = LoginInfo.fromPayload({
        'profile': {
          'contact': {
            'id': 100200300,
            'updateTime': 1700000002000,
            'registrationTime': 1700000001000,
            'baseUrl': 'https://example.invalid/avatar',
            'baseRawUrl': 'https://example.invalid/avatar/raw',
            'photoId': 400500600,
            'phone': 70000000000,
            'names': [
              {
                'name': 'Тест Пользователь',
                'firstName': 'Тест',
                'lastName': 'Пользователь',
                'type': 'SYNTHETIC',
              },
            ],
            'options': ['SYNTHETIC'],
            'accountStatus': 2,
            'country': 'ZZ',
          },
          'profileOptions': [7],
        },
        'chats': [
          {
            'id': -1001,
            'type': 'CHAT',
            'status': 'ACTIVE',
            'lastEventTime': 1700000008000,
            'newMessages': 3,
            'messagesCount': 12,
          },
          {
            'id': -1002,
            'type': 'CHANNEL',
            'status': 'HIDDEN',
            'lastEventTime': 1700000007000,
          },
          {
            'id': 1003,
            'type': 'DIALOG',
            'status': 'ACTIVE',
            'lastEventTime': 1700000006000,
          },
        ],
        'chatMarker': 1700000009000,
        'contacts': [
          {'id': 2001},
          {'id': 2002},
        ],
        'presence': {'synthetic-peer': 1700000003000},
        'messages': {'synthetic-message': {}},
        'config': {
          'hash': 'synthetic-config-hash',
          'server': {
            'known-flag': true,
            'nested': {'limit': 4},
          },
          'user': {'SYNTHETIC_SETTING': 'ON'},
          'chats': {
            'synthetic-chat': {'sound': false},
          },
          'experiments': {
            'synthetic-experiment': {'enabled': true},
          },
        },
        'videoChatHistory': true,
        'time': 1700000010000,
        'updates': 4,
      });

      expect(info['id'], 100200300);
      expect(info['phone'], 70000000000);
      expect(info['photoId'], 400500600);
      expect(info['accountStatus'], 2);
      expect(info['country'], 'ZZ');
      expect(info['profileOptions'], [7]);
      expect(info['contactOptions'], ['SYNTHETIC']);
      expect(info['chatMarker'], 1700000009000);
      expect(info['contactsCount'], 2);
      expect(info['presenceCount'], 1);
      expect(info['messagesCount'], 1);
      expect(info['configHash'], 'synthetic-config-hash');
      expect(info['chats'], {
        'count': 3,
        'active': 2,
        'hidden': 1,
        'dialogs': 1,
        'groups': 1,
        'channels': 1,
        'unread': 1,
        'newMessages': 3,
        'messages': 12,
      });
      expect(info['server'], {
        'known-flag': true,
        'nested': {'limit': 4},
      });
      expect(info['user'], {'SYNTHETIC_SETTING': 'ON'});
      expect(info['chatSettings'], {
        'synthetic-chat': {'sound': false},
      });
      expect(info['experiments'], {
        'synthetic-experiment': {'enabled': true},
      });
      expect(() => jsonEncode(info), returnsNormally);
    });

    test('falls back to latest chat event when marker is absent', () {
      final info = LoginInfo.fromPayload({
        'chats': [
          {'lastEventTime': 1700000004000},
          {'lastEventTime': 1700000006000},
          {'lastEventTime': 1700000005000},
        ],
      });

      expect(info['chatMarker'], 1700000006000);
      expect(info['chats'], {
        'count': 3,
        'active': 0,
        'hidden': 0,
        'dialogs': 0,
        'groups': 0,
        'channels': 0,
        'unread': 0,
        'newMessages': 0,
        'messages': 0,
      });
    });
  });
}

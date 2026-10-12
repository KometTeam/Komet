import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/screens/chats/chat_admin/admins_screen.dart';
import 'package:komet/frontend/screens/chats/chat_admin/channel_type_link_screen.dart';
import 'package:komet/frontend/screens/chats/chat_admin/chat_admin_state.dart';
import 'package:komet/frontend/screens/chats/chat_admin/chat_settings_screen.dart';
import 'package:komet/frontend/screens/profile/komet_settings_screen.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/main.dart' show api;
import 'package:komet/models/chat_info.dart';

final _cyrillic = RegExp('[А-Яа-яЁё]');

ChatAdminState _state(String type) => ChatAdminState(
  chatId: -1000,
  myId: 11,
  name: 'Synthetic chat',
  imageUrl: '',
  info: ChatInfo.fromMap({
    'id': -1000,
    'type': type,
    'owner': 11,
    'access': 'PRIVATE',
    'link': 'https://example.test/join/synthetic',
    'participantsCount': 3,
    'adminParticipants': {
      '11': {'id': 11, 'permissions': 4095},
    },
    'options': {'JOIN_REQUEST': true, 'COMMENTS': false},
  }),
);

CachedMessage _message(String id, {Map<String, dynamic>? payload}) =>
    CachedMessage(
      id: id,
      accountId: 1,
      chatId: 2,
      senderId: 7,
      text: 'Synthetic text',
      time: DateTime(2026, 1, 1, 12, 30).millisecondsSinceEpoch,
      status: 'EDITED',
      payload: payload,
    );

final _screens = <String, Widget Function()>{
  'channel settings': () => ChatSettingsScreen(
    state: _state('CHANNEL'),
    onLeave: () {},
    onClearHistory: () {},
    onDelete: () {},
  ),
  'group settings': () =>
      ChatSettingsScreen(state: _state('CHAT'), onLeave: () {}),
  'channel type and link': () =>
      ChannelTypeLinkScreen(state: _state('CHANNEL'), justCreated: true),
  'admins': () => AdminsScreen(state: _state('CHANNEL')),
  'komet settings': () => const KometSettingsScreen(),
  'message bubbles': () => Scaffold(
    body: ListView(
      children: [
        MessageBubble(
          message: _message('1'),
          isMe: true,
          myId: 1,
          chatType: 'CHAT',
        ),
        MessageBubble(
          message: _message(
            '2',
            payload: {
              'link': {
                'type': 'FORWARD',
                'chatId': 5,
                'message': {
                  'id': '9',
                  'sender': 3,
                  'text': 'Forwarded synthetic text',
                  'time': 0,
                  'attaches': [],
                },
              },
            },
          ),
          isMe: false,
          myId: 1,
          chatType: 'CHAT',
        ),
      ],
    ),
  ),
};

void main() {
  setUpAll(() => api.state);

  for (final entry in _screens.entries) {
    testWidgets('${entry.key} has no Russian in the English locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: entry.value(),
        ),
      );
      await tester.pump();

      final russian = [
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          if ((text.data ?? text.textSpan?.toPlainText() ?? '').contains(
            _cyrillic,
          ))
            text.data ?? text.textSpan!.toPlainText(),
        for (final rich in tester.widgetList<RichText>(find.byType(RichText)))
          if (rich.text.toPlainText().contains(_cyrillic))
            rich.text.toPlainText(),
      ];
      expect(russian, isEmpty);
    });
  }

  test('russian plurals agree with numbers ending in one', () {
    final ru = lookupAppLocalizations(const Locale('ru'));

    expect(ru.sharedMembersCount(1), '1 участник');
    expect(ru.sharedMembersCount(21), '21 участник');
    expect(ru.sharedMembersCount(22), '22 участника');
    expect(ru.pasteAttachTitleMany(21), 'Отправить 21 файл');
    expect(ru.pasteAttachTitleMany(25), 'Отправить 25 файлов');
  });
}

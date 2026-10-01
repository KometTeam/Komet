import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat_admin/admin_section.dart';
import 'package:komet/frontend/screens/chats/chat_admin/chat_admin_state.dart';
import 'package:komet/frontend/screens/chats/chat_admin/admins_screen.dart';
import 'package:komet/frontend/screens/chats/chat_admin/channel_followers_screen.dart';
import 'package:komet/frontend/screens/chats/chat_admin/channel_invite_link_screen.dart';
import 'package:komet/frontend/screens/chats/chat_admin/group_settings_screen.dart';
import 'package:komet/frontend/screens/chats/chat_admin/member_permissions_screen.dart';
import 'package:komet/frontend/screens/chats/chat_admin/ownership_transfer.dart';
import 'package:komet/frontend/widgets/settings_card.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/main.dart' show api;
import 'package:komet/models/chat_info.dart';
import 'package:material_symbols_icons/symbols.dart';

const _ownerId = 11;
const _adminId = 22;

ChatAdminState _state({
  required int myId,
  int adminPermissions = 1828,
  String type = 'CHANNEL',
  Map<String, bool> options = const {'JOIN_REQUEST': false},
}) => ChatAdminState(
  chatId: -1000,
  myId: myId,
  name: 'Synthetic channel',
  imageUrl: '',
  info: ChatInfo.fromMap({
    'id': -1000,
    'type': type,
    'owner': _ownerId,
    'access': 'PRIVATE',
    'link': 'https://example.test/join/synthetic',
    'participantsCount': 3,
    'adminParticipants': {
      '$_ownerId': {'id': _ownerId, 'permissions': 4095},
      '$_adminId': {'id': _adminId, 'permissions': adminPermissions},
    },
    'options': options,
  }),
);

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => api.state);

  testWidgets('the info section shows both counters and statistics', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: AdminSection(
          state: _state(myId: _ownerId),
          onLeave: () {},
        ),
      ),
    );

    expect(find.widgetWithText(SettingsNavTile, 'Администраторы'), findsOne);
    expect(find.widgetWithText(SettingsNavTile, '2'), findsOne);
    expect(find.widgetWithText(SettingsNavTile, 'Подписчики'), findsOne);
    expect(find.widgetWithText(SettingsNavTile, '3'), findsOne);
    expect(find.text('Статистика канала'), findsOne);

    await tester.tap(find.text('Статистика канала'));
    await tester.pump();
    expect(find.text('Статистика канала пока недоступна'), findsOne);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the owner sees every admin and can add more', (tester) async {
    await _pump(tester, AdminsScreen(state: _state(myId: _ownerId)));

    expect(find.text('Добавить администратора'), findsOne);
    expect(find.text('Владелец (вы)'), findsOne);
    expect(find.text('Админ'), findsOne);
  });

  testWidgets('an admin without the right cannot add admins', (tester) async {
    await _pump(
      tester,
      AdminsScreen(state: _state(myId: _adminId, adminPermissions: 16)),
    );

    expect(find.text('Добавить администратора'), findsNothing);
    expect(find.text('Владелец'), findsOne);
    expect(find.text('Админ (вы)'), findsOne);
  });

  testWidgets('the invite link screen offers every link action', (
    tester,
  ) async {
    await _pump(tester, ChannelInviteLinkScreen(state: _state(myId: _ownerId)));

    expect(find.text('example.test/join/synthetic'), findsOne);
    expect(find.text('Отправить в MAX'), findsOne);
    expect(find.text('Показать QR-код'), findsOne);
    expect(find.text('Заявки на вступление'), findsOne);
    expect(find.byIcon(Symbols.more_vert), findsOne);

    await tester.tap(find.byIcon(Symbols.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Перевыпустить ссылку'), findsOne);
  });

  testWidgets('an admin without follower rights only shares the link', (
    tester,
  ) async {
    await _pump(
      tester,
      ChannelInviteLinkScreen(
        state: _state(myId: _adminId, adminPermissions: 32),
      ),
    );

    expect(find.text('Отправить в MAX'), findsOne);
    expect(find.text('Заявки на вступление'), findsNothing);
    expect(find.byIcon(Symbols.more_vert), findsNothing);
  });

  testWidgets('the followers screen offers adding and inviting', (
    tester,
  ) async {
    await _pump(tester, ChannelFollowersScreen(state: _state(myId: _ownerId)));
    await tester.pump();

    expect(find.text('Найти по имени'), findsOne);
    expect(find.text('Добавить подписчиков'), findsOne);
    expect(find.text('Пригласить по ссылке'), findsOne);
  });

  testWidgets('followers without the right are read-only', (tester) async {
    await _pump(
      tester,
      ChannelFollowersScreen(
        state: _state(myId: _adminId, adminPermissions: 32),
      ),
    );
    await tester.pump();

    expect(find.text('Добавить подписчиков'), findsNothing);
    expect(find.text('Пригласить по ссылке'), findsOne);
  });

  testWidgets('a group shows admins and settings in one card', (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: AdminSection(
          state: _state(myId: _ownerId, type: 'CHAT'),
          onLeave: () {},
        ),
      ),
    );

    expect(find.widgetWithText(SettingsNavTile, 'Администраторы'), findsOne);
    expect(find.widgetWithText(SettingsNavTile, 'Настройки группы'), findsOne);
    expect(find.text('Подписчики'), findsNothing);
    expect(find.text('Статистика канала'), findsNothing);
  });

  testWidgets('the owner sees every group setting', (tester) async {
    await _pump(
      tester,
      GroupSettingsScreen(
        state: _state(myId: _ownerId, type: 'CHAT'),
        onLeave: () {},
      ),
    );
    await tester.pump();

    expect(find.text('Synthetic channel'), findsOne);
    expect(find.text('НАЗВАНИЕ ЧАТА'), findsOne);
    expect(find.text('ОПИСАНИЕ ЧАТА'), findsOne);
    expect(find.text('Реакции'), findsOne);
    expect(find.text('Передать права владельца'), findsOne);
    expect(find.text('Покинуть чат'), findsOne);
    expect(find.text('Разрешения участников'), findsOne);
  });

  testWidgets('saving waits for a real change', (tester) async {
    await _pump(
      tester,
      GroupSettingsScreen(
        state: _state(myId: _ownerId, type: 'CHAT'),
        onLeave: () {},
      ),
    );

    IconButton save() => tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Symbols.check),
    );
    expect(save().onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Synthetic renamed');
    await tester.pump();
    expect(save().onPressed, isNotNull);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    expect(save().onPressed, isNull);
  });

  testWidgets('a member with edit rights only edits the basics', (
    tester,
  ) async {
    await _pump(
      tester,
      GroupSettingsScreen(
        state: _state(
          myId: 99,
          type: 'CHAT',
          options: {'ONLY_OWNER_CAN_CHANGE_ICON_TITLE': false},
        ),
        onLeave: () {},
      ),
    );

    expect(find.text('Реакции'), findsNothing);
    expect(find.text('Передать права владельца'), findsNothing);
    expect(find.text('Разрешения участников'), findsNothing);
    expect(find.text('Покинуть чат'), findsOne);
  });

  testWidgets('member permissions mirror the chat options', (tester) async {
    await _pump(
      tester,
      MemberPermissionsScreen(
        state: _state(
          myId: _ownerId,
          type: 'CHAT',
          options: {
            'ONLY_OWNER_CAN_CHANGE_ICON_TITLE': true,
            'ONLY_ADMIN_CAN_ADD_MEMBER': false,
            'ALL_CAN_PIN_MESSAGE': true,
            'MEMBERS_CAN_SEE_PRIVATE_LINK': false,
            'ONLY_ADMIN_CAN_CALL': false,
          },
        ),
      ),
    );

    bool value(String label) => tester
        .widget<SettingsToggleTile>(
          find.widgetWithText(SettingsToggleTile, label),
        )
        .value;
    expect(value('Изменять название, фото и описание чата'), isFalse);
    expect(value('Добавлять участников'), isTrue);
    expect(value('Закреплять сообщения'), isTrue);
    expect(value('Приглашать по ссылке'), isFalse);
    expect(value('Звонить в чате'), isTrue);
  });

  testWidgets('the owner must hand over the chat before leaving', (
    tester,
  ) async {
    final owner = _state(myId: _ownerId, type: 'CHAT');
    late BuildContext context;
    await _pump(
      tester,
      Builder(
        builder: (built) {
          context = built;
          return const SizedBox();
        },
      ),
    );

    final result = transferBeforeLeaving(context, owner);
    await tester.pumpAndSettle();
    expect(find.text('Вы владелец'), findsOne);
    expect(
      find.text(
        'Чтобы покинуть группу, сначала передайте права владельца '
        'другому участнику.',
      ),
      findsOne,
    );

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('anyone else leaves without the ownership step', (tester) async {
    late BuildContext context;
    await _pump(
      tester,
      Builder(
        builder: (built) {
          context = built;
          return const SizedBox();
        },
      ),
    );

    expect(
      await transferBeforeLeaving(
        context,
        _state(myId: _adminId, type: 'CHAT'),
      ),
      isTrue,
    );
  });

  testWidgets('a sole owner leaves without handing anything over', (
    tester,
  ) async {
    late BuildContext context;
    await _pump(
      tester,
      Builder(
        builder: (built) {
          context = built;
          return const SizedBox();
        },
      ),
    );
    final alone = ChatAdminState(
      chatId: -2000,
      myId: _ownerId,
      name: 'Synthetic alone',
      imageUrl: '',
      info: ChatInfo.fromMap({
        'id': -2000,
        'type': 'CHAT',
        'owner': _ownerId,
        'participantsCount': 1,
      }),
    );

    expect(await transferBeforeLeaving(context, alone), isTrue);
    expect(find.text('Вы владелец'), findsNothing);
  });

  testWidgets('group restrictions show the server values', (tester) async {
    await _pump(
      tester,
      GroupSettingsScreen(
        state: _state(
          myId: _ownerId,
          type: 'CHAT',
          options: {
            'DISABLE_FORWARD': true,
            'MESSAGE_COPY_NOT_ALLOWED': false,
            'CONFIRM_BEFORE_SEND': true,
          },
        ),
        onLeave: () {},
      ),
    );

    bool value(String label) => tester
        .widget<SettingsToggleTile>(
          find.widgetWithText(SettingsToggleTile, label),
        )
        .value;
    expect(find.text('ОГРАНИЧЕНИЯ'), findsOne);
    expect(value('Запретить пересылку'), isTrue);
    expect(value('Запретить копирование'), isFalse);
    expect(value('Подтверждать отправку'), isTrue);
  });

  testWidgets('members do not see group restrictions', (tester) async {
    await _pump(
      tester,
      GroupSettingsScreen(
        state: _state(
          myId: 99,
          type: 'CHAT',
          options: {'ONLY_OWNER_CAN_CHANGE_ICON_TITLE': false},
        ),
        onLeave: () {},
      ),
    );

    expect(find.text('ОГРАНИЧЕНИЯ'), findsNothing);
    expect(find.text('Запретить пересылку'), findsNothing);
  });
}

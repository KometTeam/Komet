import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat_admin/admin_rights_screen.dart';
import 'package:komet/frontend/screens/chats/chat_admin/chat_admin_state.dart';
import 'package:komet/frontend/widgets/settings_card.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/chat_info.dart';

const _ownerId = 11;
const _adminId = 22;
const _followerId = 33;

ChatAdminState _state({
  required int myId,
  String type = 'CHANNEL',
  int adminPermissions = 1828,
  bool everyoneCanPin = false,
}) => ChatAdminState(
  chatId: -1000,
  myId: myId,
  name: 'Synthetic chat',
  imageUrl: '',
  info: ChatInfo.fromMap({
    'id': -1000,
    'type': type,
    'owner': _ownerId,
    'adminParticipants': {
      '$_ownerId': {'id': _ownerId, 'permissions': 4095},
      '$_adminId': {'id': _adminId, 'permissions': adminPermissions},
    },
    'options': {'ALL_CAN_PIN_MESSAGE': everyoneCanPin},
  }),
);

Future<void> _pump(
  WidgetTester tester, {
  required ChatAdminState state,
  required int userId,
  required bool appointing,
}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminRightsScreen(
        state: state,
        userId: userId,
        name: 'Synthetic person',
        appointing: appointing,
      ),
    ),
  );
  await tester.pump();
}

SettingsToggleTile _toggle(WidgetTester tester, String label) => tester
    .widget<SettingsToggleTile>(find.widgetWithText(SettingsToggleTile, label));

FilledButton _button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

void main() {
  testWidgets('appointing starts with every right granted', (tester) async {
    await _pump(
      tester,
      state: _state(myId: _ownerId),
      userId: _followerId,
      appointing: true,
    );

    expect(find.text('Назначить администратора'), findsOneWidget);
    final toggles = tester.widgetList<SettingsToggleTile>(
      find.byType(SettingsToggleTile),
    );
    expect(toggles, hasLength(8));
    expect(toggles.every((toggle) => toggle.value && toggle.enabled), isTrue);
    expect(_button(tester, 'Назначить администратором').onPressed, isNotNull);
    expect(find.text('Передать права владельца'), findsNothing);
    expect(find.text('Снять с администраторов'), findsNothing);
  });

  testWidgets('the owner edits an admin and can hand over the channel', (
    tester,
  ) async {
    await _pump(
      tester,
      state: _state(myId: _ownerId),
      userId: _adminId,
      appointing: false,
    );

    expect(find.text('Права администратора'), findsOneWidget);
    expect(_toggle(tester, 'Публиковать посты').value, isTrue);
    expect(_toggle(tester, 'Изменять канал').value, isFalse);
    expect(_button(tester, 'Сохранить').onPressed, isNull);
    expect(find.text('Передать права владельца'), findsOneWidget);
    expect(find.text('Снять с администраторов'), findsOneWidget);

    await tester.tap(find.text('Изменять канал'));
    await tester.pump();

    expect(_toggle(tester, 'Изменять канал').value, isTrue);
    expect(_button(tester, 'Сохранить').onPressed, isNotNull);
  });

  testWidgets('an admin only grants rights they hold', (tester) async {
    await _pump(
      tester,
      state: _state(myId: _adminId),
      userId: _followerId,
      appointing: true,
    );

    expect(_toggle(tester, 'Публиковать посты').enabled, isTrue);
    expect(
      _toggle(tester, 'Назначать и снимать администраторов').enabled,
      isTrue,
    );
    expect(_toggle(tester, 'Публиковать посты').value, isTrue);
    expect(_toggle(tester, 'Изменять канал').enabled, isFalse);
    expect(_toggle(tester, 'Изменять канал').value, isFalse);
    expect(_toggle(tester, 'Закреплять посты').enabled, isFalse);
    expect(_toggle(tester, 'Закреплять посты').value, isFalse);
    expect(_toggle(tester, 'Добавлять и удалять подписчиков').enabled, isFalse);
    expect(_toggle(tester, 'Смотреть статистику канала').enabled, isFalse);
  });

  testWidgets('a group admin gets the group switches', (tester) async {
    await _pump(
      tester,
      state: _state(myId: _ownerId, type: 'CHAT'),
      userId: _followerId,
      appointing: true,
    );

    final toggles = tester.widgetList<SettingsToggleTile>(
      find.byType(SettingsToggleTile),
    );
    expect(toggles, hasLength(6));
    expect(_toggle(tester, 'Изменять чат').value, isTrue);
    expect(_toggle(tester, 'Удалять сообщения').value, isTrue);
    expect(_toggle(tester, 'Закреплять сообщения').value, isTrue);
    expect(_toggle(tester, 'Добавлять и удалять участников').value, isTrue);
    expect(_toggle(tester, 'Обновлять ссылку на чат').value, isFalse);
    expect(
      _toggle(tester, 'Назначать и снимать администраторов').value,
      isFalse,
    );
    expect(find.text('Публиковать посты'), findsNothing);
  });

  testWidgets('pinning is locked on when every member may pin', (tester) async {
    await _pump(
      tester,
      state: _state(
        myId: _ownerId,
        type: 'CHAT',
        adminPermissions: 1,
        everyoneCanPin: true,
      ),
      userId: _adminId,
      appointing: false,
    );

    final pin = _toggle(tester, 'Закреплять сообщения');
    expect(pin.value, isTrue);
    expect(pin.enabled, isFalse);
    expect(_toggle(tester, 'Удалять сообщения').value, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/calls/call_session.dart';
import 'package:komet/core/calls/ws2_signaling.dart';
import 'package:komet/frontend/screens/calls/call_participant_tile.dart';
import 'package:komet/frontend/screens/calls/call_participants_sheet.dart';
import 'package:komet/frontend/screens/calls/call_stage.dart';
import 'package:komet/frontend/screens/calls/group_call_view.dart';
import 'package:komet/l10n/app_localizations.dart';

const _selfId = 1001;

CallSession _session() => CallSession(
  ws2Config: Ws2Config(
    uri: Uri.parse('wss://calls.invalid/ws'),
    userId: _selfId,
  ),
  role: CallRole.joiner,
  isGroup: true,
);

Future<void> _join(
  CallSession session,
  int id, {
  bool audio = true,
  bool video = false,
  bool screen = false,
}) => session.debugHandleNotification({
  'notification': 'participant-joined',
  'participant': {
    'id': id,
    'externalId': {'id': '${id + 500}'},
    'mediaSettings': {
      'isAudioEnabled': audio,
      'isVideoEnabled': video,
      'isScreenSharingEnabled': screen,
    },
    'roles': const <String>[],
  },
});

Widget _app(CallSession session, {CallMediaBuilder? mediaOf}) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(
    body: GroupCallView(
      session: session,
      title: 'Тестовый звонок',
      resolve: (p) => CallParticipantView(
        name: p.isSelf ? 'Вы' : 'Участник ${p.id}',
        contactId: p.externalId,
      ),
      mediaOf: mediaOf ?? (p, avatar, {source, stage = false}) => null,
      videoOf: (p) => null,
      muted: false,
      speakerOn: false,
      videoBusy: false,
      onToggleMute: () {},
      onToggleSpeaker: () {},
      onToggleVideo: () {},
      onSwitchCamera: () {},
      onToggleScreen: () {},
      onHangup: () {},
      onMinimize: () {},
      onShowMicrophones: () {},
      onShowInfo: () {},
    ),
  ),
);

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  CallSession session, {
  CallMediaBuilder? mediaOf,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(session, mediaOf: mediaOf));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  for (final size in const [Size(360, 740), Size(1280, 800)]) {
    testWidgets('групповой звонок раскладывается без переполнений на $size', (
      tester,
    ) async {
      final session = _session();
      await _join(session, _selfId);
      for (var id = 2; id <= 6; id++) {
        await _join(session, id, audio: id.isEven);
      }

      await _pumpAt(tester, size, session);

      expect(tester.takeException(), isNull);
      expect(find.byType(CallParticipantTile), findsNWidgets(6));
      expect(find.text('Тестовый звонок'), findsOneWidget);
      expect(find.text('6 участников'), findsOneWidget);
    });
  }

  testWidgets('в одиночку рядом с собой видна плитка приглашения', (
    tester,
  ) async {
    final session = _session();
    await _join(session, _selfId);

    await _pumpAt(tester, const Size(1280, 800), session);

    expect(find.text('Пригласите других участников'), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Пригласите других участников'), findsNothing);
  });

  testWidgets('поднятая рука участника видна на его плитке', (tester) async {
    final session = _session();
    await _join(session, _selfId);
    await _join(session, 2);
    await _join(session, 3);

    await _pumpAt(tester, const Size(1280, 800), session);
    expect(
      tester
          .widgetList<CallParticipantTile>(find.byType(CallParticipantTile))
          .where((t) => t.handRaised),
      isEmpty,
    );

    await session.debugHandleNotification({
      'notification': 'participant-state-changed',
      'participantId': 3,
      'participantState': {
        'state': {'hand': '1'},
        'stateUpdateTs': {'hand': 1000},
      },
    });
    await tester.pump(const Duration(milliseconds: 400));

    final raised = tester
        .widgetList<CallParticipantTile>(find.byType(CallParticipantTile))
        .where((t) => t.handRaised)
        .toList();
    expect(raised.map((t) => t.name), ['Участник 3']);

    await session.debugHandleNotification({
      'notification': 'participant-state-changed',
      'participantId': 3,
      'participantState': {'state': const {}, 'stateUpdateTs': const {}},
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widgetList<CallParticipantTile>(find.byType(CallParticipantTile))
          .where((t) => t.handRaised),
      isEmpty,
    );
  });

  testWidgets('«опустить всем руки» без participantState опускает руку', (
    tester,
  ) async {
    final session = _session();
    await _join(session, _selfId);
    await _join(session, 2);
    await session.debugHandleNotification({
      'notification': 'participant-state-changed',
      'participantId': 2,
      'participantState': {
        'state': {'hand': '1'},
        'stateUpdateTs': {'hand': 1000},
      },
    });

    await _pumpAt(tester, const Size(1280, 800), session);
    expect(session.raisedHands.map((p) => p.id), [2]);

    await session.debugHandleNotification({
      'notification': 'participants-state-changed',
      'participants': [
        {'id': 'u2'},
      ],
    });
    await tester.pump(const Duration(milliseconds: 400));

    expect(session.raisedHands, isEmpty);
    expect(
      tester
          .widgetList<CallParticipantTile>(find.byType(CallParticipantTile))
          .where((t) => t.handRaised),
      isEmpty,
    );
  });

  testWidgets('камеру видно на плитке, её можно развернуть на сцену', (
    tester,
  ) async {
    final session = _session();
    await _join(session, _selfId);
    await _join(session, 2, video: true);
    await _join(session, 3);
    await _join(session, 4, screen: true);

    await _pumpAt(tester, const Size(1280, 800), session);
    expect(find.byType(CallExpandButton), findsNWidgets(2));
    expect(session.debugDisplayLayout().layouts.keys, {
      'u2:sCAMERA',
      'u4:sSCREEN',
    });

    final screenTile = find.ancestor(
      of: find.text('Участник 4'),
      matching: find.byType(CallParticipantTile),
    );
    await tester.tap(
      find.descendant(of: screenTile, matching: find.byType(CallExpandButton)),
    );
    await _settle(tester);

    expect(find.byType(CallStage), findsOneWidget);
    expect(find.text('Экран Участник 4'), findsOneWidget);
    expect(
      session.debugDisplayLayout().layouts['u4:sSCREEN'],
      'sz=1280x720:fit=cn',
    );
    expect(find.byType(CallParticipantTile), findsNWidgets(4));

    await tester.tap(find.byTooltip('Обычный вид'));
    await _settle(tester);
    expect(find.byType(CallStage), findsNothing);
    expect(
      session.debugDisplayLayout().layouts['u4:sSCREEN'],
      isNot('sz=1280x720:fit=cn'),
    );
  });

  testWidgets('«на весь экран» оставляет только трансляцию', (tester) async {
    final session = _session();
    await _join(session, _selfId);
    await _join(session, 2, video: true);
    await _join(session, 4, screen: true);

    await _pumpAt(tester, const Size(1280, 800), session);
    final screenTile = find.ancestor(
      of: find.text('Участник 4'),
      matching: find.byType(CallParticipantTile),
    );
    await tester.tap(
      find.descendant(of: screenTile, matching: find.byType(CallExpandButton)),
    );
    await _settle(tester);
    expect(find.byType(CallParticipantTile), findsWidgets);
    expect(find.text('Тестовый звонок'), findsOneWidget);

    await tester.tap(find.byTooltip('На весь экран'));
    await _settle(tester);
    expect(find.byType(CallStage), findsOneWidget);
    expect(find.text('Экран Участник 4'), findsOneWidget);
    expect(find.byType(CallParticipantTile), findsNothing);
    expect(find.text('Тестовый звонок'), findsNothing);
    expect(find.byTooltip('Обычный вид'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byType(CallStage), findsOneWidget);
    expect(find.byType(CallParticipantTile), findsWidgets);
    expect(find.text('Тестовый звонок'), findsOneWidget);
  });

  testWidgets('сцена закрывается, когда трансляция заканчивается', (
    tester,
  ) async {
    final session = _session();
    await _join(session, _selfId);
    await _join(session, 2, screen: true);

    await _pumpAt(tester, const Size(360, 740), session);
    await tester.tap(find.byType(CallExpandButton));
    await _settle(tester);
    expect(find.byType(CallStage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await session.debugHandleNotification({
      'notification': 'media-settings-changed',
      'participantId': 2,
      'mediaSettings': const {'isAudioEnabled': true},
    });
    await _settle(tester);

    expect(find.byType(CallStage), findsNothing);
    expect(find.byType(CallExpandButton), findsNothing);
  });

  testWidgets('лента под сценой прокручивается на узком экране', (
    tester,
  ) async {
    final session = _session();
    await _join(session, _selfId);
    await _join(session, 2, screen: true);
    for (var id = 3; id <= 9; id++) {
      await _join(session, id, video: id.isOdd);
    }

    await _pumpAt(tester, const Size(360, 740), session);
    final screenTile = find.ancestor(
      of: find.text('Участник 2'),
      matching: find.byType(CallParticipantTile),
    );
    await tester.tap(
      find.descendant(of: screenTile, matching: find.byType(CallExpandButton)),
    );
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(CallStage), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(session.debugDisplayLayout().cameras.length, lessThanOrEqualTo(4));
  });

  testWidgets('кнопка «i» заливает плитку технической информацией', (
    tester,
  ) async {
    final session = _session();
    await _join(session, _selfId);
    await session.debugHandleNotification({
      'notification': 'participant-joined',
      'participant': {
        'id': 2,
        'externalId': {'id': '502', 'type': 'ONE_ME'},
        'state': 'ACCEPTED',
        'mediaSettings': {'isAudioEnabled': true},
      },
    });
    await session.debugHandleNotification({
      'notification': 'registered-peer',
      'participantId': 2,
      'clientType': 'ONE_ME',
      'platform': 'WEB',
      'peerId': {'id': 9, 'type': 'WEB_TRANSPORT'},
    });

    await _pumpAt(tester, const Size(1280, 800), session);
    expect(find.text('Аккаунт MAX'), findsNothing);

    final tile = find.ancestor(
      of: find.text('Участник 2'),
      matching: find.byType(CallParticipantTile),
    );
    await tester.tap(
      find.descendant(
        of: tile,
        matching: find.byTooltip('Техническая информация'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Аккаунт MAX'), findsOneWidget);
    expect(find.text('502'), findsOneWidget);
    expect(find.text('WEB'), findsOneWidget);
    expect(find.text('WEB_TRANSPORT'), findsOneWidget);

    await tester.tap(find.byTooltip('Скрыть информацию'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Аккаунт MAX'), findsNothing);
  });

  testWidgets('плохая сеть и зависшее видео видны на плитке', (tester) async {
    final session = _session();
    await _join(session, _selfId);
    await _join(session, 2, video: true);
    await _join(session, 3, video: true);

    await _pumpAt(
      tester,
      const Size(1280, 800),
      session,
      mediaOf: (p, avatar, {source, stage = false}) =>
          p.videoEnabled ? const ColoredBox(color: Colors.teal) : null,
    );
    expect(find.byTooltip('Соединение 10%'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    session.debugSfuNetwork({'u2': 0.1});
    session.debugSfuStalled({'u3'});
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('Соединение 10%'), findsOneWidget);
    final stalledTile = find.ancestor(
      of: find.text('Участник 3'),
      matching: find.byType(CallParticipantTile),
    );
    expect(
      find.descendant(
        of: stalledTile,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    session.debugSfuStalled(const {});
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('шкала сети видна с 60% и пропадает на хорошей сети', (
    tester,
  ) async {
    final session = _session();
    await _join(session, _selfId);
    await _join(session, 2);

    await _pumpAt(tester, const Size(1280, 800), session);
    session.debugSfuNetwork({'u2': 0.7});
    await _settle(tester);
    expect(find.byTooltip('Соединение 70%'), findsNothing);

    session.debugSfuNetwork({'u2': 0.55});
    await _settle(tester);
    expect(find.byTooltip('Соединение 55%'), findsOneWidget);

    session.debugSfuNetwork({'u2': 0.25});
    await _settle(tester);
    expect(find.byTooltip('Соединение 25%'), findsOneWidget);

    session.debugSfuNetwork({'u2': 0.9});
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Соединение 90%'), findsNothing);
  });
}

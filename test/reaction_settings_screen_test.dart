import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat_admin/chat_admin_state.dart';
import 'package:komet/frontend/screens/chats/chat_admin/reaction_settings_screen.dart';
import 'package:komet/frontend/widgets/settings_card.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/main.dart' show api;
import 'package:komet/models/chat_info.dart';
import 'package:komet/models/chat_reaction_settings.dart';
import 'package:material_symbols_icons/symbols.dart';

class _SeededState extends ChatAdminState {
  ChatReactionSettings seeded;
  final List<String> saves = [];

  _SeededState(this.seeded)
    : super(
        chatId: -1000,
        myId: 11,
        name: 'Synthetic group',
        imageUrl: '',
        info: ChatInfo.fromMap({'id': -1000, 'type': 'CHAT', 'owner': 11}),
      );

  @override
  ChatReactionSettings? get reactions => seeded;

  @override
  Future<void> loadReactions() async {}

  @override
  Future<void> disableReactions() async {
    saves.add('off');
    seeded = ChatReactionSettings(
      isActive: false,
      count: seeded.count,
      included: false,
      reactionIds: seeded.reactionIds,
    );
    notifyListeners();
  }

  @override
  Future<void> setReactions({
    required int count,
    required List<String> forbidden,
  }) async {
    saves.add('on $count $forbidden');
    seeded = ChatReactionSettings(
      isActive: true,
      count: count,
      included: false,
      reactionIds: forbidden,
    );
    notifyListeners();
  }
}

Future<_SeededState> _pump(
  WidgetTester tester,
  ChatReactionSettings settings,
) async {
  final state = _SeededState(settings);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReactionSettingsScreen(state: state),
    ),
  );
  await tester.pump();
  await tester.pump();
  return state;
}

VoidCallback? _save(WidgetTester tester) => tester
    .widget<IconButton>(find.widgetWithIcon(IconButton, Symbols.check))
    .onPressed;

void main() {
  setUpAll(() => api.state);

  testWidgets('shows the count and offers a reset when restricted', (
    tester,
  ) async {
    await _pump(
      tester,
      const ChatReactionSettings(
        isActive: true,
        count: 4,
        included: false,
        reactionIds: ['😴'],
      ),
    );

    expect(
      tester.widget<SettingsToggleTile>(find.byType(SettingsToggleTile)).value,
      isTrue,
    );
    expect(find.text('КОЛИЧЕСТВО РЕАКЦИЙ К ПУБЛИКАЦИИ'), findsOne);
    expect(find.text('4 реакции'), findsOne);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 4);
    expect(find.text('Сбросить настройки реакций'), findsOne);
  });

  testWidgets('hides everything but the switch when reactions are off', (
    tester,
  ) async {
    await _pump(
      tester,
      const ChatReactionSettings(
        isActive: false,
        count: 8,
        included: false,
        reactionIds: [],
      ),
    );

    expect(find.byType(Slider), findsNothing);
    expect(find.text('Сбросить настройки реакций'), findsNothing);
  });

  testWidgets('no reset while every reaction is allowed', (tester) async {
    await _pump(
      tester,
      const ChatReactionSettings(
        isActive: true,
        count: 8,
        included: false,
        reactionIds: [],
      ),
    );

    expect(find.text('8 реакций'), findsOne);
    expect(find.text('Сбросить настройки реакций'), findsNothing);
  });

  testWidgets('switching reactions off waits for save', (tester) async {
    final state = await _pump(
      tester,
      const ChatReactionSettings(
        isActive: true,
        count: 8,
        included: false,
        reactionIds: [],
      ),
    );
    expect(_save(tester), isNull);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(state.saves, isEmpty);
    expect(find.byType(Slider), findsNothing);
    expect(_save(tester), isNotNull);

    await tester.tap(find.widgetWithIcon(IconButton, Symbols.check));
    await tester.pump();

    expect(state.saves, ['off']);
    expect(_save(tester), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('moving the slider saves the new count with the same list', (
    tester,
  ) async {
    final state = await _pump(
      tester,
      const ChatReactionSettings(
        isActive: true,
        count: 8,
        included: false,
        reactionIds: ['😴'],
      ),
    );

    await tester.drag(find.byType(Slider), const Offset(-2000, 0));
    await tester.pump();
    expect(find.text('1 реакция'), findsOne);
    expect(state.saves, isEmpty);

    await tester.tap(find.widgetWithIcon(IconButton, Symbols.check));
    await tester.pump();

    expect(state.saves, ['on 1 [😴]']);
    await tester.pump(const Duration(seconds: 3));
  });
}

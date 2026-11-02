import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/komet_settings.dart';
import 'package:komet/frontend/screens/chats/chat/channel_recommendations.dart';
import 'package:komet/frontend/screens/chats/chat/view/channel_recommendations_view.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/frontend/widgets/small_spinner.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/suggested_channel.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _channelId = -900601;
const String _title = 'Рекомендуемые каналы';
const String _join = 'Подписаться';
const String _open = 'Открыть';

const List<SuggestedChannel> _channels = [
  SuggestedChannel(
    id: -900602,
    title: 'Синтетический канал А',
    link: 'https://example.test/channel_a',
    subscribers: 3663,
  ),
  SuggestedChannel(
    id: -900603,
    title: 'Синтетический канал Б',
    link: 'https://example.test/channel_b',
    subscribers: 129812,
  ),
];

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(400, 700);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    ),
  );
}

ChannelRecommendations _recommendations({
  Future<void> Function(SuggestedChannel channel)? join,
}) {
  final recommendations = ChannelRecommendations(
    chatId: _channelId,
    fetch: () async => _channels,
    join: join ?? (_) async {},
  );
  addTearDown(recommendations.dispose);
  return recommendations;
}

double _blockHeight(WidgetTester tester) =>
    tester.getSize(find.byType(ChannelRecommendationsView)).height;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    KometSettings.hideChannelRecommendations.value = false;
    KometSettings.recommendationsHiddenIn.value = const {};
  });

  testWidgets('the block slides in once the channels arrive', (tester) async {
    final recommendations = _recommendations();
    await _pump(
      tester,
      ChannelRecommendationsView(recommendations: recommendations),
    );
    expect(_blockHeight(tester), 0);

    await recommendations.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midway = _blockHeight(tester);
    await tester.pumpAndSettle();

    expect(midway, inExclusiveRange(0, _blockHeight(tester)));
    expect(find.text(_title), findsOneWidget);
    expect(find.text('Синтетический канал А'), findsOneWidget);
    expect(find.text('3,7K'), findsOneWidget);
    expect(find.text('129,8K'), findsOneWidget);
  });

  testWidgets('joining shows progress and then offers to open the channel', (
    tester,
  ) async {
    final joining = Completer<void>();
    final joined = <int>[];
    final recommendations = _recommendations(
      join: (channel) {
        joined.add(channel.id);
        return joining.future;
      },
    );
    await recommendations.load();
    await _pump(
      tester,
      ChannelRecommendationsView(recommendations: recommendations),
    );

    await tester.tap(find.text(_join).first);
    await tester.pump();
    expect(joined, [-900602]);
    expect(find.byType(SmallSpinner), findsOneWidget);

    joining.complete();
    await tester.pumpAndSettle();
    expect(find.text(_open), findsOneWidget);
    expect(find.text(_join), findsOneWidget);
  });

  testWidgets('a failed join puts the button back', (tester) async {
    final recommendations = _recommendations(
      join: (_) async => throw StateError('synthetic'),
    );
    await recommendations.load();
    await _pump(
      tester,
      ChannelRecommendationsView(recommendations: recommendations),
    );

    await tester.tap(find.text(_join).first);
    await tester.pumpAndSettle();

    expect(find.text(_join), findsNWidgets(2));
    expect(find.text('Не удалось подписаться'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('the close button folds the block away and remembers it', (
    tester,
  ) async {
    final recommendations = _recommendations();
    await recommendations.load();
    await _pump(
      tester,
      ChannelRecommendationsView(recommendations: recommendations),
    );
    final full = _blockHeight(tester);

    await tester.tap(find.byIcon(Symbols.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final folding = _blockHeight(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(folding, inExclusiveRange(0, full));
    expect(_blockHeight(tester), 0);
    expect(KometSettings.recommendationsHiddenIn.value, {_channelId});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('komet_recommendations_hidden_in'), [
      '$_channelId',
    ]);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('the Komet switch hides recommendations everywhere', (
    tester,
  ) async {
    final recommendations = _recommendations();
    await recommendations.load();
    await _pump(
      tester,
      ChannelRecommendationsView(recommendations: recommendations),
    );
    expect(_blockHeight(tester), greaterThan(0));

    await KometSettings.setHideChannelRecommendations(true);
    await tester.pumpAndSettle();
    expect(_blockHeight(tester), 0);

    final another = _recommendations();
    await another.load();
    expect(another.visible, isFalse);
    expect(another.channels, isEmpty);
  });

  testWidgets('a channel post shows its views before the time', (tester) async {
    final views = ValueNotifier<int?>(null);
    addTearDown(views.dispose);
    await _pump(
      tester,
      MessageBubble(
        message: CachedMessage(
          id: '900701',
          accountId: 1,
          chatId: _channelId,
          senderId: 2,
          text: 'Синтетический пост',
          time: DateTime(2026, 1, 1, 12).millisecondsSinceEpoch,
          status: 'sent',
        ),
        isMe: false,
        channelPost: true,
        views: views,
        myId: 1,
        chatType: 'CHANNEL',
        peerName: 'Синтетический канал',
      ),
    );
    expect(find.byIcon(Symbols.visibility), findsNothing);

    views.value = 8948;
    await tester.pump();

    expect(find.byIcon(Symbols.visibility), findsOneWidget);
    expect(find.text('8,9K'), findsOneWidget);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/komet_settings.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/core/storage/chat_activity_store.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/meta_marks.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String directory;

  _SyntheticPathProvider(this.directory);

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

const int _me = 1;
const int _chatId = 900201;
const int _alice = 900301;
const int _bob = 900302;

CachedMessage _message({int? typingMs}) => CachedMessage.fromPushPayload(
  _me,
  _chatId,
  {
    'id': '7101',
    'time': DateTime(2026, 1, 1, 12, 30).millisecondsSinceEpoch,
    'type': 'USER',
    'sender': _alice,
    'text': 'Синтетическое сообщение',
  },
).copyWith(typingMs: typingMs);

Future<void> _pumpBubble(WidgetTester tester, CachedMessage message) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: MessageBubble(
            message: message,
            isMe: false,
            myId: _me,
            chatType: 'DIALOG',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _marks => find.descendant(
  of: find.byType(TypingTimeMark),
  matching: find.byType(Icon),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Отсчёт времени набора', () {
    late int now;
    late ChatActivityStore store;

    setUp(() {
      now = 1000000;
      store = ChatActivityStore.withClock(() => now);
    });

    void typing(int userId) => store.mark(_chatId, userId, ChatActivity.typing);

    testWidgets('считает от первого «печатает» до сообщения', (tester) async {
      typing(_alice);
      now += 4000;
      await tester.pump(const Duration(seconds: 4));
      typing(_alice);
      now += 3500;
      await tester.pump(const Duration(milliseconds: 3500));

      expect(store.takeTypingTime(_chatId, _alice), 7500);
      expect(store.takeTypingTime(_chatId, _alice), isNull);
      store.clearChat(_chatId);
    });

    testWidgets('истёкший статус сбрасывает отсчёт', (tester) async {
      typing(_alice);
      now += 7000;
      await tester.pump(const Duration(seconds: 7));
      expect(store.takeTypingTime(_chatId, _alice), isNull);

      typing(_alice);
      now += 2000;
      await tester.pump(const Duration(seconds: 2));
      expect(store.takeTypingTime(_chatId, _alice), 2000);
      store.clearChat(_chatId);
    });

    testWidgets('в группе у каждого участника свой отсчёт', (tester) async {
      typing(_alice);
      now += 3000;
      await tester.pump(const Duration(seconds: 3));
      typing(_bob);
      typing(_alice);
      now += 2000;
      await tester.pump(const Duration(seconds: 2));

      expect(store.takeTypingTime(_chatId, _bob), 2000);
      expect(store.takeTypingTime(_chatId, _alice), 5000);
      store.clearChat(_chatId);
    });

    testWidgets('выбор стикера и снятие статуса обнуляют отсчёт', (
      tester,
    ) async {
      typing(_alice);
      now += 2000;
      store.mark(_chatId, _alice, ChatActivity.sticker);
      expect(store.takeTypingTime(_chatId, _alice), isNull);

      typing(_bob);
      now += 2000;
      store.clearUser(_chatId, _bob);
      expect(store.takeTypingTime(_chatId, _bob), isNull);
      store.clearChat(_chatId);
    });

    testWidgets('набор дольше пятнадцати минут не засчитывается', (
      tester,
    ) async {
      typing(_alice);
      now += ChatActivityStore.maxTypingTime.inMilliseconds + 1;

      expect(store.takeTypingTime(_chatId, _alice), isNull);
      store.clearChat(_chatId);
    });
  });

  test('секунды набора округляются до десятых, минуты — до сотых', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(formatApproxDuration(ru, 240), '0,2 с');
    expect(formatApproxDuration(ru, 7000), '7,0 с');
    expect(formatApproxDuration(ru, 7460), '7,5 с');
    expect(formatApproxDuration(ru, 59940), '59,9 с');
    expect(formatApproxDuration(ru, 59960), '1,00 мин');
    expect(formatApproxDuration(ru, 150000), '2,50 мин');
    expect(formatApproxDuration(ru, 208200), '3,47 мин');
    expect(formatApproxDuration(ru, 843000), '14,05 мин');
  });

  test('время набора переживает сохранение сообщения в базу', () async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_typing_time_test',
    );
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    addTearDown(() async {
      await AppDatabase.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    await AppDatabase.init();
    await AppDatabase.saveProfile(
      ProfileData(
        id: _me,
        firstName: 'Synthetic owner',
        phone: 100000,
        country: 'ZZ',
        accountStatus: 0,
        updateTime: 1,
      ),
    );
    await chats.cacheServerChat({
      'id': _chatId,
      'type': 'DIALOG',
      'status': 'ACTIVE',
      'participants': {'$_me': 0, '$_alice': 0},
    }, _me);

    await AppDatabase.saveMessages([_message(typingMs: 7500).toDbRow()]);

    final row = await AppDatabase.loadMessage(_me, _chatId, '7101');
    expect(CachedMessage.fromDbRow(row!).typingMs, 7500);
  });

  group('Метка времени набора', () {
    setUp(() => KometSettings.showTypingTime.value = true);
    tearDown(() => KometSettings.showTypingTime.value = false);

    testWidgets('стоит слева от времени и по тапу называет длительность', (
      tester,
    ) async {
      await _pumpBubble(tester, _message(typingMs: 7500));

      final mark = tester.getRect(_marks);
      final clock = tester.getRect(find.text('12:30'));
      expect(mark.right, lessThanOrEqualTo(clock.left));

      await tester.tap(_marks);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('Сообщение печаталось примерно ~7,5 с'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('сообщение без насчитанного времени остаётся без метки', (
      tester,
    ) async {
      await _pumpBubble(tester, _message());

      expect(_marks, findsNothing);
    });

    testWidgets('выключенная настройка прячет метку', (tester) async {
      KometSettings.showTypingTime.value = false;
      await _pumpBubble(tester, _message(typingMs: 7500));

      expect(_marks, findsNothing);
    });
  });
}

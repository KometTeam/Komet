import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/app_message_actions_style.dart';
import 'package:komet/core/media/voice_audio_controller.dart';
import 'package:komet/frontend/widgets/message_actions_overlay.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';

Future<void> _openMenu(WidgetTester tester, {VoidCallback? onSave}) async {
  final controller = MessageActionsController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMessageActions(
              context: context,
              originRect: const Rect.fromLTWH(20, 200, 200, 40),
              tapPoint: const Offset(60, 220),
              isMe: false,
              messageText: null,
              copyText: null,
              controller: controller,
              style: MessageActionsStyle.list,
              interaction: MessageActionsInteraction.click,
              onSave: onSave,
              onDispose: () {},
            ),
            child: const Text('open menu'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open menu'));
  await tester.pumpAndSettle();
}

CachedMessage _message(List<MessageAttachment> attachments) => CachedMessage(
  id: '1001',
  accountId: 1,
  chatId: 2,
  senderId: 3,
  time: 1700000000000,
  attachments: attachments,
);

void main() {
  testWidgets('без обработчика пункта сохранения в меню нет', (tester) async {
    await _openMenu(tester);
    expect(find.text('Сохранить'), findsNothing);
  });

  testWidgets('сохранение закрывает меню и вызывает обработчик', (
    tester,
  ) async {
    var saved = 0;
    await _openMenu(tester, onSave: () => saved++);

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(saved, 1);
    expect(find.text('Сохранить'), findsNothing);
  });

  test('голосовое находится и в пересланном сообщении', () {
    const voice = AudioAttachment(
      audioId: 42,
      baseUrl: 'https://example.test/a',
    );
    final own = _message(const [voice]);
    final forwarded = _message(const [
      ForwardedMessageAttachment(
        originalSenderId: 4,
        originalMessageId: '2002',
        originalAttachments: [voice],
      ),
    ]);
    final text = _message(const []);

    expect(own.audioAttachment, same(voice));
    expect(forwarded.audioAttachment, same(voice));
    expect(text.audioAttachment, isNull);
  });

  test('ключ кэша голосового общий для пузыря и сохранения', () {
    expect(
      VoiceAudioController.cacheNameFor(audioId: 42, messageId: '1001'),
      '42.ogg',
    );
    expect(VoiceAudioController.cacheNameFor(messageId: '1001'), '1001.ogg');
  });
}

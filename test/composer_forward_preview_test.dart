import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/app_chat_chrome.dart';
import 'package:komet/core/config/app_composer_background.dart';
import 'package:komet/core/config/app_composer_style.dart';
import 'package:komet/backend/modules/forward_sender.dart';
import 'package:komet/frontend/screens/chats/chat/upload_status.dart';
import 'package:komet/frontend/screens/chats/chat/video_note_controller.dart';
import 'package:komet/frontend/screens/chats/chat/view/composer_input.dart';
import 'package:komet/frontend/screens/chats/chat/voice_record_controller.dart';
import 'package:komet/frontend/widgets/lottie_slash_icon.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';

CachedMessage _message() => const CachedMessage(
  id: '101',
  accountId: 7,
  chatId: 70,
  senderId: 7,
  text: 'Synthetic forwarded text',
  time: 1000,
  status: 'sent',
);

ForwardRequest _request() => ForwardRequest(
  sourceChatId: 70,
  sourceChatName: 'Synthetic chat',
  sourceChatIconUrl: '',
  sourceChatType: 'CHAT',
  messages: [_message()],
);

void main() {
  testWidgets(
    'forward preview forces send mode, hides the sender and can be cancelled',
    (tester) async {
      final forwards = ValueNotifier<ForwardRequest?>(_request());
      final reply = ValueNotifier<CachedMessage?>(null);
      final hasText = ValueNotifier(false);
      final uploadStatus = ValueNotifier(const UploadStatus());
      final messageController = RichMessageController();
      final focusNode = FocusNode();
      final attachAnimation = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 1),
      );
      late BuildContext composerContext;
      var sendCount = 0;
      var cancelCount = 0;
      var toggleCount = 0;
      final voice = VoiceRecordController(
        contextOf: () => composerContext,
        isMounted: () => true,
        myId: () => 7,
        onRecorded:
            (File file, int durationMs, List<double> amplitudes) async {},
      );
      final note = VideoNoteController(
        contextOf: () => composerContext,
        isMounted: () => true,
        onRecorded: (File file, int durationMs) async {},
        formatElapsed: (milliseconds) => '$milliseconds',
        bottomInset: () => 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              composerContext = context;
              return Scaffold(
                bottomNavigationBar: ComposerInputBar(
                  chatType: 'CHAT',
                  chrome: ChatChromeStyle.color,
                  style: ComposerStyle.materialYou,
                  background: ComposerBackground.standard,
                  attachAnim: attachAnimation,
                  replyTo: reply,
                  forward: forwards,
                  myId: 7,
                  hasText: hasText,
                  uploadStatus: uploadStatus,
                  messageController: messageController,
                  messageFocusNode: focusNode,
                  voiceRec: voice,
                  note: note,
                  onToggleStickerPanel: () {},
                  onSendText: () => sendCount++,
                  onScheduleMessage: () {},
                  onOpenAttach: () {},
                  onOpenAttachScheduled: () {},
                  onSendHistory: (_) async {},
                  onCancelReply: () {},
                  onCancelForward: () {
                    cancelCount++;
                    forwards.value = null;
                  },
                  onToggleForwardSender: () {
                    toggleCount++;
                    final request = forwards.value!;
                    forwards.value = request.withHideSender(
                      !request.hideSender,
                    );
                  },
                  formatElapsed: (milliseconds) => '$milliseconds',
                  contextMenuBuilder: (context, state) =>
                      const SizedBox.shrink(),
                  isMuted: false,
                  onToggleMute: () {},
                  showStickerButton: false,
                  showAttachButton: false,
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Пересылка от вас'), findsOneWidget);
      expect(find.text('Synthetic forwarded text'), findsOneWidget);
      expect(find.byIcon(Symbols.forward), findsOneWidget);
      expect(find.byIcon(Symbols.send), findsOneWidget);
      expect(find.byIcon(Symbols.mic), findsNothing);

      await tester.tap(find.byIcon(Symbols.send));
      expect(sendCount, 1);

      expect(
        tester.widget<LottieSlashIcon>(find.byType(LottieSlashIcon)).slashed,
        isFalse,
      );
      await tester.tap(find.byTooltip('Скрыть имя отправителя'));
      await tester.pump();

      expect(toggleCount, 1);
      expect(find.text('Пересылка без автора'), findsOneWidget);
      expect(find.text('Пересылка от вас'), findsNothing);
      expect(find.text('Synthetic forwarded text'), findsOneWidget);
      expect(
        tester.widget<LottieSlashIcon>(find.byType(LottieSlashIcon)).slashed,
        isTrue,
      );

      await tester.tap(find.byTooltip('Показать имя отправителя'));
      await tester.pump();

      expect(toggleCount, 2);
      expect(find.text('Пересылка от вас'), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(cancelCount, 1);
      expect(find.text('Пересылка от вас'), findsNothing);
      expect(find.byIcon(Symbols.send), findsNothing);
      expect(find.byIcon(Symbols.mic), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      forwards.dispose();
      reply.dispose();
      hasText.dispose();
      uploadStatus.dispose();
      messageController.dispose();
      focusNode.dispose();
      attachAnimation.dispose();
      voice.dispose();
      note.dispose();
    },
  );
}

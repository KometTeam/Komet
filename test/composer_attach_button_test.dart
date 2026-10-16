import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/forward_sender.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/app_chat_chrome.dart';
import 'package:komet/core/config/app_composer_background.dart';
import 'package:komet/core/config/app_composer_style.dart';
import 'package:komet/frontend/screens/chats/chat/upload_status.dart';
import 'package:komet/frontend/screens/chats/chat/video_note_controller.dart';
import 'package:komet/frontend/screens/chats/chat/view/composer_input.dart';
import 'package:komet/frontend/screens/chats/chat/voice_record_controller.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  testWidgets('the attach button stays usable while text is typed', (
    tester,
  ) async {
    final forwards = ValueNotifier<ForwardRequest?>(null);
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
    var attachCount = 0;
    final voice = VoiceRecordController(
      contextOf: () => composerContext,
      isMounted: () => true,
      myId: () => 7,
      onRecorded: (File file, int durationMs, List<double> amplitudes) async {},
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
                chatType: 'DIALOG',
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
                onSendText: () {},
                onScheduleMessage: () {},
                onOpenAttach: () => attachCount++,
                onOpenAttachScheduled: () {},
                onSendHistory: (_) async {},
                onCancelReply: () {},
                onCancelForward: () {},
                onToggleForwardSender: () {},
                formatElapsed: (milliseconds) => '$milliseconds',
                contextMenuBuilder: (context, state) => const SizedBox.shrink(),
                isMuted: false,
                onToggleMute: () {},
                showStickerButton: false,
              ),
            );
          },
        ),
      ),
    );

    expect(find.byIcon(Symbols.attachment), findsOneWidget);

    messageController.text = 'Synthetic caption';
    hasText.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Symbols.attachment), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.attachment));
    expect(attachCount, 1);

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
  });
}

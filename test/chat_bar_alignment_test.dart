import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/app_chat_chrome.dart';
import 'package:komet/core/config/app_composer_background.dart';
import 'package:komet/core/config/app_composer_style.dart';
import 'package:komet/frontend/screens/chats/chat/upload_status.dart';
import 'package:komet/frontend/screens/chats/chat/view/chat_header.dart';
import 'package:komet/frontend/screens/chats/chat/video_note_controller.dart';
import 'package:komet/frontend/screens/chats/chat/view/composer_input.dart';
import 'package:komet/frontend/screens/chats/chat/voice_record_controller.dart';
import 'package:komet/frontend/widgets/composer_morph_icon.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';

void main() {
  late RichMessageController messageController;
  late FocusNode focusNode;
  late AnimationController attachAnim;
  late VoiceRecordController voiceRec;
  late VideoNoteController note;
  late ValueNotifier<CachedMessage?> replyTo;
  late ValueNotifier<List<CachedMessage>> forwards;
  late ValueNotifier<bool> hasText;
  late ValueNotifier<UploadStatus> uploadStatus;

  setUp(() {
    messageController = RichMessageController();
    focusNode = FocusNode();
    attachAnim = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 200),
    );
    voiceRec = VoiceRecordController(
      contextOf: () => throw UnimplementedError(),
      isMounted: () => true,
      myId: () => 1,
      onRecorded: (File file, int durationMs, List<double> amps) async {},
    );
    note = VideoNoteController(
      contextOf: () => throw UnimplementedError(),
      isMounted: () => true,
      onRecorded: (File file, int durationMs) async {},
      formatElapsed: (ms) => '0:00',
      bottomInset: () => 0,
    );
    replyTo = ValueNotifier(null);
    forwards = ValueNotifier(const []);
    hasText = ValueNotifier(false);
    uploadStatus = ValueNotifier(const UploadStatus());
  });

  tearDown(() {
    messageController.dispose();
    focusNode.dispose();
    attachAnim.dispose();
    replyTo.dispose();
    forwards.dispose();
    hasText.dispose();
    uploadStatus.dispose();
  });

  Future<double> pumpBar(WidgetTester tester, ComposerStyle style) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ComposerInputBar(
                chatType: 'DIALOG',
                chrome: ChatChromeStyle.none,
                vignette: true,
                style: style,
                background: ComposerBackground.standard,
                attachAnim: attachAnim,
                replyTo: replyTo,
                forwardMessages: forwards,
                myId: 1,
                hasText: hasText,
                uploadStatus: uploadStatus,
                messageController: messageController,
                messageFocusNode: focusNode,
                voiceRec: voiceRec,
                note: note,
                onToggleStickerPanel: () {},
                onSendText: () {},
                onScheduleMessage: () {},
                onOpenAttach: () {},
                onOpenAttachScheduled: () {},
                onSendHistory: (entry) async {},
                onCancelReply: () {},
                onCancelForward: () {},
                formatElapsed: (ms) => '0:00',
                contextMenuBuilder: (context, state) => const SizedBox.shrink(),
                isMuted: false,
                onToggleMute: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.getSize(find.byType(ComposerInputBar)).height;
  }

  Future<void> pumpHeader(WidgetTester tester) async {
    final status = ValueNotifier<String>('online');
    final scheduled = ValueNotifier<int>(0);
    final unread = ValueNotifier<int>(0);
    addTearDown(status.dispose);
    addTearDown(scheduled.dispose);
    addTearDown(unread.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: SizedBox(
              height: kToolbarHeight,
              child: ChatHeaderRow(
                glossy: false,
                frosted: false,
                cs: Theme.of(context).colorScheme,
                embedded: false,
                chatId: 0,
                heroTag: 'header',
                name: 'Chat',
                imageUrl: '',
                chatType: 'CHAT',
                isOfficial: false,
                myId: 1,
                headerStatus: status,
                scheduledCount: scheduled,
                otherUnread: unread,
                showCall: true,
                onClose: null,
                onOpenInfo: () {},
                onOpenScheduled: () {},
                onCall: () {},
                onMenu: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the material composer is exactly as tall as the app bar', (
    tester,
  ) async {
    expect(await pumpBar(tester, ComposerStyle.materialYou), kToolbarHeight);
  });

  testWidgets('the glossy composer keeps its taller pill layout', (
    tester,
  ) async {
    expect(
      await pumpBar(tester, ComposerStyle.glossy),
      greaterThan(kToolbarHeight),
    );
  });

  testWidgets('material actions sit on the app bar icon columns', (
    tester,
  ) async {
    await pumpHeader(tester);
    final headerWidth = tester.getSize(find.byType(ChatHeaderRow)).width;
    final back = tester.getCenter(find.byIcon(Symbols.arrow_back)).dx;
    final call = headerWidth - tester.getCenter(find.byIcon(Symbols.call)).dx;
    final menu =
        headerWidth - tester.getCenter(find.byIcon(Symbols.more_vert)).dx;

    await pumpBar(tester, ComposerStyle.materialYou);
    final width = tester.getSize(find.byType(ComposerInputBar)).width;

    expect(tester.getCenter(find.byIcon(Symbols.face)).dx, back);
    expect(width - tester.getCenter(find.byIcon(Symbols.attachment)).dx, call);
    expect(width - tester.getCenter(find.byType(ComposerMorphIcon)).dx, menu);
  });

  testWidgets('glossy action geometry is untouched', (tester) async {
    await pumpBar(tester, ComposerStyle.glossy);
    final width = tester.getSize(find.byType(ComposerInputBar)).width;

    expect(tester.getCenter(find.byType(ComposerMorphIcon)).dx, width - 39);
    expect(tester.getCenter(find.byIcon(Symbols.face)).dx, 38);
    expect(tester.getCenter(find.byIcon(Symbols.attachment)).dx, width - 100);
  });
}

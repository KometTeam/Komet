import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/bubble_context.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/call_bubble.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/contact_bubble.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/file_bubble.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/forwarded_bubble.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/location_bubble.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/photo_bubble.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/share_bubble.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/sticker_bubble.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/video_bubble.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/video_note_bubble.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/voice_bubble.dart';
import 'package:komet/frontend/widgets/formatted_message_text.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';
import 'package:material_symbols_icons/symbols.dart';

Future<void> _pumpBubble(
  WidgetTester tester,
  CachedMessage message, {
  void Function(ForwardedMessageAttachment forwarded)? onSourceTap,
  bool isMe = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

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
            isMe: isMe,
            myId: 1,
            chatType: 'CHAT',
            onForwardedSourceTap: onSourceTap,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ForwardedMessageAttachment', () {
    test('styles a server heading', () {
      final style = applyTextFormats(const TextStyle(fontSize: 16), {
        TextFormat.heading,
      });

      expect(style.fontWeight, FontWeight.w700);
      expect(style.fontSize, greaterThan(16));
    });

    test('uses channel metadata as the original author', () {
      final attachment = ForwardedMessageAttachment.fromMap({
        'link': {
          'type': 'FORWARD',
          'message': {
            'id': '101',
            'time': 1000,
            'type': 'CHANNEL',
            'text': 'Synthetic channel message',
            'attaches': [
              {'_type': 'PHOTO', 'photoId': 11},
            ],
            'elements': [
              {'type': 'HEADING', 'length': 9},
            ],
          },
          'chatId': -10,
          'chatName': 'Example Channel',
          'chatIconUrl': 'https://example.test/channel.jpg',
        },
      });

      expect(attachment.originalSenderId, 0);
      expect(attachment.originalSenderName, 'Example Channel');
      expect(attachment.isChannel, isTrue);
      expect(attachment.originalMessageId, '101');
      expect(attachment.originalTime, 1000);
      expect(
        attachment.originalSenderAvatar,
        'https://example.test/channel.jpg',
      );
      expect(attachment.originalChatId, -10);
      expect(attachment.originalAttachments, hasLength(1));
      expect(attachment.originalAttachments!.single, isA<PhotoAttachment>());
      expect(attachment.originalFormatRanges, hasLength(1));
      expect(attachment.originalFormatRanges.single.format, TextFormat.heading);
    });

    test('keeps the user as the original author', () {
      final attachment = ForwardedMessageAttachment.fromMap({
        'link': {
          'type': 'FORWARD',
          'message': {
            'id': '102',
            'time': 2000,
            'type': 'USER',
            'sender': 42,
            'text': '',
            'attaches': const [],
          },
          'chatId': -20,
          'chatName': 'Example Group',
          'chatIconUrl': 'https://example.test/group.jpg',
        },
      });

      expect(attachment.originalSenderId, 42);
      expect(attachment.isChannel, isFalse);
      expect(attachment.originalSenderName, isNull);
      expect(attachment.originalSenderAvatar, isNull);
    });

    test('keeps channel metadata in an optimistic forward', () {
      final forwarded = MessagesModule.buildForwardMessage(
        myId: 1,
        targetChatId: 2,
        sourceChatId: -10,
        source: const CachedMessage(
          id: '101',
          accountId: 1,
          chatId: -10,
          senderId: 0,
          text: 'Synthetic channel message',
          time: 1000,
          payload: {
            'type': 'CHANNEL',
            'attaches': [],
            'elements': [
              {'type': 'STRONG', 'length': 9},
            ],
          },
        ),
        tempId: 'temp_1',
        time: 3000,
        status: 'sending',
        sourceChatName: 'Example Channel',
        sourceChatIconUrl: 'https://example.test/channel.jpg',
        sourceChatType: 'CHANNEL',
      );

      final attachment =
          forwarded.attachments!.single as ForwardedMessageAttachment;
      expect(attachment.originalSenderName, 'Example Channel');
      expect(
        attachment.originalSenderAvatar,
        'https://example.test/channel.jpg',
      );
      expect(attachment.originalFormatRanges, hasLength(1));
    });

    test('keeps the original channel when forwarding a forward', () {
      final forwarded = MessagesModule.buildForwardMessage(
        myId: 1,
        targetChatId: 2,
        sourceChatId: 3,
        source: const CachedMessage(
          id: '201',
          accountId: 1,
          chatId: 3,
          senderId: 42,
          time: 3000,
          payload: {
            'link': {
              'type': 'FORWARD',
              'message': {
                'id': '101',
                'time': 1000,
                'type': 'CHANNEL',
                'text': 'Synthetic channel message',
                'attaches': [],
              },
              'chatId': -10,
              'chatName': 'Example Channel',
              'chatIconUrl': 'https://example.test/channel.jpg',
            },
          },
        ),
        tempId: 'temp_2',
        time: 4000,
        status: 'sending',
        sourceChatName: 'Current Chat',
        sourceChatIconUrl: 'https://example.test/current-chat.jpg',
        sourceChatType: 'CHAT',
      );

      final attachment =
          forwarded.attachments!.single as ForwardedMessageAttachment;
      expect(attachment.originalSenderName, 'Example Channel');
      expect(
        attachment.originalSenderAvatar,
        'https://example.test/channel.jpg',
      );
    });

    testWidgets('renders a formatted caption with a forwarded photo', (
      tester,
    ) async {
      const caption =
          'Bold synthetic caption that wraps within the synthetic photo width';
      final attachment = ForwardedMessageAttachment.fromMap({
        'link': {
          'type': 'FORWARD',
          'message': {
            'id': '103',
            'time': 5000,
            'type': 'CHANNEL',
            'text': caption,
            'attaches': [
              {'_type': 'PHOTO', 'photoId': 13, 'width': 200, 'height': 200},
            ],
            'elements': [
              {'type': 'HEADING', 'length': 4},
            ],
          },
          'chatId': -30,
          'chatName': 'Another Example Channel',
        },
      });
      final message = CachedMessage(
        id: '202',
        accountId: 1,
        chatId: 2,
        senderId: 42,
        time: 6000,
        attachments: [attachment],
      );
      ForwardedMessageAttachment? tappedSource;

      await _pumpBubble(
        tester,
        message,
        onSourceTap: (forwarded) => tappedSource = forwarded,
      );

      expect(find.text('Another Example Channel'), findsOneWidget);
      expect(find.text(caption), findsOneWidget);
      final formatted = tester.widget<FormattedMessageText>(
        find.byType(FormattedMessageText),
      );
      expect(formatted.ranges.single.format, TextFormat.heading);
      expect(find.text('0'), findsNothing);
      expect(
        tester.getSize(find.byType(ForwardedHeader)).width,
        closeTo(200, 0.1),
      );
      expect(
        tester.getSize(find.byType(ForwardedHeader)).width,
        closeTo(tester.getSize(find.byType(PhotoBubble)).width, 0.1),
      );
      expect(
        tester.getBottomLeft(find.byType(ClipRRect).first).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text(caption)).dy),
      );

      await tester.tap(find.text('Another Example Channel'));
      expect(tappedSource, same(attachment));
      expect(tappedSource?.isChannel, isTrue);
    });

    testWidgets('renders a forwarded video with its original metadata', (
      tester,
    ) async {
      final attachment = ForwardedMessageAttachment.fromMap({
        'link': {
          'type': 'FORWARD',
          'message': {
            'id': 'synthetic-source-message',
            'time': 9000,
            'type': 'USER',
            'sender': 44,
            'text': 'Synthetic video caption',
            'attaches': [
              {
                '_type': 'VIDEO',
                'videoId': 7001,
                'token': 'synthetic-video-token',
                'videoType': 0,
                'duration': 9000,
                'width': 720,
                'height': 1280,
              },
            ],
          },
          'chatId': -50,
        },
      });
      final video = attachment.originalAttachments!.single as VideoAttachment;
      final message = CachedMessage(
        id: 'synthetic-forward-message',
        accountId: 1,
        chatId: 2,
        senderId: 43,
        time: 10000,
        attachments: [attachment],
      );

      expect(video.videoId, 7001);
      expect(video.videoToken, 'synthetic-video-token');
      expect(video.videoType, 0);

      await _pumpBubble(tester, message);

      expect(find.byType(ForwardedHeader), findsOneWidget);
      expect(find.byType(VideoBubble), findsOneWidget);
      expect(find.text('Synthetic video caption'), findsOneWidget);
      expect(find.text('0:09'), findsOneWidget);
      final forwardedWidth = tester.getSize(find.byType(ForwardedHeader)).width;
      final videoWidth = tester.getSize(find.byType(VideoBubble)).width;
      expect(forwardedWidth, closeTo(BubbleContext.photoMaxSize, 0.1));
      expect(forwardedWidth, closeTo(videoWidth, 0.1));
      final preview = find.descendant(
        of: find.byType(VideoBubble),
        matching: find.byType(ClipRRect),
      );
      expect(
        tester.getBottomLeft(preview.first).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.text('Synthetic video caption')).dy,
        ),
      );
      final bubble = tester.widget<VideoBubble>(find.byType(VideoBubble));
      expect(bubble.ctx.sourceMessageId, 'synthetic-source-message');
      expect(bubble.ctx.sourceChatId, -50);
      final forwardedVideoSize = tester.getSize(find.byType(VideoBubble));
      final forwardedPreviewSize = tester.getSize(preview.first);

      final regularMessage = CachedMessage(
        id: 'synthetic-regular-message',
        accountId: 1,
        chatId: 2,
        senderId: 43,
        time: 10000,
        text: 'Synthetic video caption',
        attachments: [video],
      );
      await _pumpBubble(tester, regularMessage);

      final regularPreview = find.descendant(
        of: find.byType(VideoBubble),
        matching: find.byType(ClipRRect),
      );
      expect(tester.getSize(find.byType(VideoBubble)), forwardedVideoSize);
      expect(tester.getSize(regularPreview.first), forwardedPreviewSize);
      expect(find.byType(ForwardedHeader), findsNothing);
    });

    final nativeAttachmentCases =
        <({String name, MessageAttachment attachment, Type bubbleType})>[
          (
            name: 'file',
            attachment: const FileAttachment(
              fileId: 7101,
              name: 'synthetic.txt',
              size: 128,
            ),
            bubbleType: FileBubble,
          ),
          (
            name: 'sticker',
            attachment: const StickerAttachment(
              stickerId: 'synthetic-sticker',
              width: 128,
              height: 128,
            ),
            bubbleType: StickerBubble,
          ),
          (
            name: 'location',
            attachment: const LocationAttachment(
              latitude: 1,
              longitude: 2,
              title: 'Synthetic location',
            ),
            bubbleType: LocationBubble,
          ),
          (
            name: 'call',
            attachment: const CallAttachment(isVideo: false, durationMs: 1000),
            bubbleType: CallBubble,
          ),
          (
            name: 'share',
            attachment: const ShareAttachment(
              shareId: 7102,
              title: 'Synthetic preview',
              url: 'https://example.test/synthetic',
            ),
            bubbleType: ShareBubble,
          ),
          (
            name: 'audio',
            attachment: const AudioAttachment(
              audioId: 7103,
              duration: 1000,
              baseUrl: 'https://example.test/synthetic.ogg',
            ),
            bubbleType: VoiceMessageBubble,
          ),
          (
            name: 'video note',
            attachment: const VideoAttachment(
              videoId: 7104,
              videoToken: 'synthetic-note-token',
              videoType: 1,
              duration: 1000,
              width: 480,
              height: 480,
            ),
            bubbleType: VideoNoteBubble,
          ),
        ];

    for (final item in nativeAttachmentCases) {
      testWidgets('decorates forwarded ${item.name} native bubble', (
        tester,
      ) async {
        final forwarded = ForwardedMessageAttachment(
          originalSenderId: 71,
          originalMessageId: 'synthetic-source-${item.name}',
          originalChatId: 72,
          originalText: item.name == 'share'
              ? 'Synthetic forwarded caption'
              : null,
          originalAttachments: [item.attachment],
        );
        final message = CachedMessage(
          id: 'synthetic-forward-${item.name}',
          accountId: 1,
          chatId: 2,
          senderId: 70,
          time: 11000,
          text: 'Synthetic outer text',
          attachments: [forwarded],
        );

        await _pumpBubble(tester, message, isMe: item.name == 'audio');

        expect(find.byType(ForwardedHeader), findsOneWidget);
        expect(find.byType(item.bubbleType), findsOneWidget);
        final usesFloatingHeader =
            item.name == 'sticker' || item.name == 'video note';
        if (usesFloatingHeader) {
          expect(find.byType(ForwardedHeaderFloating), findsOneWidget);
          expect(
            tester.getRect(find.byType(ForwardedHeaderFloating)).bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(item.bubbleType)).top),
          );
        } else {
          expect(find.byType(ForwardedHeaderFloating), findsNothing);
        }
        if (item.name == 'audio') {
          final headerRect = tester.getRect(find.byType(ForwardedHeader));
          final voiceRect = tester.getRect(find.byType(VoiceMessageBubble));
          expect(voiceRect.left - headerRect.left, closeTo(14, 0.1));
          expect(headerRect.right - voiceRect.right, closeTo(14, 0.1));
          expect(
            find.descendant(
              of: find.byType(VoiceMessageBubble),
              matching: find.byIcon(Symbols.check),
            ),
            findsOneWidget,
          );
        }
        if (item.name == 'share') {
          expect(find.text('Synthetic forwarded caption'), findsOneWidget);
          expect(find.text('Synthetic outer text'), findsNothing);
        }
      });
    }

    testWidgets('decorates the native forwarded contact bubble', (
      tester,
    ) async {
      const forwarded = ForwardedMessageAttachment(
        originalSenderId: 73,
        originalMessageId: 'synthetic-contact-source',
        originalChatId: 74,
        originalContact: ContactAttachment(
          firstName: 'Synthetic',
          lastName: 'Contact',
          phoneNumber: '+10000000000',
        ),
      );
      const message = CachedMessage(
        id: 'synthetic-contact-forward',
        accountId: 1,
        chatId: 2,
        senderId: 70,
        time: 12000,
        attachments: [forwarded],
      );

      await _pumpBubble(tester, message);

      expect(find.byType(ForwardedHeader), findsOneWidget);
      expect(find.byType(ContactBubble), findsOneWidget);
    });

    testWidgets('makes the forwarded user name clickable', (tester) async {
      const attachment = ForwardedMessageAttachment(
        originalSenderId: 42,
        originalSenderName: 'Example Person',
        originalType: 'USER',
        originalMessageId: '104',
        originalTime: 7000,
        originalText: 'Synthetic user message',
        originalChatId: -40,
        originalFormatRanges: [
          FormatRange(format: TextFormat.strong, start: 0, length: 9),
        ],
      );
      const message = CachedMessage(
        id: '203',
        accountId: 1,
        chatId: 2,
        senderId: 43,
        time: 8000,
        attachments: [attachment],
      );
      ForwardedMessageAttachment? tappedSource;

      await _pumpBubble(
        tester,
        message,
        onSourceTap: (forwarded) => tappedSource = forwarded,
      );
      expect(find.byType(FormattedMessageText), findsOneWidget);
      await tester.tap(find.text('Example Person'));

      expect(tappedSource, same(attachment));
      expect(tappedSource?.originalSenderId, 42);
    });
  });
}

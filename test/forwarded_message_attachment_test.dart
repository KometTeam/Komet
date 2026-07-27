import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/forwarded_bubble.dart';
import 'package:komet/frontend/widgets/formatted_message_text.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';

Future<void> _pumpBubble(
  WidgetTester tester,
  CachedMessage message, {
  void Function(ForwardedMessageAttachment forwarded)? onSourceTap,
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
            isMe: false,
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
        tester.getSize(find.byType(ForwardedPhotoBubble)).width,
        closeTo(200, 0.1),
      );
      expect(
        tester.getBottomLeft(find.byType(ClipRRect).first).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text(caption)).dy),
      );

      await tester.tap(find.text('Another Example Channel'));
      expect(tappedSource, same(attachment));
      expect(tappedSource?.isChannel, isTrue);
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

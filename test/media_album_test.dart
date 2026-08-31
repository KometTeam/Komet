import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/photo_bubble.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/animoji.dart';
import 'package:komet/models/attachment.dart';
import 'package:material_symbols_icons/symbols.dart';

const int _me = 1;
const int _peer = 7;

const _photo = PhotoAttachment(
  baseUrl: 'https://example.com/synthetic-poster.jpg',
  width: 180,
  height: 240,
);

const _video = VideoAttachment(
  baseUrl: 'https://example.com/synthetic-clip.mp4',
  thumbnail: 'https://example.com/synthetic-clip.jpg',
  videoId: 42,
  videoToken: 'synthetic-token',
  width: 320,
  height: 240,
  duration: 65000,
);

const _secondVideo = VideoAttachment(
  baseUrl: 'https://example.com/synthetic-clip-2.mp4',
  thumbnail: 'https://example.com/synthetic-clip-2.jpg',
  videoId: 43,
  videoToken: 'synthetic-token-2',
  width: 320,
  height: 240,
  duration: 12000,
);

Map<String, dynamic> get _manyReactions => {
  'totalCount': 195,
  'counters': [
    {'reaction': '👍', 'count': 145},
    {'reaction': '⚡', 'count': 17},
    {'reaction': '❤️', 'count': 12},
    {'reaction': '😮', 'count': 7},
    {'reaction': '👑', 'count': 5},
    {'reaction': '🤣', 'count': 5},
    {'reaction': '💀', 'count': 4},
  ],
};

CachedMessage _message({
  required List<MessageAttachment> attachments,
  String? caption,
  Map<String, dynamic>? reactions,
}) => CachedMessage(
  id: '1',
  accountId: _me,
  chatId: 2,
  senderId: _peer,
  text: caption,
  time: DateTime(2026, 1, 1, 12, 0).millisecondsSinceEpoch,
  status: 'sent',
  attachments: attachments,
  payload: reactions == null ? null : {'reactionInfo': reactions},
);

Future<void> _pump(WidgetTester tester, CachedMessage message) async {
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
            key: const ValueKey('bubble'),
            message: message,
            isMe: false,
            myId: _me,
            chatType: 'DIALOG',
            reactionAnimojiResolver: (emoji) =>
                Animoji(id: 1, emoji: emoji, iconUrl: 'https://e.test/a.png'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

List<MessageAttachment> _renderedMedia(WidgetTester tester) =>
    tester.widget<PhotoBubble>(find.byType(PhotoBubble)).media;

Rect _bubbleRect(WidgetTester tester) {
  final containers = find.descendant(
    of: find.byKey(const ValueKey('bubble')),
    matching: find.byType(Container),
  );
  Rect? best;
  for (final element in tester.elementList(containers)) {
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (best == null || rect.width * rect.height > best.width * best.height) {
      best = rect;
    }
  }
  return best!;
}

void main() {
  testWidgets('a photo and a video share one album', (tester) async {
    await _pump(tester, _message(attachments: const [_photo, _video]));

    expect(_renderedMedia(tester), const [_photo, _video]);
    expect(
      find.descendant(
        of: find.byType(PhotoBubble),
        matching: find.byIcon(Symbols.play_arrow),
      ),
      findsOneWidget,
    );
  });

  testWidgets('two videos both get a tile', (tester) async {
    await _pump(tester, _message(attachments: const [_video, _secondVideo]));

    expect(_renderedMedia(tester).length, 2);
    expect(
      find.descendant(
        of: find.byType(PhotoBubble),
        matching: find.byIcon(Symbols.play_arrow),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('a lone video still gets the dedicated bubble', (tester) async {
    await _pump(tester, _message(attachments: const [_video]));

    expect(find.byType(PhotoBubble), findsNothing);
    expect(find.byIcon(Symbols.play_arrow), findsOneWidget);
  });

  testWidgets('reactions wrap instead of stretching a media bubble', (
    tester,
  ) async {
    await _pump(
      tester,
      _message(
        attachments: const [_photo],
        caption: 'Очень стильный и безумный боевик',
        reactions: _manyReactions,
      ),
    );

    final mediaWidth = PhotoBubble.layoutWidth(const [_photo], hasCaption: true);
    expect(_bubbleRect(tester).width, closeTo(mediaWidth, 0.5));
  });
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/komet_settings.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/media_autoplay.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/photo_bubble.dart';
import 'package:komet/frontend/widgets/lottie_image.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/frontend/widgets/message_animoji.dart';
import 'package:komet/frontend/widgets/section_header.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';

const _lottie = 'https://example.test/synthetic-animoji.json';

const _gif = PhotoAttachment(
  photoId: 5,
  baseUrl: 'https://example.test/synthetic.gif',
  previewUrl: 'https://example.test/synthetic-still.jpg',
  mp4Url: 'https://example.test/synthetic.mp4',
  isGif: true,
  width: 314,
  height: 400,
);

void main() {
  testWidgets('section headers are capitalised and slightly transparent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SectionHeader('Архив'))),
    );

    final text = tester.widget<Text>(find.text('АРХИВ'));
    final context = tester.element(find.byType(SectionHeader));
    final primary = Theme.of(context).colorScheme.primary;
    expect(text.style?.color?.a, lessThan(1));
    expect(text.style?.color?.withValues(alpha: 1), primary);
  });

  group('AutoplayClip', () {
    test('takes short remote video clips', () {
      final clip = AutoplayClip.video(
        const VideoAttachment(videoId: 1, videoToken: 't', duration: 12000),
        messageId: '1',
        chatId: 2,
      );
      expect(clip, isNotNull);
      expect(clip!.setting, same(KometSettings.autoplayVideo));
      expect(clip.autoDownload, same(KometSettings.autoDownloadVideo));
    });

    test('skips videos over a minute or without a duration', () {
      expect(
        AutoplayClip.video(
          const VideoAttachment(
            videoId: 1,
            videoToken: 't',
            duration: AutoplayClip.maxVideoDurationMs + 1,
          ),
          messageId: '1',
          chatId: 2,
        ),
        isNull,
      );
      expect(
        AutoplayClip.video(
          const VideoAttachment(videoId: 1, videoToken: 't'),
          messageId: '1',
          chatId: 2,
        ),
        isNull,
      );
    });

    test('needs either a local file or a way to fetch the video', () {
      expect(
        AutoplayClip.video(
          const VideoAttachment(duration: 5000),
          messageId: '1',
          chatId: 2,
        ),
        isNull,
      );
      expect(
        AutoplayClip.video(
          const VideoAttachment(duration: 5000, localPath: '/tmp/clip.mp4'),
          messageId: '1',
          chatId: 2,
        )?.localPath,
        '/tmp/clip.mp4',
      );
    });

    test('plays a GIF from its mp4 under the GIF switch', () async {
      final clip = AutoplayClip.gif(_gif);
      expect(clip, isNotNull);
      expect(clip!.setting, same(KometSettings.autoplayGif));
      expect(clip.autoDownload, same(KometSettings.autoDownloadPhoto));
      expect(await clip.resolveUrl!(), _gif.mp4Url);
    });

    test('leaves ordinary photos alone', () {
      expect(
        AutoplayClip.gif(
          const PhotoAttachment(photoId: 5, baseUrl: 'https://e.test/p.jpg'),
        ),
        isNull,
      );
    });
  });

  test('a GIF photo keeps its mp4 and still preview through the cache', () {
    final parsed = MessageAttachment.fromMap({
      '_type': 'PHOTO',
      'photoId': 5,
      'baseUrl': 'https://example.test/synthetic.gif',
      'previewUrl': 'https://example.test/synthetic-still.jpg',
      'mp4Url': 'https://example.test/synthetic.mp4',
      'gif': true,
      'width': 314,
      'height': 400,
    });

    expect(parsed, isA<PhotoAttachment>());
    final roundTrip =
        MessageAttachment.fromMap(parsed.toMap()) as PhotoAttachment;
    expect(roundTrip.isGif, isTrue);
    expect(roundTrip.previewUrl, 'https://example.test/synthetic-still.jpg');
    expect(roundTrip.mp4Url, 'https://example.test/synthetic.mp4');
  });

  testWidgets('a GIF shows its badge and a still poster', (tester) async {
    addTearDown(() => KometSettings.autoplayGif.value = true);
    KometSettings.autoplayGif.value = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: MessageBubble(
              message: CachedMessage(
                id: '1',
                accountId: 1,
                chatId: 2,
                senderId: 7,
                time: DateTime(2026, 1, 1, 12).millisecondsSinceEpoch,
                status: 'sent',
                attachments: const [_gif],
              ),
              isMe: false,
              myId: 1,
              chatType: 'DIALOG',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final badge = find.text(PhotoBubble.gifLabel);
    expect(badge, findsOneWidget);
    final time = find.text('12:00');
    expect(tester.getCenter(badge).dy, closeTo(tester.getCenter(time).dy, 1));
    expect(tester.getCenter(badge).dx, lessThan(tester.getCenter(time).dx));
    final poster = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(poster.imageUrl, _gif.previewUrl);
  });

  testWidgets('animated emoji in messages follow the autoplay switch', (
    tester,
  ) async {
    addTearDown(() => KometSettings.autoplayAnimoji.value = true);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageAnimoji(lottieUrl: _lottie, size: 48, memCacheWidth: 96),
        ),
      ),
    );

    expect(
      tester.widget<LottieImage>(find.byType(LottieImage)).animate,
      isTrue,
    );

    KometSettings.autoplayAnimoji.value = false;
    await tester.pump();
    expect(
      tester.widget<LottieImage>(find.byType(LottieImage)).animate,
      isFalse,
    );
  });
}

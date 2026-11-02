import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:image/image.dart' as img;
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/backend/modules/share_sender.dart';
import 'package:komet/core/media/share_thumbnail.dart';
import 'package:komet/frontend/screens/chats/share_composer_bar.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/bubble_context.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/photo_bubble.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';
import 'package:komet/models/attachment.dart';
import 'package:komet/models/shared_payload.dart';
import 'package:material_symbols_icons/symbols.dart';

Future<void> _resolveImages(WidgetTester tester) async {
  for (var pass = 0; pass < 2; pass++) {
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    final context = tester.element(find.byType(Scaffold));
    await tester.runAsync(() async {
      await Future.wait([
        for (final image in images)
          precacheImage(image.image, context, onError: (_, _) {}),
      ]);
    });
    await tester.pump();
  }
}

Future<void> _pumpWithImages(WidgetTester tester, Widget widget) async {
  await tester.runAsync(() => tester.pumpWidget(widget));
  await _resolveImages(tester);
}

bool _hasRenderedImage(WidgetTester tester) => tester
    .widgetList<RawImage>(find.byType(RawImage))
    .any((image) => image.image != null);

Future<void> _pumpComposer(WidgetTester tester, PreparedShare share) async {
  final controller = RichMessageController();
  addTearDown(controller.dispose);
  await _pumpWithImages(
    tester,
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Builder(
            builder: (context) => ShareComposerBar.forShare(
              l10n: AppLocalizations.of(context)!,
              share: share,
              controller: controller,
              recipientNames: const ['Synthetic recipient'],
              onSend: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late Directory directory;
  late File photo;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('synthetic_shared_photo');
    final raster = img.Image(width: 320, height: 160);
    img.fill(raster, color: img.ColorRgb8(32, 144, 224));
    photo = File('${directory.path}/synthetic-photo.png')
      ..writeAsBytesSync(img.encodePng(raster));
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    directory.deleteSync(recursive: true);
  });

  SharedFile source({String mime = 'image/png'}) => SharedFile(
    path: photo.path,
    name: 'synthetic-photo.png',
    mime: mime,
    size: photo.lengthSync(),
  );

  test(
    'generic MIME retains image/video kinds without overriding explicit document MIME',
    () {
      expect(
        source(mime: 'application/octet-stream').kind,
        SharedFileKind.photo,
      );
      for (final extension in ['JPG', 'HEIC', 'heif']) {
        expect(
          SharedFile(
            path: '/synthetic/$extension',
            name: 'photo.$extension',
            mime: '',
            size: 1,
          ).kind,
          SharedFileKind.photo,
        );
      }
      expect(
        const SharedFile(
          path: '/synthetic/movie',
          name: 'clip.MOV',
          mime: 'application/octet-stream',
          size: 1,
        ).kind,
        SharedFileKind.video,
      );
      expect(source(mime: 'application/pdf').kind, SharedFileKind.file);
      expect(source(mime: 'image/svg+xml').kind, SharedFileKind.file);
      expect(
        source(mime: 'IMAGE/PNG; charset=binary').kind,
        SharedFileKind.photo,
      );
      expect(
        const SharedFile(
          path: '/synthetic/jpeg',
          name: 'jpeg',
          mime: '',
          size: 1,
        ).kind,
        SharedFileKind.file,
      );
    },
  );

  testWidgets(
    'an incoming local photo prepares and renders a retained thumbnail',
    (tester) async {
      final payload = SharedPayload.fromMap({
        'files': [
          {
            'path': photo.path,
            'name': 'synthetic-photo.png',
            'mime': 'application/octet-stream',
            'size': photo.lengthSync(),
          },
        ],
      })!;
      final prepared = await tester.runAsync(
        () => PreparedShare.prepare(payload),
      );
      final file = prepared!.files.single;
      expect(file.kind, SharedFileKind.photo);
      expect(file.width, 320);
      expect(file.height, 160);
      expect(photo.existsSync(), isTrue);
      final data = base64Decode(file.thumbDataUri!.split(',').last);
      final thumb = img.decodeImage(data)!;
      expect((thumb.width, thumb.height), (128, 64));

      await _pumpComposer(tester, prepared);
      expect(_hasRenderedImage(tester), isTrue);
      expect(find.byIcon(Symbols.description), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      photo.deleteSync();
      await _pumpComposer(tester, prepared);
      expect(_hasRenderedImage(tester), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('composer uses the local image when no thumbnail is supplied', (
    tester,
  ) async {
    await _pumpComposer(
      tester,
      PreparedShare(files: [PreparedShareFile(source: source())]),
    );
    expect(_hasRenderedImage(tester), isTrue);
    expect(photo.existsSync(), isTrue);
    expect(find.byIcon(Symbols.description), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'outgoing photo keeps its embedded preview if the local file is gone',
    (tester) async {
      final preview = await tester.runAsync(
        () => sharedThumbnailDataUri(source()),
      );
      final attachment = PhotoAttachment(
        localPath: photo.path,
        previewData: preview,
        width: 320,
        height: 160,
      );
      photo.deleteSync();
      await _pumpWithImages(
        tester,
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: PhotoBubble(
                  media: [attachment],
                  ctx: BubbleContext(
                    context: context,
                    cs: Theme.of(context).colorScheme,
                    text: Colors.black,
                    shape: BubbleShape.singleMiddle,
                    contentType: MessageType.attachment,
                    hasPhotoWithCaption: false,
                    hasMultiplePhotosNoCaption: false,
                    message: CachedMessage(
                      id: 'synthetic-photo-message',
                      accountId: 101,
                      chatId: 202,
                      senderId: 101,
                      time: 123456,
                      attachments: [attachment],
                    ),
                    isMe: true,
                    myId: 101,
                    chatType: 'DIALOG',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(_hasRenderedImage(tester), isTrue);
      expect(find.byIcon(Symbols.image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a malformed image leaves thumbnail preparation recoverable', (
    tester,
  ) async {
    photo.writeAsBytesSync([1, 2, 3, 4]);
    final thumbnail = await tester.runAsync(
      () => sharedThumbnailDataUri(source()),
    );
    expect(thumbnail, isNull);
    expect(photo.existsSync(), isTrue);
  });
}

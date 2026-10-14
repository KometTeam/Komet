import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/komet_settings.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/edge_stretch_fill.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const int _me = 1;
const int _peer = 7;

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String directory;

  _SyntheticPathProvider(this.directory);

  @override
  Future<String?> getTemporaryPath() async => directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

CachedMessage _photo(int width, int height, {String? caption}) =>
    CachedMessage(
      id: '1',
      accountId: _me,
      chatId: 2,
      senderId: _peer,
      text: caption,
      time: DateTime(2026, 1, 1, 5, 46).millisecondsSinceEpoch,
      status: 'sent',
      attachments: [
        PhotoAttachment(
          baseUrl: 'https://example.com/synthetic-$width-$height.jpg',
          width: width,
          height: height,
        ),
      ],
    );

Future<void> _pumpBubble(WidgetTester tester, CachedMessage message) async {
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
            myId: _me,
            chatType: 'DIALOG',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

CachedNetworkImage _networkImage(WidgetTester tester) =>
    tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

void _expectDecodeKeepsAspect(CachedNetworkImage image, double aspect) {
  final ratio = image.memCacheWidth! / image.memCacheHeight!;
  expect(ratio, closeTo(aspect, aspect * 0.01));
}

Future<Uint8List> _edgeTestPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  void fill(Rect rect, Color color) =>
      canvas.drawRect(rect, Paint()..color = color);
  fill(const Rect.fromLTWH(0, 0, 10, 20), const Color(0xFF808080));
  fill(const Rect.fromLTWH(0, 0, 1, 10), const Color(0xFFFF0000));
  fill(const Rect.fromLTWH(0, 10, 1, 10), const Color(0xFF0000FF));
  fill(const Rect.fromLTWH(9, 0, 1, 10), const Color(0xFF00FF00));
  fill(const Rect.fromLTWH(9, 10, 1, 10), const Color(0xFFFFFF00));
  final image = await recorder.endRecording().toImage(10, 20);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Color _pixel(ByteData rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return Color.fromARGB(
    rgba.getUint8(i + 3),
    rgba.getUint8(i),
    rgba.getUint8(i + 1),
    rgba.getUint8(i + 2),
  );
}

void main() {
  late Directory cache;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('photo_crop_fill');
    PathProviderPlatform.instance = _SyntheticPathProvider(cache.path);
    KometSettings.autoDownloadPhoto.value = true;
  });

  tearDown(() {
    KometSettings.autoDownloadPhoto.value = true;
    cache.deleteSync(recursive: true);
  });

  testWidgets('a captioned screenshot is cropped instead of getting bars', (
    tester,
  ) async {
    await _pumpBubble(tester, _photo(1080, 2340, caption: 'подпись'));

    expect(find.byType(EdgeStretchFill), findsNothing);
    final image = _networkImage(tester);
    expect(image.width, 200);
    expect(image.height, 280);
    _expectDecodeKeepsAspect(image, 1080 / 2340);
  });

  testWidgets('a wide panorama is cropped at the sides', (tester) async {
    await _pumpBubble(tester, _photo(4000, 1000));

    expect(find.byType(EdgeStretchFill), findsNothing);
    _expectDecodeKeepsAspect(_networkImage(tester), 4);
  });

  testWidgets('a photo that would lose too much gets edge bars', (
    tester,
  ) async {
    await _pumpBubble(tester, _photo(1080, 5000, caption: 'подпись'));

    final fill = tester.widget<EdgeStretchFill>(find.byType(EdgeStretchFill));
    expect(fill.source, isNotNull);
    final image = _networkImage(tester);
    expect(image.height, 280);
    expect(image.width, closeTo(280 * 1080 / 5000, 0.01));
    _expectDecodeKeepsAspect(image, 1080 / 5000);
  });

  testWidgets('edge bars never download a photo that waits for a tap', (
    tester,
  ) async {
    KometSettings.autoDownloadPhoto.value = false;
    await _pumpBubble(tester, _photo(1080, 5000, caption: 'подпись'));

    final fill = tester.widget<EdgeStretchFill>(find.byType(EdgeStretchFill));
    expect(fill.source, isNull);
  });

  testWidgets('each bar row takes the colour of the photo edge at that row', (
    tester,
  ) async {
    final png = await tester.runAsync(_edgeTestPng);
    final boundary = GlobalKey();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 200,
                height: 100,
                child: EdgeStretchFill(
                  source: MemoryImage(png!),
                  imageAspect: 0.5,
                  fallback: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    final rgba = await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final data = await image.toByteData();
      image.dispose();
      return data!;
    });

    final topLeft = _pixel(rgba!, 200, 10, 8);
    final bottomLeft = _pixel(rgba, 200, 10, 92);
    final topRight = _pixel(rgba, 200, 190, 8);
    final bottomRight = _pixel(rgba, 200, 190, 92);

    expect(topLeft.r, greaterThan(topLeft.b));
    expect(bottomLeft.b, greaterThan(bottomLeft.r));
    expect(topRight.g, greaterThan(topRight.r));
    expect(bottomRight.r, greaterThan(bottomRight.b));
    expect(bottomRight.g, greaterThan(bottomRight.b));
    expect(_pixel(rgba, 200, 10, 8), _pixel(rgba, 200, 60, 8));
  });
}

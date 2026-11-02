import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/utils/download_history.dart';
import 'package:komet/core/utils/download_progress.dart';
import 'package:komet/core/utils/file_download.dart';
import 'package:komet/core/utils/haptics.dart';
import 'package:komet/core/utils/media_cache.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/bubble_context.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/file_bubble.dart';
import 'package:komet/models/attachment.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

Future<String> _pump(
  WidgetTester tester, {
  required String name,
  required FileBubbleOpener openFile,
  bool cached = false,
  double? progress,
  Widget Function(Widget child)? wrap,
}) async {
  final cacheName = '901_$name';
  await tester.runAsync(() async {
    if (cached) {
      final local = await MediaCache.fileFor(cacheName);
      await local.writeAsBytes(List.filled(2048, 0));
    }
    await MediaCache.existing(cacheName);
  });
  MediaDownloadProgress.set(cacheName, progress);
  addTearDown(() => MediaDownloadProgress.set(cacheName, null));

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final bubble = FileBubble(
              fill: true,
              file: FileAttachment(fileId: 901, name: name, size: 2048),
              openFile: openFile,
              ctx: BubbleContext(
                context: context,
                cs: Theme.of(context).colorScheme,
                text: Colors.black,
                shape: BubbleShape.singleMiddle,
                contentType: MessageType.attachment,
                hasPhotoWithCaption: false,
                hasMultiplePhotosNoCaption: false,
                message: CachedMessage(
                  id: 'synthetic-file-message',
                  accountId: 101,
                  chatId: 202,
                  senderId: 303,
                  time: 123456,
                ),
                isMe: false,
                myId: 101,
                chatType: 'DIALOG',
                chatName: 'Synthetic chat',
              ),
            );
            return Center(
              child: SizedBox(width: 320, child: wrap?.call(bubble) ?? bubble),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return cacheName;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() {
    directory = Directory.systemTemp.createTempSync('synthetic_file_bubble');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    Haptics.enabled = false;
  });

  tearDownAll(() {
    PathProviderPlatform.instance = originalPathProvider;
    Haptics.enabled = true;
    directory.deleteSync(recursive: true);
  });

  testWidgets(
    'tapping a document title starts one download and shows progress',
    (tester) async {
      final completed = Completer<FileDownloadResult>();
      var opens = 0;
      DownloadMetadata? metadata;
      await _pump(
        tester,
        name: 'synthetic-download.pdf',
        openFile: (cacheName, resolveUrl, {onProgress, onReady, download}) {
          opens++;
          metadata = download;
          onProgress?.call(0.4);
          return completed.future.whenComplete(() => onReady?.call());
        },
      );
      expect(find.text('Скачать · 2.0 КБ'), findsOneWidget);

      await tester.tap(find.text('synthetic-download.pdf'));
      await tester.pump();
      expect(find.text('Загрузка 40% · 2.0 КБ'), findsOneWidget);

      await tester.tap(find.text('synthetic-download.pdf'));
      await tester.tap(find.byIcon(Symbols.description));
      await tester.pump();
      expect(opens, 1);
      expect(metadata?.name, 'synthetic-download.pdf');
      expect(metadata?.chatId, 202);
      expect(metadata?.messageId, 'synthetic-file-message');
      completed.complete(const FileDownloadResult(ok: true));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('cached files open from card padding and reject repeated opens', (
    tester,
  ) async {
    final closed = Completer<FileDownloadResult>();
    var opens = 0;
    await _pump(
      tester,
      name: 'synthetic-cached.zip',
      cached: true,
      openFile: (cacheName, resolveUrl, {onProgress, onReady, download}) {
        opens++;
        onReady?.call();
        return closed.future;
      },
    );
    expect(find.text('Открыть · 2.0 КБ'), findsOneWidget);
    final card = tester.getRect(find.byType(FileBubble));

    await tester.tapAt(card.topLeft + const Offset(3, 3));
    await tester.pump();
    expect(find.text('Открытие… · 2.0 КБ'), findsOneWidget);
    await tester.tap(find.text('synthetic-cached.zip'));
    await tester.pump();
    expect(opens, 1);

    closed.complete(const FileDownloadResult(ok: true));
    await tester.pumpAndSettle();
    expect(find.text('Открыть · 2.0 КБ'), findsOneWidget);
  });

  testWidgets('active download taps neither restart it nor open the row menu', (
    tester,
  ) async {
    var opens = 0;
    var menuTaps = 0;
    await _pump(
      tester,
      name: 'synthetic-progress.pdf',
      progress: 0.65,
      wrap: (child) => GestureDetector(onTap: () => menuTaps++, child: child),
      openFile: (cacheName, resolveUrl, {onProgress, onReady, download}) async {
        opens++;
        return const FileDownloadResult(ok: true);
      },
    );

    await tester.tap(find.text('synthetic-progress.pdf'));
    await tester.pump();
    expect(find.text('Загрузка 65% · 2.0 КБ'), findsOneWidget);
    expect(opens, 0);
    expect(menuTaps, 0);
  });

  testWidgets('long press, reply drag and selection remain with the parent', (
    tester,
  ) async {
    var opens = 0;
    var longPresses = 0;
    var replyDrags = 0;
    var selections = 0;
    var selecting = false;
    late StateSetter update;
    await _pump(
      tester,
      name: 'synthetic-gestures.pdf',
      wrap: (child) => StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => selections++,
            onLongPress: () => longPresses++,
            onHorizontalDragUpdate: (_) => replyDrags++,
            child: IgnorePointer(ignoring: selecting, child: child),
          );
        },
      ),
      openFile: (cacheName, resolveUrl, {onProgress, onReady, download}) async {
        opens++;
        return const FileDownloadResult(ok: true);
      },
    );

    await tester.longPress(find.text('synthetic-gestures.pdf'));
    await tester.drag(
      find.text('synthetic-gestures.pdf'),
      const Offset(-80, 0),
    );
    expect(longPresses, 1);
    expect(replyDrags, greaterThan(0));
    update(() => selecting = true);
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.text('synthetic-gestures.pdf')));
    expect(selections, 1);
    expect(opens, 0);
  });

  testWidgets('screen readers receive the file action and download state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final cacheName = await _pump(
      tester,
      name: 'synthetic-accessibility.pdf',
      openFile: (cacheName, resolveUrl, {onProgress, onReady, download}) async {
        return const FileDownloadResult(ok: true);
      },
    );
    final finder = find.bySemanticsLabel('synthetic-accessibility.pdf');
    expect(
      tester.getSemantics(finder),
      matchesSemantics(
        label: 'synthetic-accessibility.pdf',
        value: 'Скачать · 2.0 КБ',
        hint: 'Скачать и открыть файл',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    MediaDownloadProgress.set(cacheName, 0.5);
    await tester.pump();
    expect(
      tester.getSemantics(finder),
      matchesSemantics(
        label: 'synthetic-accessibility.pdf',
        value: 'Загрузка 50% · 2.0 КБ',
        isButton: true,
        hasEnabledState: true,
      ),
    );
    semantics.dispose();
  });
}

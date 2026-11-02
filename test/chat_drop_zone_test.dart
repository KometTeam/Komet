import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/view/chat_drop_zone.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

const _channel = 'desktop_drop';

Future<void> _platformCall(WidgetTester tester, String method, Object args) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _channel,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('komet_drop_zone_test');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<List<List<String>>> pumpZone(WidgetTester tester) async {
    final drops = <List<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatDropZone(
          enabled: true,
          onDrop: drops.add,
          child: const SizedBox.expand(),
        ),
      ),
    );
    return drops;
  }

  testWidgets('a folder reported as a plain file is still recognised', (
    tester,
  ) async {
    final drops = await pumpZone(tester);
    final file = p.join(dir.path, 'notes.txt');
    File(file).writeAsStringSync('hi');
    final folder = Directory(p.join(dir.path, 'album'))..createSync();

    await tester.runAsync(() async {
      await _platformCall(tester, 'entered', [20.0, 20.0]);
      await _platformCall(tester, 'performOperation', [folder.path, file]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(drops, [
      [file],
    ]);
    expect(find.textContaining("Folders can't be sent"), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('files alone go through without a notice', (tester) async {
    final drops = await pumpZone(tester);
    final file = p.join(dir.path, 'photo.jpg');
    File(file).writeAsBytesSync([1, 2, 3]);

    await tester.runAsync(() async {
      await _platformCall(tester, 'entered', [20.0, 20.0]);
      await _platformCall(tester, 'performOperation', [file]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(drops, [
      [file],
    ]);
    expect(find.textContaining("Folders can't be sent"), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}

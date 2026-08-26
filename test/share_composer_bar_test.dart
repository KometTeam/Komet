import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/backend/modules/share_sender.dart';
import 'package:komet/frontend/screens/chats/share_composer_bar.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';
import 'package:komet/models/shared_payload.dart';

PreparedShareFile _file(String name, String mime) => PreparedShareFile(
  source: SharedFile(path: '/synthetic/$name', name: name, mime: mime, size: 8),
);

Future<RichMessageController> _pump(
  WidgetTester tester, {
  required PreparedShare share,
  required List<String> recipients,
  bool sending = false,
  Future<void> Function(String)? onSend,
}) async {
  final controller = RichMessageController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ShareComposerBar(
            share: share,
            controller: controller,
            recipientNames: recipients,
            sending: sending,
            onSend: onSend ?? (_) async {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('a single photo names itself and lists the recipient', (
    tester,
  ) async {
    await _pump(
      tester,
      share: PreparedShare(files: [_file('a.jpg', 'image/jpeg')]),
      recipients: const ['ЛУКА'],
    );

    expect(find.text('Отправить фотографию'), findsOneWidget);
    expect(find.text('В чат ЛУКА'), findsOneWidget);
    expect(find.text('Добавить подпись...'), findsOneWidget);
  });

  testWidgets('three chats collapse into a count and a badge', (tester) async {
    await _pump(
      tester,
      share: PreparedShare(
        files: [
          _file('a.jpg', 'image/jpeg'),
          _file('b.jpg', 'image/jpeg'),
          _file('c.jpg', 'image/jpeg'),
        ],
      ),
      recipients: const ['a', 'b', 'c'],
    );

    expect(find.text('Отправить 3 фотографии'), findsOneWidget);
    expect(find.text('В 3 чата'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a text share drops the preview row', (tester) async {
    final controller = await _pump(
      tester,
      share: const PreparedShare(files: [], text: 'https://komet.pw'),
      recipients: const ['ЛУКА'],
    );

    expect(find.text('Отправить сообщение'), findsNothing);
    expect(find.text('Сообщение'), findsOneWidget);
    expect(controller.text, '');
  });

  testWidgets('a file share still shows a title but no photo wording', (
    tester,
  ) async {
    await _pump(
      tester,
      share: PreparedShare(files: [_file('doc.pdf', 'application/pdf')]),
      recipients: const ['ЛУКА', 'Zarub'],
    );

    expect(find.text('Отправить файл'), findsOneWidget);
    expect(find.text('В чат ЛУКА, Zarub'), findsOneWidget);
  });

  testWidgets('the caption reaches onSend', (tester) async {
    String? captured;
    final controller = await _pump(
      tester,
      share: PreparedShare(files: [_file('a.jpg', 'image/jpeg')]),
      recipients: const ['ЛУКА'],
      onSend: (caption) async => captured = caption,
    );

    controller.text = '  привет  ';
    await tester.pump();
    await tester.tap(find.byIcon(Symbols.send));
    await tester.pump();

    expect(captured, 'привет');
  });

  testWidgets('with no recipients the send button is inert', (tester) async {
    var sent = false;
    await _pump(
      tester,
      share: PreparedShare(files: [_file('a.jpg', 'image/jpeg')]),
      recipients: const [],
      onSend: (_) async => sent = true,
    );

    expect(find.text('Выберите чат'), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.send));
    await tester.pump();
    expect(sent, isFalse);
  });
}

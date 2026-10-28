import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/screens/chats/chat/message_media_draft.dart';
import 'package:komet/frontend/screens/chats/chat/view/message_row_widgets.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/bubble_context.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';
import 'package:material_symbols_icons/symbols.dart';

const _first = PhotoAttachment(photoId: 1, photoToken: 'synthetic-a');
const _second = PhotoAttachment(photoId: 2, photoToken: 'synthetic-b');

CachedMessage _message(
  List<MessageAttachment>? attachments, {
  String? status,
}) => CachedMessage(
  id: '1000',
  accountId: 101,
  chatId: 202,
  senderId: 101,
  time: 123456,
  status: status,
  attachments: attachments,
);

void main() {
  group('editable photos', () {
    test('only an album of photos with tokens can be edited', () {
      expect(MessageMediaDraft.editablePhotos(_message(null)), isNull);
      expect(MessageMediaDraft.editablePhotos(_message(const [])), isNull);
      expect(
        MessageMediaDraft.editablePhotos(
          _message(const [_first, VideoAttachment(videoId: 3)]),
        ),
        isNull,
      );
      expect(
        MessageMediaDraft.editablePhotos(
          _message(const [_first, PhotoAttachment(photoId: 4)]),
        ),
        isNull,
      );
      expect(
        MessageMediaDraft.editablePhotos(_message(const [_first, _second])),
        [_first, _second],
      );
    });

    test('removing a photo changes the draft and keeps the rest', () async {
      final draft = MessageMediaDraft(const [_first, _second]);
      addTearDown(draft.dispose);
      expect(draft.changed, isFalse);

      draft.remove(draft.items.first);

      expect(draft.changed, isTrue);
      expect(draft.isEmpty, isFalse);
      expect(await draft.settle(), [
        {'_type': 'PHOTO', 'photoToken': 'synthetic-b'},
      ]);
    });

    test('removing every photo leaves an empty attachment list', () async {
      final draft = MessageMediaDraft(const [_first]);
      addTearDown(draft.dispose);

      draft.remove(draft.items.single);

      expect(draft.isEmpty, isTrue);
      expect(await draft.settle(), isEmpty);
    });
  });

  testWidgets('media meta marks an edited message', (tester) async {
    Widget meta(String? status) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Builder(
        builder: (context) {
          final ctx = BubbleContext(
            context: context,
            cs: Theme.of(context).colorScheme,
            text: Colors.black,
            shape: BubbleShape.singleMiddle,
            contentType: MessageType.attachment,
            hasPhotoWithCaption: true,
            hasMultiplePhotosNoCaption: false,
            message: _message(const [_first], status: status),
            isMe: false,
            myId: 101,
            chatType: 'DIALOG',
          );
          return Column(children: [ctx.compactTime(), ctx.meta()]);
        },
      ),
    );

    await tester.pumpWidget(meta('EDITED'));
    expect(find.textContaining('ред.'), findsNWidgets(2));

    await tester.pumpWidget(meta(null));
    expect(find.textContaining('ред.'), findsNothing);
  });

  group('edit sheet', () {
    Future<void> open(
      WidgetTester tester,
      void Function(EditedMessage? result) onClosed,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onClosed(
                await showModalBottomSheet<EditedMessage>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => EditMessageSheet(
                    text: '',
                    formatRanges: const [],
                    photos: const [_first, _second],
                    contextMenuBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    FilledButton saveButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('sends only the photos left in the message', (tester) async {
      EditedMessage? result;
      await open(tester, (value) => result = value);
      expect(find.byIcon(Symbols.close), findsNWidgets(2));

      await tester.tap(find.byIcon(Symbols.close).first);
      await tester.pump();
      expect(find.byIcon(Symbols.close), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(result?.attachments, [
        {'_type': 'PHOTO', 'photoToken': 'synthetic-b'},
      ]);
    });

    testWidgets('untouched photos are not sent again', (tester) async {
      EditedMessage? result;
      await open(tester, (value) => result = value);

      await tester.enterText(find.byType(TextField), 'Synthetic caption');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(result?.text, 'Synthetic caption');
      expect(result?.attachments, isNull);
    });

    testWidgets('an empty message without photos cannot be saved', (
      tester,
    ) async {
      await open(tester, (_) {});
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.byIcon(Symbols.close).first);
      await tester.pump();
      await tester.tap(find.byIcon(Symbols.close).first);
      await tester.pump();
      expect(saveButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Synthetic caption');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNotNull);
    });
  });
}

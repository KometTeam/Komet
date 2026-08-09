import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/view/chat_preview_line.dart';
import 'package:komet/models/chat_preview_media.dart';
import 'package:material_symbols_icons/symbols.dart';

const String _pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

const TextStyle _style = TextStyle(fontSize: 14, height: 1.2);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

String _plainText(WidgetTester tester) {
  final span = tester.widget<Text>(find.byType(Text).first).textSpan!;
  final buffer = StringBuffer();
  span.visitChildren((child) {
    if (child is TextSpan && child.text != null) buffer.write(child.text);
    return true;
  });
  return buffer.toString();
}

List<TextSpan> _spans(WidgetTester tester) {
  final span = tester.widget<Text>(find.byType(Text).first).textSpan!;
  final result = <TextSpan>[];
  span.visitChildren((child) {
    if (child is TextSpan && child.text != null) result.add(child);
    return true;
  });
  return result;
}

void main() {
  testWidgets('фото без подписи: миниатюра и курсивная подпись', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ChatPreviewLine(
          text: 'Изображение',
          style: _style,
          media: ChatPreviewMedia(
            kind: ChatPreviewKind.photo,
            thumbs: [ChatPreviewThumb(source: _pixel)],
            label: 'Изображение',
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Symbols.play_arrow), findsNothing);
    expect(_plainText(tester), 'Изображение');
    expect(_spans(tester).single.style?.fontStyle, FontStyle.italic);
  });

  testWidgets('фото с подписью: миниатюра и обычный текст', (tester) async {
    await tester.pumpWidget(
      _host(
        const ChatPreviewLine(
          prefix: 'Кто-то: ',
          text: 'смотри',
          style: _style,
          media: ChatPreviewMedia(
            kind: ChatPreviewKind.photo,
            thumbs: [ChatPreviewThumb(source: _pixel)],
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(_plainText(tester), 'Кто-то: смотри');
    expect(_spans(tester).last.style?.fontStyle, isNot(FontStyle.italic));
  });

  testWidgets('видео помечается иконкой проигрывания на миниатюре', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ChatPreviewLine(
          text: 'Видео',
          style: _style,
          media: ChatPreviewMedia(
            kind: ChatPreviewKind.video,
            thumbs: [
              ChatPreviewThumb(source: _pixel, video: true),
              ChatPreviewThumb(source: _pixel),
            ],
            label: 'Видео',
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byIcon(Symbols.play_arrow), findsOneWidget);
  });

  testWidgets('файл: иконка вместо слова и имя после двоеточия', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ChatPreviewLine(
          text: 'Файл: notes.pdf',
          style: _style,
          media: ChatPreviewMedia(
            kind: ChatPreviewKind.file,
            label: 'Файл',
            detail: 'notes.pdf',
          ),
        ),
      ),
    );

    expect(find.byIcon(Symbols.description), findsOneWidget);
    expect(_plainText(tester), ': notes.pdf');
  });

  testWidgets('специфичная подпись идёт с иконкой и курсивом', (tester) async {
    await tester.pumpWidget(
      _host(
        const ChatPreviewLine(
          text: 'Пропущенный звонок',
          style: _style,
          media: ChatPreviewMedia(
            kind: ChatPreviewKind.missedCall,
            label: 'Пропущенный звонок',
          ),
        ),
      ),
    );

    expect(find.byIcon(Symbols.call_missed), findsOneWidget);
    expect(_plainText(tester), 'Пропущенный звонок');
    expect(_spans(tester).single.style?.fontStyle, FontStyle.italic);
  });

  testWidgets('метка пересылки остаётся перед иконкой', (tester) async {
    await tester.pumpWidget(
      _host(
        const ChatPreviewLine(
          text: '↪ Контакт',
          style: _style,
          media: ChatPreviewMedia(
            kind: ChatPreviewKind.contact,
            label: '↪ Контакт',
          ),
        ),
      ),
    );

    expect(find.byIcon(Symbols.person), findsOneWidget);
    expect(_plainText(tester), '↪ Контакт');
  });

  testWidgets('ссылка с текстом сообщения не тащит иконку', (tester) async {
    await tester.pumpWidget(
      _host(
        const ChatPreviewLine(
          text: 'глянь komet.ru',
          style: _style,
          media: ChatPreviewMedia(kind: ChatPreviewKind.share),
        ),
      ),
    );

    expect(find.byIcon(Symbols.link), findsNothing);
    expect(_plainText(tester), 'глянь komet.ru');
  });

  testWidgets('без описания вложения строка остаётся обычным текстом', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ChatPreviewLine(text: 'привет', style: _style)),
    );

    expect(find.byType(Image), findsNothing);
    expect(_plainText(tester), 'привет');
  });

  test('иконка типа чата зависит от вида чата', () {
    expect(chatKindIcon('CHANNEL', isBot: false), Symbols.campaign);
    expect(chatKindIcon('CHAT', isBot: false), Symbols.group);
    expect(chatKindIcon('GROUP', isBot: false), Symbols.group);
    expect(chatKindIcon('DIALOG', isBot: true), Symbols.smart_toy);
    expect(chatKindIcon('DIALOG', isBot: false), isNull);
  });
}

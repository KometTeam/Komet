import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/screens/chats/chat/view/chat_preview_line.dart';

void main() {
  testWidgets('упоминание в превью чата красится как в самом чате', (
    tester,
  ) async {
    final theme = ThemeData(colorSchemeSeed: Colors.blue);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: ChatPreviewLine(
            prefix: 'Автор: ',
            text: 'привет @Тестовый, как дела',
            ranges: [
              FormatRange(
                format: TextFormat.userMention,
                start: 7,
                length: 9,
                entityId: 42,
              ),
            ],
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final spans = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    final mention = spans.firstWhere((s) => s.text == '@Тестовый');
    final plain = spans.firstWhere((s) => s.text == 'привет ');

    expect(mention.style?.color, theme.colorScheme.primary);
    expect(plain.style?.color, isNot(theme.colorScheme.primary));
  });
}

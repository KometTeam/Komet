import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/ios_typography.dart';
import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/screens/chats/chat/view/message_list_decorations.dart';

TextStyle _messageBody() => TextStyle(
  fontSize: 16,
  fontFamily: 'Inter',
  fontWeight: IosTypography.messageBodyWeight(),
  fontVariations: IosTypography.messageBodyVariations('Inter'),
);

void main() {
  testWidgets(
    'iOS draws the message body at regular weight and bold spans bold',
    (tester) async {
      final body = _messageBody();
      expect(body.fontWeight, FontWeight.w400);
      expect(body.fontVariations, isNull);

      final bold = applyTextFormats(body, {TextFormat.strong});
      expect(bold.fontWeight, FontWeight.w700);
      expect(bold.fontVariations, isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('Android keeps the light Inter message body', (tester) async {
    final body = _messageBody();
    expect(body.fontWeight, isNull);
    expect(body.fontVariations, const [FontVariation('wght', 300)]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS weights: regular body, semibold titles, upright text', (
    tester,
  ) async {
    expect(IosTypography.body(FontWeight.w500), FontWeight.w400);
    expect(IosTypography.title(FontWeight.w500), FontWeight.w600);
    expect(IosTypography.title(FontWeight.w700), FontWeight.w600);
    expect(IosTypography.upright(FontStyle.italic), FontStyle.normal);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android weights are left as they are', (tester) async {
    expect(IosTypography.body(FontWeight.w500), FontWeight.w500);
    expect(IosTypography.title(FontWeight.w700), FontWeight.w700);
    expect(IosTypography.upright(FontStyle.italic), FontStyle.italic);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  Future<Text> pumpDateChip(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DateSeparatorLabel(date: DateTime.now())),
      ),
    );
    return tester.widget<Text>(find.text('Сегодня'));
  }

  testWidgets('iOS date chip is regular and upright', (tester) async {
    final text = await pumpDateChip(tester);
    expect(text.style?.fontStyle, FontStyle.normal);
    expect(text.style?.fontWeight, FontWeight.w400);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android date chip keeps its italic', (tester) async {
    final text = await pumpDateChip(tester);
    expect(text.style?.fontStyle, FontStyle.italic);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

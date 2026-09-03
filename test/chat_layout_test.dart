import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/chat_layout.dart';

void main() {
  test('mobile bubbles use 80 percent of the pane', () {
    expect(ChatLayout.maxBubbleWidth(390), closeTo(312, 0.1));
  });

  test('wide panes keep a centered column instead of stretching', () {
    expect(ChatLayout.horizontalInset(390), 0);
    expect(ChatLayout.horizontalInset(1200), closeTo(230, 0.1));
    expect(ChatLayout.maxBubbleWidth(1200), ChatLayout.bubbleHardCap);
  });
}

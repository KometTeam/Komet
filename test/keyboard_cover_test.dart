import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/keyboard_cover.dart';

const _keyboardOpen = MediaQueryData(
  size: Size(400, 800),
  viewInsets: EdgeInsets.only(bottom: 300),
  viewPadding: EdgeInsets.only(top: 24, bottom: 20),
  padding: EdgeInsets.only(top: 24),
);

void main() {
  testWidgets('под шторкой приложение видит клавиатуру закрытой', (
    tester,
  ) async {
    late MediaQueryData seen;
    await tester.pumpWidget(
      MediaQuery(
        data: _keyboardOpen,
        child: KeyboardCoverScope(
          child: Builder(
            builder: (context) {
              seen = MediaQuery.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(seen.viewInsets.bottom, 300);

    KeyboardCover.instance.active.value = true;
    addTearDown(() => KeyboardCover.instance.active.value = false);
    await tester.pump();

    expect(seen.viewInsets.bottom, 0);
    expect(seen.padding.bottom, 20);
    expect(seen.padding.top, 24);
  });

  test('без Android накрыть клавиатуру нельзя', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await KeyboardCover.instance.engage(), isFalse);
    expect(KeyboardCover.instance.active.value, isFalse);
  });
}

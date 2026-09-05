import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/selection_check_circle.dart';

void main() {
  test('кружок выбора помещается в строку любой высоты', () {
    for (var height = 8.0; height <= 200.0; height += 1) {
      final diameter = SelectionCheckCircle.diameterFor(height);
      final bottom = SelectionCheckCircle.bottomInsetFor(height, diameter);
      expect(
        diameter + bottom,
        lessThanOrEqualTo(height),
        reason: 'высота строки $height',
      );
    }
  });

  test('на обычной строке размер и отступ прежние', () {
    const diameter = SelectionCheckCircle.maxDiameter;
    expect(SelectionCheckCircle.diameterFor(64), diameter);
    expect(
      SelectionCheckCircle.bottomInsetFor(64, diameter),
      SelectionCheckCircle.preferredBottomInset,
    );
  });

  testWidgets('на низкой строке кружок сжимается', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 26,
              width: 200,
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: SelectionCheckCircle(
                  selected: true,
                  diameter: SelectionCheckCircle.diameterFor(26),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(SelectionCheckCircle));
    expect(size.height, 22);
    expect(size.height, lessThanOrEqualTo(26));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/draggable_floating_layer.dart';

const _screen = Size(400, 800);
const _safe = EdgeInsets.only(top: 48, bottom: 24);

FloatingDockGeometry _dockOf(Size size) =>
    FloatingDockGeometry(bounds: _screen, size: size, safeArea: _safe);

final _badge = _dockOf(const Size(120, 118));

void main() {
  test('бейджик стартует у правого края над нижней панелью', () {
    final resting = _badge.resting;
    expect(resting.dx, _screen.width - 120 - 12);
    expect(resting.dy, _screen.height - 118 - 24 - 96);
  });

  test('позиция зажата в безопасной зоне', () {
    expect(_badge.clamp(const Offset(-500, -500)), Offset(12, 48 + 12));
    expect(
      _badge.clamp(const Offset(9999, 9999)),
      Offset(_screen.width - 120 - 12, _screen.height - 118 - 24 - 12),
    );
  });

  test('без броска липнет к ближнему краю', () {
    final left = _badge.snap(const Offset(40, 300), Offset.zero);
    expect(left.dx, 12);
    expect(
      left.dy,
      300,
      reason: 'высота не меняется без вертикальной скорости',
    );

    final right = _badge.snap(const Offset(250, 300), Offset.zero);
    expect(right.dx, _screen.width - 120 - 12);
  });

  test('бросок перебивает ближний край', () {
    final flungRight = _badge.snap(const Offset(40, 300), const Offset(900, 0));
    expect(flungRight.dx, _screen.width - 120 - 12);

    final flungLeft = _badge.snap(
      const Offset(250, 300),
      const Offset(-900, 0),
    );
    expect(flungLeft.dx, 12);
  });

  test('слабый рывок не считается броском', () {
    final weak = _badge.snap(const Offset(40, 300), const Offset(200, 0));
    expect(weak.dx, 12);
  });

  test('вертикальный бросок продолжает движение, но не за экран', () {
    final down = _badge.snap(const Offset(250, 300), const Offset(0, 1000));
    expect(down.dy, 300 + 1000 * FloatingDockGeometry.flingSeconds);

    final overshoot = _badge.snap(
      const Offset(250, 600),
      const Offset(0, 5000),
    );
    expect(overshoot.dy, _screen.height - 118 - 24 - 12);

    final up = _badge.snap(const Offset(250, 100), const Offset(0, -5000));
    expect(up.dy, 48 + 12);
  });

  test('раскрытие бейджика удерживает правый край на месте', () {
    final collapsed = _badge;
    final expanded = _dockOf(const Size(152, 166));

    final docked = collapsed.resting;
    final grown = expanded.clamp(docked);

    expect(
      grown.dx + 152,
      docked.dx + 120,
      reason: 'кнопки должны вырастать влево, а не выезжать за экран',
    );
  });

  test('узкий экран не переворачивает границы', () {
    final tiny = FloatingDockGeometry(
      bounds: const Size(100, 200),
      size: const Size(120, 118),
      safeArea: EdgeInsets.zero,
    );
    expect(tiny.maxX, tiny.minX);
    expect(tiny.clamp(const Offset(50, 50)).dx, 12);
  });
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/video_note_bubble.dart';

const _extent = 210.0;
const _knob = 7.0;
const _geometry = NoteRingGeometry(extent: _extent, knobRadius: _knob);

void main() {
  test('ручка идёт по ободу от 12 часов по часовой', () {
    final center = _geometry.center;
    final r = _geometry.radius;

    expect(_geometry.knobCenter(0).dx, closeTo(center.dx, 0.001));
    expect(_geometry.knobCenter(0).dy, closeTo(center.dy - r, 0.001));

    expect(_geometry.knobCenter(0.25).dx, closeTo(center.dx + r, 0.001));
    expect(_geometry.knobCenter(0.25).dy, closeTo(center.dy, 0.001));

    expect(_geometry.knobCenter(0.5).dy, closeTo(center.dy + r, 0.001));
    expect(_geometry.knobCenter(0.75).dx, closeTo(center.dx - r, 0.001));

    expect(_geometry.knobCenter(1).dx, closeTo(center.dx, 0.001));
    expect(_geometry.knobCenter(1).dy, closeTo(center.dy - r, 0.001));
  });

  test('ручка целиком помещается в бокс и не обрезается', () {
    for (var i = 0; i <= 100; i++) {
      final knob = _geometry.knobCenter(i / 100);
      expect(knob.dx - _knob, greaterThanOrEqualTo(0));
      expect(knob.dy - _knob, greaterThanOrEqualTo(0));
      expect(knob.dx + _knob, lessThanOrEqualTo(_extent));
      expect(knob.dy + _knob, lessThanOrEqualTo(_extent));
    }
  });

  test('центр кружка остаётся под тап, обод и ручка ловят драг', () {
    expect(
      _geometry.grabs(_geometry.center, 0),
      isFalse,
      reason: 'центр должен переключать воспроизведение, а не мотать',
    );
    expect(_geometry.grabs(_geometry.knobCenter(0.4), 0.4), isTrue);
    expect(
      _geometry.grabs(_geometry.knobCenter(0.4) + const Offset(0, 18), 0.4),
      isTrue,
      reason: 'промах мимо ручки в пределах допуска всё ещё считается',
    );

    final onBand = _geometry.center + Offset(_geometry.radius, 0);
    expect(_geometry.grabs(onBand, 0), isTrue);

    final wellInside = _geometry.center + Offset(_geometry.radius / 2, 0);
    expect(_geometry.grabs(wellInside, 0), isFalse);
  });

  test('тап по ободу попадает ровно в свою долю', () {
    for (final progress in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 0.999]) {
      expect(
        _geometry.progressAt(_geometry.knobCenter(progress)),
        closeTo(progress, 0.0001),
        reason: 'тап по точке $progress',
      );
    }
  });

  test('тап работает на любом удалении от обода вдоль того же луча', () {
    final center = _geometry.center;
    for (final radius in [_geometry.radius - 10, _geometry.radius + 5]) {
      final point = center + Offset(radius, 0);
      expect(_geometry.progressAt(point), closeTo(0.25, 0.0001));
    }
  });

  test('захват абсолютный: драг ведёт ручку ровно под пальцем', () {
    for (final route in [
      [0.1, 0.3],
      [0.4, 0.2],
      [0.7, 0.95],
      [0.0, 0.15],
    ]) {
      final from = _geometry.knobCenter(route[0]);
      final to = _geometry.knobCenter(route[1]);

      final grabbed = _geometry.progressAt(from);
      expect(
        grabbed,
        closeTo(route[0], 1e-4),
        reason: 'захват должен встать в точку пальца, а не в текущую позицию',
      );

      final delta = NoteRingGeometry.angleDelta(
        _geometry.angleAt(from),
        _geometry.angleAt(to),
      );
      expect(
        _geometry.advance(grabbed, delta),
        closeTo(route[1], 1e-4),
        reason: 'ручка отстала от пальца на маршруте $route',
      );
    }
  });

  test('прокрутка мимо конца упирается, а не заворачивается в начало', () {
    final from = _geometry.knobCenter(0.9);
    final to = _geometry.knobCenter(0.1);
    final delta = NoteRingGeometry.angleDelta(
      _geometry.angleAt(from),
      _geometry.angleAt(to),
    );
    expect(delta, greaterThan(0));
    expect(_geometry.advance(_geometry.progressAt(from), delta), 1.0);
  });

  test('переход через 12 часов не перебрасывает позицию', () {
    final before = _geometry.angleAt(
      _geometry.center + const Offset(-4, -90),
    );
    final after = _geometry.angleAt(_geometry.center + const Offset(4, -90));
    final delta = NoteRingGeometry.angleDelta(before, after);

    expect(delta.abs(), lessThan(0.3), reason: 'скачок вместо плавного шага');
    expect(delta, greaterThan(0));
    expect(_geometry.advance(0.99, delta), 1.0);
    expect(_geometry.advance(0.01, -delta), greaterThanOrEqualTo(0.0));
  });

  test('прогресс зажат в границах при бесконечной прокрутке', () {
    expect(_geometry.advance(0.5, 100 * math.pi), 1.0);
    expect(_geometry.advance(0.5, -100 * math.pi), 0.0);
  });

  test('увеличенный кружок сохраняет пропорции обода', () {
    const big = NoteRingGeometry(extent: 357, knobRadius: 9);
    expect(big.radius, closeTo(357 / 2 - 10, 0.001));
    expect(big.knobCenter(0).dy, closeTo(big.center.dy - big.radius, 0.001));
    expect(big.knobCenter(0.5).dy + 9, lessThanOrEqualTo(357));
  });
}

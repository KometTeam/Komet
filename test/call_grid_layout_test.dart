import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/calls/call_grid.dart';

void main() {
  const desktop = Size(1840, 690);
  const phone = Size(360, 600);

  test('два участника на широком экране встают рядом и тянутся на всю высоту', () {
    final layout = CallGridLayout.fit(desktop, 2, gap: 8);
    expect(layout.columns, 2);
    expect(layout.rows, 1);
    expect(layout.tile.height, 690);
    expect(layout.tile.width, closeTo(916, 0.01));
  });

  test('два участника на телефоне встают друг под другом', () {
    final layout = CallGridLayout.fit(phone, 2, gap: 8);
    expect(layout.columns, 1);
    expect(layout.rows, 2);
    expect(layout.tile.width, 360);
  });

  test('чем больше участников, тем меньше плитка', () {
    var previous = double.infinity;
    for (var count = 1; count <= 12; count++) {
      final tile = CallGridLayout.fit(desktop, count).tile;
      final area = tile.width * tile.height;
      expect(area, lessThanOrEqualTo(previous + 0.01), reason: '$count');
      previous = area;
    }
  });

  test('неполный последний ряд центрируется', () {
    final layout = CallGridLayout.fit(const Size(900, 600), 5, gap: 10);
    expect(layout.columns, 3);
    final first = layout.rectAt(3);
    final second = layout.rectAt(4);
    final rowCenter = (first.left + second.right) / 2;
    expect(rowCenter, closeTo(450, 0.01));
  });

  test('плитки не вылезают за область и не пересекаются', () {
    for (final area in [desktop, phone, const Size(800, 1280)]) {
      for (var count = 1; count <= 16; count++) {
        final layout = CallGridLayout.fit(area, count, gap: 8);
        final bounds = Offset.zero & area;
        final rects = [for (var i = 0; i < count; i++) layout.rectAt(i)];
        for (final r in rects) {
          expect(bounds.inflate(0.01).contains(r.topLeft), isTrue);
          expect(bounds.inflate(0.01).contains(r.bottomRight), isTrue);
        }
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            final overlap = rects[i].intersect(rects[j]);
            expect(
              overlap.width <= 0.01 || overlap.height <= 0.01,
              isTrue,
              reason: '$area $count: $i и $j пересеклись',
            );
          }
        }
      }
    }
  });

  test('одна плитка на ультрашироком экране не растягивается в полосу', () {
    final layout = CallGridLayout.fit(const Size(3000, 600), 1);
    expect(layout.tile.width / layout.tile.height, CallGridLayout.widestAspect);
    expect(layout.rectAt(0).center.dx, closeTo(1500, 0.01));
  });

  test('вместимость страницы растёт с площадью экрана', () {
    final small = CallGridLayout.capacity(phone, minSide: 120);
    final large = CallGridLayout.capacity(desktop, minSide: 120);
    expect(small, greaterThanOrEqualTo(4));
    expect(large, greaterThan(small));
    final tile = CallGridLayout.fit(phone, small).tile;
    expect(tile.shortestSide, greaterThanOrEqualTo(120));
  });
}

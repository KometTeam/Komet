import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/bubble_context.dart';

void main() {
  test('16:9 video stays 16:9 inside the max box', () {
    final size = BubbleContext.fitMediaSize(1920, 1080);
    expect(size.width, closeTo(280, 0.1));
    expect(size.height, closeTo(157.5, 0.1));
  });

  test('panorama keeps a wide strip instead of a cropped square', () {
    final size = BubbleContext.fitMediaSize(4000, 200);
    expect(size.width, closeTo(280, 0.1));
    expect(size.height / size.width, closeTo(200 / 4000, 0.001));
  });

  test('tiny stickers scale up uniformly', () {
    final size = BubbleContext.fitMediaSize(20, 20);
    expect(size.width, closeTo(100, 0.1));
    expect(size.height, closeTo(100, 0.1));
  });

  test('missing dimensions fall back to a square', () {
    final size = BubbleContext.fitMediaSize(0, 0);
    expect(size.width, size.height);
  });
}

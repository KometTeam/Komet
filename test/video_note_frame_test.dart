import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/video_note_frame.dart';

void main() {
  const fallback = 220.0;

  test('a reported frame is used as is', () {
    expect(
      videoNoteFrameSize(const Size(480, 480), fallback),
      const Size(480, 480),
    );
    expect(
      videoNoteFrameSize(const Size(640, 360), fallback),
      const Size(640, 360),
    );
  });

  test('an unreported frame falls back to a square of the circle size', () {
    expect(videoNoteFrameSize(Size.zero, fallback), const Size(220, 220));
  });

  test('a half-reported frame keeps the dimension it does have', () {
    expect(
      videoNoteFrameSize(const Size(480, 0), fallback),
      const Size(480, 220),
    );
    expect(
      videoNoteFrameSize(const Size(0, 480), fallback),
      const Size(220, 480),
    );
  });

  test('negative and non-finite dimensions fall back', () {
    expect(
      videoNoteFrameSize(const Size(-1, -1), fallback),
      const Size(220, 220),
    );
    expect(
      videoNoteFrameSize(const Size(double.nan, double.infinity), fallback),
      const Size(220, 220),
    );
  });
}

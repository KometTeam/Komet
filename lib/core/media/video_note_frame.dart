import 'dart:ui';

Size videoNoteFrameSize(Size frame, double fallback) {
  final width = frame.width.isFinite && frame.width > 0
      ? frame.width
      : fallback;
  final height = frame.height.isFinite && frame.height > 0
      ? frame.height
      : fallback;
  return Size(width, height);
}

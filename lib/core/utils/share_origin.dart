import 'package:flutter/material.dart';

Rect shareOriginOf(BuildContext? context) {
  final box = context?.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize && box.attached) {
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.isEmpty) return rect;
  }
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}

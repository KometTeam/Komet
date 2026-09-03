import 'package:flutter/widgets.dart';

import '../config/app_bubble_behavior.dart';
import '../config/app_bubble_shape.dart';

const double kBubbleBigRadius = 24;
const double kBubbleSmallRadius = 4;

const Radius _big = Radius.circular(kBubbleBigRadius);
const Radius _small = Radius.circular(kBubbleSmallRadius);

BorderRadius computeBubbleRadius({
  required bool isMe,
  required bool isTop,
  required bool isBottom,
  required BubbleStyle style,
  required BubbleBehavior behavior,
}) {
  final outer = style == BubbleStyle.desktop ? _small : _big;
  final isSingle = isTop && isBottom;

  Radius tl = outer, tr = outer, bl = outer, br = outer;

  if (behavior == BubbleBehavior.immutable || isSingle) {
    return BorderRadius.only(
      topLeft: tl,
      topRight: tr,
      bottomLeft: bl,
      bottomRight: br,
    );
  }

  if (isMe) {
    if (isTop) {
      br = _small;
    } else if (isBottom) {
      tr = _small;
    } else {
      tr = _small;
      br = _small;
    }
  } else {
    if (isTop) {
      bl = _small;
    } else if (isBottom) {
      tl = _small;
    } else {
      tl = _small;
      bl = _small;
    }
  }

  return BorderRadius.only(
    topLeft: tl,
    topRight: tr,
    bottomLeft: bl,
    bottomRight: br,
  );
}

BorderRadius albumClipRadius(
  BorderRadius bubble, {
  required bool hasCaption,
  required bool hasContentAbove,
}) {
  return BorderRadius.only(
    topLeft: hasContentAbove ? Radius.zero : bubble.topLeft,
    topRight: hasContentAbove ? Radius.zero : bubble.topRight,
    bottomLeft: hasCaption ? Radius.zero : bubble.bottomLeft,
    bottomRight: hasCaption ? Radius.zero : bubble.bottomRight,
  );
}

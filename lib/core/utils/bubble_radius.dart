import 'package:flutter/widgets.dart';

import '../config/app_bubble_behavior.dart';
import '../config/app_bubble_shape.dart';

const double kBubbleBigRadius = 20;
const double kBubbleSmallRadius = 4;

const Radius _big = Radius.circular(kBubbleBigRadius);
const Radius _small = Radius.circular(kBubbleSmallRadius);

BorderRadius computeBubbleRadius({
  required bool isMe,
  required bool isTop,
  required bool isBottom,
  required BubbleStyle style,
  required BubbleBehavior behavior,
  bool hasPhotoWithCaption = false,
  bool hasMultiplePhotosNoCaption = false,
}) {
  final isSingle = isTop && isBottom;

  if (hasPhotoWithCaption && (isTop || isBottom)) {
    return BorderRadius.only(
      topLeft: _big,
      topRight: _big,
      bottomLeft: isMe ? _big : _small,
      bottomRight: _small,
    );
  }

  if (hasMultiplePhotosNoCaption && isBottom) {
    return BorderRadius.only(
      topLeft: isMe ? _big : _small,
      topRight: _small,
      bottomLeft: isMe ? _big : _small,
      bottomRight: isMe ? _small : _big,
    );
  }

  final base = style == BubbleStyle.desktop ? _small : _big;
  Radius tl = base, tr = base, bl = base, br = base;

  if (behavior == BubbleBehavior.immutable || isSingle) {
    return BorderRadius.only(
      topLeft: tl,
      topRight: tr,
      bottomLeft: bl,
      bottomRight: br,
    );
  }

  if (isTop) {
    if (isMe) {
      br = _small;
    } else {
      bl = _small;
    }
  } else if (isBottom) {
    if (isMe) {
      tr = _small;
    } else {
      tl = _small;
    }
  } else {
    if (isMe) {
      tr = _small;
      br = _small;
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

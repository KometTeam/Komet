import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// #***! размеры баблов на iOS, остальные платформы на прежних значениях
abstract final class IosBubbleMetrics {
  static const double compactWidthBoundary = 500;
  static const double compactInset = 36;
  static const double freeFillFactor = 0.85;
  static const double edgeInset = 3;
  static const double contentInsets = 6;
  static const double avatarSize = 34;
  static const double avatarGap = 4;
  static const double avatarInset = avatarSize + avatarGap;

  // #***! фото и альбомы внутри бабла: отступ 2, не больше 300×380,
  // #***! плитки альбома через 1 pt
  static const double mediaInset = 2;
  static const double mediaMaxWidth = 300;
  static const double mediaMaxHeight = 380;
  static const double mediaMinWidth = 170;
  static const double mediaMinHeight = 74;
  static const double mediaStatusInset = 6;
  static const EdgeInsets captionPadding = EdgeInsets.fromLTRB(11, 6, 11, 8);
  static const double albumSpacing = 1;
  static const double albumOrderPenalty = 1.5;

  static double mediaWidthLimit(double listWidth, {required bool avatarSlot}) =>
      math.min(
        mediaMaxWidth,
        maxBubbleWidth(listWidth, avatarSlot: avatarSlot) - mediaInset * 2,
      );

  static Size mediaSize(int? width, int? height, {required double maxWidth}) {
    final w = (width ?? 0) > 0 ? width!.toDouble() : 256.0;
    final h = (height ?? 0) > 0 ? height!.toDouble() : 256.0;
    final scale = math.min(1.0, math.min(maxWidth / w, mediaMaxHeight / h));
    final fitted = math.max(mediaMinWidth, w * scale).clamp(1.0, maxWidth);
    final fittedHeight = (fitted * h / w).clamp(mediaMinHeight, mediaMaxHeight);
    return Size(fitted.toDouble(), fittedHeight.toDouble());
  }

  static BorderRadius innerRadius(
    BorderRadius outer, {
    bool flatTop = false,
    bool flatBottom = false,
  }) {
    Radius shrink(Radius r) => Radius.circular(math.max(0, r.x - mediaInset));
    return BorderRadius.only(
      topLeft: flatTop ? Radius.zero : shrink(outer.topLeft),
      topRight: flatTop ? Radius.zero : shrink(outer.topRight),
      bottomLeft: flatBottom ? Radius.zero : shrink(outer.bottomLeft),
      bottomRight: flatBottom ? Radius.zero : shrink(outer.bottomRight),
    );
  }

  // #***! на телефоне ширина списка минус 36, шире 500 — 0,85 списка,
  // #***! дальше вычитаем отступы и место под аватар в группах
  static double maxBubbleWidth(double listWidth, {required bool avatarSlot}) {
    final fill = listWidth <= compactWidthBoundary
        ? listWidth - compactInset
        : (listWidth * freeFillFactor).floorToDouble();
    final width =
        fill - edgeInset * 3 - contentInsets - (avatarSlot ? avatarInset : 0);
    return math.max(1, width);
  }
}

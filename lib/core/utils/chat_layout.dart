import 'dart:math' as math;

/// Shared chat geometry: bubble share, media frames, wide-pane column.
class ChatLayout {
  static const double bubbleWidthShare = 0.80;
  static const double bubbleHardCap = 560.0;
  static const double columnMaxWidth = 740.0;
  static const double widePaneBreakpoint = 720.0;
  static const double narrowMediaFillShare = 0.72;

  static double maxBubbleWidth(double paneWidth) {
    final column = paneWidth > widePaneBreakpoint
        ? math.min(paneWidth, columnMaxWidth)
        : paneWidth;
    return math.min(column * bubbleWidthShare, bubbleHardCap);
  }

  /// Horizontal inset that centers a [columnMaxWidth] thread in a wide pane.
  static double horizontalInset(double paneWidth) {
    if (paneWidth <= widePaneBreakpoint) return 0;
    return math.max(0.0, (paneWidth - columnMaxWidth) / 2);
  }

  static bool isNarrowMedia(double width, double height) {
    if (width <= 0 || height <= 0) return false;
    return width / height < 0.95;
  }
}

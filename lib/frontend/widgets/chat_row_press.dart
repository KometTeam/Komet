import 'package:flutter/material.dart';

import '../../core/config/ios_release.dart';
import 'springy_tap.dart';

/// Press feedback for a row in the chat list.
///
/// On iOS the row does not scale: a pressed row gets a flat highlight, as
/// table cells do in UIKit, and a scroll that starts on the row cancels
/// the press before the highlight shows. Other platforms keep the springy
/// scale with the Material ripple.
class ChatRowPress extends StatelessWidget {
  const ChatRowPress({
    super.key,
    required this.onTap,
    this.onLongPress,
    required this.child,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ios = IosRelease.isIOS;
    final ink = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashFactory: ios ? NoSplash.splashFactory : null,
      highlightColor: ios
          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
          : null,
      child: child,
    );
    if (ios) return ink;
    return SpringyTap(child: ink);
  }
}

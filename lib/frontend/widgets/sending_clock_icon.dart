import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/config/app_animations.dart';

class SendingClockIcon extends StatelessWidget {
  final Color color;
  final double size;

  const SendingClockIcon({super.key, required this.color, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Lottie.asset(
        AppAnimations.clock,
        repeat: true,
        fit: BoxFit.contain,
        delegates: LottieDelegates(
          values: [
            ValueDelegate.color(const ['**'], value: color),
            ValueDelegate.strokeColor(const ['**'], value: color),
          ],
        ),
      ),
    );
  }
}

bool isSendingStatus(String? status) =>
    status == 'sending' || status == 'pending';

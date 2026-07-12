import 'dart:math';

import 'package:flutter/material.dart';

class ChatShimmerTile extends StatelessWidget {
  const ChatShimmerTile({super.key, required this.shimmer});

  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) {
        final opacity = 0.3 + 0.3 * sin(shimmer.value * pi * 2);
        return Opacity(opacity: opacity, child: child);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FolderStripShimmer extends StatelessWidget {
  const FolderStripShimmer({super.key, required this.shimmer});

  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) {
        final opacity = 0.3 + 0.3 * sin(shimmer.value * pi * 2);
        return Opacity(
          opacity: opacity,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            physics: const BouncingScrollPhysics(),
            children: [
              _pill(cs, 88),
              const SizedBox(width: 8),
              _pill(cs, 72),
              const SizedBox(width: 8),
              _pill(cs, 96),
              const SizedBox(width: 8),
              _pill(cs, 64),
              const SizedBox(width: 8),
              _pill(cs, 80),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(ColorScheme cs, double width) {
    return Container(
      width: width,
      height: 32,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

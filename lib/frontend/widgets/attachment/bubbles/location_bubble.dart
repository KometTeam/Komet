import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/link_opener.dart';
import '../../../../models/attachment.dart';
import 'bubble_context.dart';

class LocationBubble extends StatelessWidget {
  final BubbleContext ctx;
  final LocationAttachment location;

  const LocationBubble({super.key, required this.ctx, required this.location});

  @override
  Widget build(BuildContext context) {
    final isMe = ctx.isMe;
    final lat = location.latitude;
    final lon = location.longitude;
    final coords = lat != null && lon != null
        ? '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: lat == null || lon == null
                  ? null
                  : () {
                      Haptics.tap();
                      openLocationOnMap(
                        ctx.context,
                        lat,
                        lon,
                        zoom: location.zoom,
                      );
                    },
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe
                      ? ctx.cs.onPrimaryContainer.withValues(alpha: 0.08)
                      : ctx.cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isMe ? ctx.systemTint : ctx.cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Symbols.location_on,
                        color: isMe
                            ? ctx.cs.onPrimaryContainer
                            : ctx.cs.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            location.title ?? 'Геопозиция',
                            style: TextStyle(
                              color: ctx.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            location.address ?? coords ?? 'Открыть на карте',
                            style: TextStyle(color: ctx.dim, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ctx.meta(),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../backend/modules/messages.dart' show ContactCache;
import '../../core/cache/official_options.dart';
import 'verified_mark.dart';

class SenderBadge extends StatefulWidget {
  final int senderId;
  final double size;

  const SenderBadge({super.key, required this.senderId, this.size = 14});

  @override
  State<SenderBadge> createState() => _SenderBadgeState();
}

class _SenderBadgeState extends State<SenderBadge> {
  @override
  void initState() {
    super.initState();
    OfficialOptions.request(widget.senderId);
  }

  @override
  void didUpdateWidget(SenderBadge old) {
    super.didUpdateWidget(old);
    if (old.senderId != widget.senderId) {
      OfficialOptions.request(widget.senderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ContactCache.officialRevision,
      builder: (context, _, _) {
        if (!ContactCache.isOfficial(widget.senderId)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: VerifiedMark(size: widget.size),
        );
      },
    );
  }
}

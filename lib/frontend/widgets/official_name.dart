import 'package:flutter/material.dart';

import '../../backend/modules/messages.dart' show ContactCache;
import '../../core/cache/official_options.dart';
import 'verified_mark.dart';

class OfficialName extends StatefulWidget {
  final int contactId;
  final String text;
  final TextStyle? style;
  final int maxLines;
  final double iconSize;
  final TextAlign? textAlign;

  const OfficialName({
    super.key,
    required this.contactId,
    required this.text,
    this.style,
    this.maxLines = 1,
    this.iconSize = 15,
    this.textAlign,
  });

  @override
  State<OfficialName> createState() => _OfficialNameState();
}

class _OfficialNameState extends State<OfficialName> {
  @override
  void initState() {
    super.initState();
    OfficialOptions.request(widget.contactId);
  }

  @override
  void didUpdateWidget(OfficialName old) {
    super.didUpdateWidget(old);
    if (old.contactId != widget.contactId) {
      OfficialOptions.request(widget.contactId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ContactCache.officialRevision,
      builder: (context, _, _) {
        final text = Text(
          widget.text,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: widget.textAlign,
          style: widget.style,
        );
        if (!ContactCache.isOfficial(widget.contactId)) return text;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: text),
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: VerifiedMark(size: widget.iconSize),
            ),
          ],
        );
      },
    );
  }
}

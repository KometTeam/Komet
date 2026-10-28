import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/upload_bytes.dart';

class UploadBytesLabel extends StatelessWidget {
  final ValueListenable<List<UploadBytes>> progress;
  final int slot;

  const UploadBytesLabel({super.key, required this.progress, this.slot = 0});

  static const TextStyle _style = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<List<UploadBytes>>(
      valueListenable: progress,
      builder: (context, values, _) {
        final bytes = slot < values.length ? values[slot] : UploadBytes.none;
        if (!bytes.sized) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '${formatBytes(l10n, bytes.sent)} / '
                  '${formatBytes(l10n, bytes.total)}',
                  maxLines: 1,
                  style: _style,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

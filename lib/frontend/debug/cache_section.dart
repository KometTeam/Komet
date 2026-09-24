import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/format.dart';
import '../widgets/small_spinner.dart';
import 'dev_menu_widgets.dart';

class DebugCacheSection extends StatelessWidget {
  final int cacheSize;
  final bool clearingCache;
  final String cacheLimitLabel;
  final VoidCallback onPickCacheLimit;
  final VoidCallback onClearCache;

  const DebugCacheSection({
    super.key,
    required this.cacheSize,
    required this.clearingCache,
    required this.cacheLimitLabel,
    required this.onPickCacheLimit,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DevGroup(
      children: [
        DevRow(
          caption: 'Лимит кэша медиа',
          title: cacheLimitLabel,
          onTap: onPickCacheLimit,
          trailing: Icon(Symbols.chevron_right, color: cs.outline, size: 20),
        ),
        DevRow(
          caption: clearingCache
              ? 'Очистка…'
              : 'Занято: ${formatBytes(cacheSize)}',
          title: 'Очистить кэш медиа',
          onTap: clearingCache ? null : onClearCache,
          trailing: clearingCache
              ? SmallSpinner(size: 20, color: cs.onSurfaceVariant)
              : null,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/format.dart';
import '../widgets/small_spinner.dart';

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onPickCacheLimit,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.data_usage,
                      color: cs.onSurfaceVariant,
                      size: 22,
                      weight: 400,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Лимит кэша медиа',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cacheLimitLabel,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Symbols.chevron_right,
                      color: cs.onSurfaceVariant,
                      size: 22,
                      weight: 400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: clearingCache ? null : onClearCache,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.delete_sweep,
                      color: cs.onSurfaceVariant,
                      size: 22,
                      weight: 400,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Очистить кэш медиа',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            clearingCache
                                ? 'Очистка…'
                                : 'Занято: ${formatBytes(cacheSize)}',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (clearingCache)
                      SmallSpinner(size: 20, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_shape.dart';
import '../widgets/custom_notification.dart';
import '../widgets/glossy_pill.dart';
import 'performance_monitor.dart';

class DebugPerformanceSection extends StatefulWidget {
  const DebugPerformanceSection({super.key});

  @override
  State<DebugPerformanceSection> createState() =>
      _DebugPerformanceSectionState();
}

class _DebugPerformanceSectionState extends State<DebugPerformanceSection> {
  Timer? _refreshTimer;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _toggle() {
    final monitor = PerformanceMonitor.instance;
    setState(() {
      if (monitor.isActive) {
        monitor.stop();
        _refreshTimer?.cancel();
        _refreshTimer = null;
      } else {
        monitor.start();
        _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (
          _,
        ) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  void _clear() {
    setState(() => PerformanceMonitor.instance.clear());
  }

  Future<void> _copyLog() async {
    final log = PerformanceMonitor.instance.exportLog();
    await Clipboard.setData(ClipboardData(text: log));
    if (!mounted) return;
    showCustomNotification(
      context,
      'Лог скопирован (${PerformanceMonitor.instance.sampleCount} сэмплов)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monitor = PerformanceMonitor.instance;
    final stats = monitor.statsForLast(const Duration(seconds: 5));

    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Мониторинг производительности (APM)',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Захватывает build/raster время каждого кадра через '
            'SchedulerBinding.addTimingsCallback — живой FPS/джанк без '
            'внешних инструментов. Включи, повзаимодействуй с приложением '
            '(скролл, ресайз), потом скопируй лог.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _toggle,
                style: FilledButton.styleFrom(shape: AppShape.buttonBorder),
                child: Text(monitor.isActive ? 'Стоп' : 'Начать'),
              ),
              OutlinedButton(
                onPressed: monitor.sampleCount == 0 ? null : _clear,
                style: OutlinedButton.styleFrom(shape: AppShape.buttonBorder),
                child: const Text('Очистить'),
              ),
              OutlinedButton(
                onPressed: monitor.sampleCount == 0 ? null : _copyLog,
                style: OutlinedButton.styleFrom(shape: AppShape.buttonBorder),
                child: const Text('Скопировать лог'),
              ),
            ],
          ),
          if (monitor.sampleCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statRow(cs, 'FPS (5с)', stats.fps.toStringAsFixed(0)),
                  _statRow(
                    cs,
                    'Средний кадр (5с)',
                    '${stats.avgMs.toStringAsFixed(1)} мс',
                  ),
                  _statRow(
                    cs,
                    'Худший кадр (5с)',
                    '${stats.worstMs.toStringAsFixed(1)} мс',
                  ),
                  _statRow(cs, 'Сэмплов всего', '${monitor.sampleCount}'),
                  _statRow(
                    cs,
                    'Джанк (>16.7мс)',
                    '${monitor.jankCount}',
                    warn: monitor.jankCount > 0,
                  ),
                  _statRow(
                    cs,
                    'Сильный джанк (>32мс)',
                    '${monitor.bigJankCount}',
                    warn: monitor.bigJankCount > 0,
                  ),
                ],
              ),
            ),
            if (monitor.worstContexts().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Что грузит кадры больше всего',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final e in monitor.worstContexts(top: 5))
                      _statRow(
                        cs,
                        e.key,
                        '${e.value.toStringAsFixed(0)} мс сверх бюджета',
                        warn: true,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statRow(ColorScheme cs, String label, String value, {bool warn = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: warn ? cs.error : cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

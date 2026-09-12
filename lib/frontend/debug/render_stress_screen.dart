import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/custom_notification.dart';
import 'performance_monitor.dart';

// #***! автоматический рендер-стресс-тест: рисует N "пузырей" похожей на
// реальные сообщения сложности (реакции, IntrinsicWidth) и сам гоняет
// скролл вверх-вниз, снимая FrameTiming — воспроизводимый бенчмарк вместо
// ручного "потыкать и оценить на глаз"
class RenderStressScreen extends StatefulWidget {
  final int itemCount;
  final Duration duration;

  const RenderStressScreen({
    super.key,
    this.itemCount = 400,
    this.duration = const Duration(seconds: 8),
  });

  @override
  State<RenderStressScreen> createState() => _RenderStressScreenState();
}

class _RenderStressScreenState extends State<RenderStressScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  bool _running = true;
  bool _done = false;
  PerfStats? _report;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runTest());
  }

  Future<void> _runTest() async {
    PerformanceMonitor.instance.clear();
    PerformanceMonitor.instance.start();
    final stopwatch = Stopwatch()..start();
    final maxExtentGuess = widget.itemCount * 90.0;

    while (mounted && stopwatch.elapsed < widget.duration) {
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 16));
        continue;
      }
      final target =
          (math.Random().nextDouble() * maxExtentGuess).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
    }

    PerformanceMonitor.instance.stop();
    if (!mounted) return;
    setState(() {
      _running = false;
      _done = true;
      _report = PerformanceMonitor.instance.statsAll();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copyReport() async {
    final log = PerformanceMonitor.instance.exportLog();
    await Clipboard.setData(ClipboardData(text: log));
    if (!mounted) return;
    showCustomNotification(context, 'Отчёт скопирован');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          _running
              ? 'Рендер-стресс-тест: идёт...'
              : 'Рендер-стресс-тест: готово',
        ),
      ),
      body: Column(
        children: [
          if (_done && _report != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.itemCount} элементов, ${widget.duration.inSeconds}с автоскролла',
                    style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Средний кадр: ${_report!.avgMs.toStringAsFixed(1)}мс  '
                    'Худший: ${_report!.worstMs.toStringAsFixed(1)}мс  '
                    'Сэмплов: ${_report!.sampleCount}\n'
                    'Джанк (>16.7мс): ${PerformanceMonitor.instance.jankCount}  '
                    'Сильный (>32мс): ${PerformanceMonitor.instance.bigJankCount}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _copyReport,
                        child: const Text('Скопировать отчёт'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Закрыть'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.itemCount,
              itemBuilder: (context, index) => _StressBubble(index: index),
            ),
          ),
        ],
      ),
    );
  }
}

class _StressBubble extends StatelessWidget {
  final int index;

  const _StressBubble({required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMe = index.isEven;
    final text =
        'Синтетическое сообщение №$index для стресс-теста рендера, '
        'достаточно длинное, чтобы форсировать перенос и intrinsic-лэйаут '
        'реакций под ним.';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: IntrinsicWidth(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isMe ? cs.primaryContainer : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: TextStyle(color: cs.onSurface)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final emoji in const ['👍', '❤️', '🔥'])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

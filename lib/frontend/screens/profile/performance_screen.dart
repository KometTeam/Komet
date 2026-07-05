import 'package:flutter/material.dart';
import '../../widgets/connection_status.dart';

import '../../../core/config/app_cache_extent.dart';
import '../../../core/utils/haptics.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/glossy_pill.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  late double _value;
  late double _preZoneValue;
  bool _lowWarnDismissed = false;
  bool _highWarnDismissed = false;

  @override
  void initState() {
    super.initState();
    _value = AppCacheExtent.current.value;
    _preZoneValue = _value;
  }

  bool _isInSafeZone(double v) =>
      v >= AppCacheExtent.lowWarnThreshold &&
      v < AppCacheExtent.highWarnThreshold;

  void _onChanged(double v) {
    setState(() {
      _value = v;
      if (_isInSafeZone(v)) _preZoneValue = v;
    });
  }

  Future<void> _onChangeEnd(double v) async {
    Haptics.selection();
    final inLow = v < AppCacheExtent.lowWarnThreshold;
    final inHigh = v >= AppCacheExtent.highWarnThreshold;

    if (inLow && !_lowWarnDismissed) {
      final ok = await _showWarning(
        text: 'Производительность приложения может снизиться, вы уверены?',
      );
      if (ok) {
        _lowWarnDismissed = true;
        await AppCacheExtent.save(v);
      } else {
        if (!mounted) return;
        setState(() => _value = _preZoneValue);
        await AppCacheExtent.save(_preZoneValue);
      }
      return;
    }

    if (inHigh && !_highWarnDismissed) {
      final ok = await _showWarning(
        text:
            'Это врядли даст хотя-бы немного заметный прирост к FPS, '
            'но может потреблять больше памяти. Вы уверены?',
      );
      if (ok) {
        _highWarnDismissed = true;
        await AppCacheExtent.save(v);
      } else {
        if (!mounted) return;
        setState(() => _value = _preZoneValue);
        await AppCacheExtent.save(_preZoneValue);
      }
      return;
    }

    await AppCacheExtent.save(v);
  }

  Future<bool> _showWarning({required String text}) {
    return showConfirmDialog(
      context,
      message: text,
      confirmLabel: 'Да',
      cancelLabel: 'Нет',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hint = cs.onSurfaceVariant;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: 'Производительность',
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            GlossyPill(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              depth: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Кеш сообщений',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Сколько пикселей сообщений держать построенными за пределами видимой области.',
                    style: TextStyle(color: hint, fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Текущий cacheExtent: ${_value.round()}',
                    style: TextStyle(color: hint, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Slider(
                    value: _value,
                    min: AppCacheExtent.min,
                    max: AppCacheExtent.max,
                    onChanged: _onChanged,
                    onChangeEnd: _onChangeEnd,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Меньше потребление',
                        style: TextStyle(color: hint, fontSize: 11),
                      ),
                      Text(
                        'Больше FPS',
                        style: TextStyle(color: hint, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

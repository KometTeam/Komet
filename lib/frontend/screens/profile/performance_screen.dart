import 'package:flutter/material.dart';
import '../../widgets/connection_status.dart';

import '../../../core/config/app_cache_extent.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/settings_card.dart';

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
        text: AppLocalizations.of(context)!.performanceScreenLowWarning,
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
        text: AppLocalizations.of(context)!.performanceScreenHighWarning,
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
    final l10n = AppLocalizations.of(context)!;
    return showConfirmDialog(
      context,
      message: text,
      confirmLabel: l10n.chatInfoConfirmYes,
      cancelLabel: l10n.chatInfoConfirmNo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hint = cs.onSurfaceVariant;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.performanceScreenTitle,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            SettingsPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.performanceScreenCacheTitle,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.performanceScreenCacheSubtitle,
                    style: TextStyle(color: hint, fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.performanceScreenCurrentExtent(_value.round()),
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
                        l10n.performanceScreenLessUsage,
                        style: TextStyle(color: hint, fontSize: 11),
                      ),
                      Text(
                        l10n.performanceScreenMoreFps,
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

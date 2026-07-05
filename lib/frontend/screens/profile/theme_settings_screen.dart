import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/app_amoled.dart';
import '../../../core/config/app_theme_mode.dart';
import '../../../core/config/app_theme_schedule.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/settings_radio_tile.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.themeSettingsTitle,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: const [
            _ThemeModeCard(),
            SizedBox(height: 12),
            _AmoledCard(),
            SizedBox(height: 12),
            _ScheduleCard(),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard();

  static const _items = [
    (mode: AppThemeMode.system, icon: Symbols.brightness_auto),
    (mode: AppThemeMode.light, icon: Symbols.light_mode),
    (mode: AppThemeMode.dark, icon: Symbols.dark_mode),
    (mode: AppThemeMode.schedule, icon: Symbols.schedule),
  ];

  String _labelFor(AppLocalizations l10n, AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return l10n.themeSettingsModeSystem;
      case AppThemeMode.light:
        return l10n.themeSettingsModeLight;
      case AppThemeMode.dark:
        return l10n.themeSettingsModeDark;
      case AppThemeMode.schedule:
        return l10n.themeSettingsModeSchedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.themeSettingsModeCardTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.themeSettingsModeCardSubtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<AppThemeMode>(
            valueListenable: AppThemeModeConfig.current,
            builder: (context, current, _) {
              return Column(
                children: [
                  for (final item in _items)
                    _ModeTile(
                      icon: item.icon,
                      label: _labelFor(l10n, item.mode),
                      selected: current == item.mode,
                      onTap: (position) {
                        if (current == item.mode) return;
                        Haptics.selection();
                        KometApp.stateOf(
                          context,
                        )?.applyThemeModeWithReveal(item.mode, position);
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<Offset> onTap;

  const _ModeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ModeTile> createState() => _ModeTileState();
}

class _ModeTileState extends State<_ModeTile> {
  Offset _lastTapPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SettingsRadioTile(
      leading: Icon(widget.icon, color: cs.onSurface, size: 22, weight: 500),
      label: widget.label,
      selected: widget.selected,
      onTapDown: (d) => _lastTapPosition = d.globalPosition,
      onTap: () => widget.onTap(_lastTapPosition),
    );
  }
}

class _AmoledCard extends StatefulWidget {
  const _AmoledCard();

  @override
  State<_AmoledCard> createState() => _AmoledCardState();
}

class _AmoledCardState extends State<_AmoledCard> {
  Offset _lastPointerPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _lastPointerPosition = e.position,
      child: GlossyPill(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        depth: 6,
        child: Row(
          children: [
            Icon(Symbols.contrast, color: cs.onSurface, size: 24, weight: 500),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.themeSettingsAmoledTitle,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.themeSettingsAmoledSubtitle,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: AppAmoled.current,
              builder: (context, value, _) {
                return Switch(
                  value: value,
                  onChanged: (v) {
                    Haptics.selection();
                    KometApp.stateOf(
                      context,
                    )?.applyAmoledWithReveal(v, _lastPointerPosition);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: AppThemeModeConfig.current,
      builder: (context, mode, _) {
        final enabled = mode == AppThemeMode.schedule;
        return AnimatedOpacity(
          opacity: enabled ? 1 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: GlossyPill(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            depth: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.themeSettingsScheduleTitle,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enabled
                      ? l10n.themeSettingsScheduleSubtitleEnabled
                      : l10n.themeSettingsScheduleSubtitleDisabled,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<ThemeSchedule>(
                  valueListenable: AppThemeSchedule.current,
                  builder: (context, schedule, _) {
                    return Column(
                      children: [
                        _TimeRow(
                          icon: Symbols.bedtime,
                          label: l10n.themeSettingsScheduleDarkFrom,
                          time: schedule.darkStart,
                          enabled: enabled,
                          onPick: (picked) {
                            KometApp.stateOf(context)?.applyThemeSchedule(
                              ThemeSchedule(
                                darkStart: picked,
                                darkEnd: schedule.darkEnd,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _TimeRow(
                          icon: Symbols.wb_sunny,
                          label: l10n.themeSettingsScheduleLightFrom,
                          time: schedule.darkEnd,
                          enabled: enabled,
                          onPick: (picked) {
                            KometApp.stateOf(context)?.applyThemeSchedule(
                              ThemeSchedule(
                                darkStart: schedule.darkStart,
                                darkEnd: picked,
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final TimeOfDay time;
  final bool enabled;
  final ValueChanged<TimeOfDay> onPick;

  const _TimeRow({
    required this.icon,
    required this.label,
    required this.time,
    required this.enabled,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlossyPill(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      depth: 6,
      onTap: enabled ? () => _pick(context) : null,
      child: Row(
        children: [
          Icon(icon, color: cs.onSurface, size: 22, weight: 500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            AppThemeSchedule.format(time),
            style: TextStyle(
              color: cs.primary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    Haptics.tap();
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) onPick(picked);
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/app_amoled.dart';
import '../../../core/config/app_theme_mode.dart';
import '../../../core/config/app_theme_schedule.dart';
import '../../../core/config/app_wallpaper_tint.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/chat_wallpaper_store.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/mesh_gradient_background.dart';
import '../../widgets/settings_radio_tile.dart';
import '../../widgets/settings_card.dart';
import 'custom_gradient_editor_screen.dart';

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

class _ThemeModeCard extends StatefulWidget {
  const _ThemeModeCard();

  @override
  State<_ThemeModeCard> createState() => _ThemeModeCardState();
}

class _ThemeModeCardState extends State<_ThemeModeCard> {
  static const _items = [
    (mode: AppThemeMode.system, icon: Symbols.brightness_auto),
    (mode: AppThemeMode.light, icon: Symbols.light_mode),
    (mode: AppThemeMode.dark, icon: Symbols.dark_mode),
    (mode: AppThemeMode.schedule, icon: Symbols.schedule),
  ];

  int _accountId = 0;
  ChatWallpaper? _wallpaper;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await ChatWallpaperStore.instance.load();
    final profile = await AppDatabase.loadActiveProfile();
    if (!mounted) return;
    setState(() {
      _accountId = profile?.id ?? 0;
      final wallpaper = ChatWallpaperStore.instance.get(
        _accountId,
        kGlobalWallpaperChatId,
      );
      _wallpaper = wallpaper?.isGradient == true ? wallpaper : null;
      _ready = true;
    });
  }

  Future<void> _enableCustom() async {
    Haptics.selection();
    if (_wallpaper == null && _accountId != 0) {
      final wallpaper = await ChatWallpaperStore.instance.setGradient(
        _accountId,
        kGlobalWallpaperChatId,
        const [Color(0xFF000000)],
      );
      if (mounted) setState(() => _wallpaper = wallpaper);
    }
    await AppWallpaperTint.save(true);
  }

  Future<void> _openEditor() async {
    if (_accountId == 0) return;
    final result = await Navigator.of(context).push<CustomGradientResult>(
      MaterialPageRoute(
        builder: (_) => CustomGradientEditorScreen(
          initialColors: _wallpaper?.gradientColors,
          initialAnimated: _wallpaper?.gradientAnimated ?? false,
          initialRotation: _wallpaper?.gradientRotation ?? 0,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final wallpaper = await ChatWallpaperStore.instance.setGradient(
      _accountId,
      kGlobalWallpaperChatId,
      result.colors,
      animated: result.animated,
      rotation: result.rotation,
    );
    if (!AppWallpaperTint.current.value) {
      await AppWallpaperTint.save(true);
    }
    if (!mounted) return;
    setState(() => _wallpaper = wallpaper);
  }

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
    final colors = _wallpaper?.gradientColors;
    return SettingsPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
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
          ListenableBuilder(
            listenable: Listenable.merge([
              AppThemeModeConfig.current,
              AppWallpaperTint.current,
            ]),
            builder: (context, _) {
              final current = AppThemeModeConfig.current.value;
              final customSelected = AppWallpaperTint.current.value;
              return Column(
                children: [
                  for (final item in _items)
                    _ModeTile(
                      icon: item.icon,
                      label: _labelFor(l10n, item.mode),
                      selected: !customSelected && current == item.mode,
                      onTap: (position) {
                        if (!customSelected && current == item.mode) return;
                        Haptics.selection();
                        if (customSelected) {
                          unawaited(AppWallpaperTint.save(false));
                        }
                        KometApp.stateOf(
                          context,
                        )?.applyThemeModeWithReveal(item.mode, position);
                      },
                    ),
                  _ModeTile(
                    icon: Symbols.palette,
                    label: l10n.themeSettingsCustomTitle,
                    selected: customSelected,
                    onTap: (_) {
                      if (customSelected) return;
                      unawaited(_enableCustom());
                    },
                  ),
                  if (customSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: SettingsNavTile(
                        isLast: true,
                        onTap: _ready ? _openEditor : null,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: colors != null && colors.isNotEmpty
                                ? MeshGradientBackground(
                                    colors: colors,
                                    animate: false,
                                    rotation: _wallpaper?.gradientRotation ?? 0,
                                  )
                                : ColoredBox(
                                    color: cs.surfaceContainerHighest,
                                    child: Icon(
                                      Symbols.palette,
                                      color: cs.onSurface,
                                      size: 18,
                                    ),
                                  ),
                          ),
                        ),
                        label: 'Настроить',
                      ),
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
      child: SettingsPanel(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
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
          child: SettingsPanel(
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


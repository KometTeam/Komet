import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/cache/cache_janitor.dart';
import '../../../core/config/app_cache_limit.dart';
import '../../../core/config/app_shape.dart';
import '../../../core/whats_new/spotlight_ids.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/route_settle.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/route_probe.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/spotlight.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  late final RouteSettle _routeSettle = RouteSettle(isMounted: () => mounted);
  StorageReport? _report;
  bool _scanFailed = false;
  bool _clearing = false;
  final Set<StorageCategory> _selected = {
    for (final category in StorageCategory.values)
      if (category.evictable) category,
  };
  int _limit = AppCacheLimit.current.value;

  @override
  void initState() {
    super.initState();
    unawaited(_scan());
  }

  @override
  void dispose() {
    _routeSettle.dispose();
    super.dispose();
  }

  static int _presetIndexOf(int limit) {
    const presets = AppCacheLimit.presets;
    final exact = presets.indexOf(limit);
    if (exact != -1) return exact;
    var nearest = 0;
    for (var i = 0; i < presets.length; i++) {
      final preset = presets[i];
      if (preset == AppCacheLimit.unlimited) continue;
      if ((preset - limit).abs() < (presets[nearest] - limit).abs()) {
        nearest = i;
      }
    }
    return nearest;
  }

  Future<void> _scan() async {
    try {
      final report = await CacheJanitor.instance.scan();
      _routeSettle.run(
        () => setState(() {
          _report = report;
          _scanFailed = false;
        }),
      );
    } catch (_) {
      _routeSettle.run(() => setState(() => _scanFailed = true));
    }
  }

  void _toggle(StorageCategory category) {
    Haptics.selection();
    setState(() {
      if (!_selected.remove(category)) _selected.add(category);
    });
  }

  Future<void> _clear() async {
    final report = _report;
    if (report == null || _clearing) return;
    final l10n = AppLocalizations.of(context)!;
    final categories = {
      for (final category in _selected)
        if (report.of(category) > 0) category,
    };
    if (categories.isEmpty) return;
    if (categories.contains(StorageCategory.keptMedia)) {
      final confirmed = await showConfirmDialog(
        context,
        message: l10n.storageClearKeptMessage,
        confirmLabel: l10n.storageClearKeptConfirm,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _clearing = true);
    try {
      final (:freed, :report) = await CacheJanitor.instance.clear(categories);
      if (!mounted) return;
      setState(() {
        _report = report;
        _clearing = false;
      });
      showCustomNotification(
        context,
        l10n.storageCleared(formatBytes(l10n, freed)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _clearing = false);
      showCustomNotification(context, l10n.storageClearFailed);
    }
  }

  void _onLimitChanged(double value) {
    final limit = AppCacheLimit.presets[value.round()];
    if (limit == _limit) return;
    Haptics.selection();
    setState(() => _limit = limit);
  }

  Future<void> _onLimitChangeEnd(double value) async {
    await AppCacheLimit.save(AppCacheLimit.presets[value.round()]);
    final report = await CacheJanitor.instance.trim();
    if (!mounted) return;
    if (report == null) {
      await _scan();
    } else {
      setState(() => _report = report);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return RouteProbe(
      onRoute: _routeSettle.bind,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: ConnectionTitleBar(
          titleText: l10n.storageTitle,
          backgroundColor: cs.surface,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              SpotlightTarget(
                id: SpotlightIds.storageUsage,
                borderRadius: AppShape.cardRadius,
                child: SettingsPanel(child: _buildUsage(context)),
              ),
              const SizedBox(height: 20),
              SectionHeader(
                l10n.storageLimitTitle,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              ),
              SpotlightTarget(
                id: SpotlightIds.storageLimit,
                borderRadius: AppShape.cardRadius,
                child: SettingsPanel(
                  child: _LimitPicker(
                    limit: _limit,
                    index: _presetIndexOf(_limit),
                    onChanged: _onLimitChanged,
                    onChangeEnd: _onLimitChangeEnd,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final report = _report;
    final still = MediaQuery.disableAnimationsOf(context);

    final Widget child;
    if (report != null) {
      child = _UsagePanel(
        key: const ValueKey('usage'),
        report: report,
        selected: _selected,
        clearing: _clearing,
        onToggle: _toggle,
        onClear: _clear,
      );
    } else {
      child = SizedBox(
        key: ValueKey(_scanFailed),
        height: 160,
        child: Center(
          child: _scanFailed
              ? Text(
                  l10n.storageScanFailed,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SmallSpinner(size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      l10n.storageScanning,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    return AnimatedSize(
      duration: still ? Duration.zero : const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : const Duration(milliseconds: 220),
        switchOutCurve: const Threshold(1),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: child,
      ),
    );
  }
}

abstract final class _Motion {
  static const Duration reveal = Duration(milliseconds: 1100);
  static const Duration change = Duration(milliseconds: 480);
  static const Duration collapseGrace = Duration(milliseconds: 80);
  static const Curve curve = Curves.easeOutCubic;
  static const Interval sweep = Interval(0, 0.7, curve: Curves.easeOutCubic);

  static Interval row(int index) {
    final start = (0.18 + index * 0.08).clamp(0.0, 0.7);
    return Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: curve);
  }
}

class _UsagePanel extends StatefulWidget {
  const _UsagePanel({
    super.key,
    required this.report,
    required this.selected,
    required this.clearing,
    required this.onToggle,
    required this.onClear,
  });

  final StorageReport report;
  final Set<StorageCategory> selected;
  final bool clearing;
  final ValueChanged<StorageCategory> onToggle;
  final VoidCallback onClear;

  @override
  State<_UsagePanel> createState() => _UsagePanelState();
}

class _UsagePanelState extends State<_UsagePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: _Motion.reveal,
  );
  late final Animation<double> _sweep = _reveal.drive(
    CurveTween(curve: _Motion.sweep),
  );
  final Map<int, Animation<double>> _entrances = {};
  final Set<StorageCategory> _collapsing = {};
  Timer? _collapseTimer;

  Animation<double> _entrance(int index) => _entrances.putIfAbsent(
    index,
    () => _reveal.drive(CurveTween(curve: _Motion.row(index))),
  );

  @override
  void didUpdateWidget(_UsagePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final gone = [
      for (final category in StorageCategory.values)
        if (oldWidget.report.of(category) > 0 &&
            widget.report.of(category) == 0)
          category,
    ];
    if (gone.isEmpty) return;
    _collapsing.addAll(gone);
    _collapseTimer?.cancel();
    _collapseTimer = Timer(_Motion.change + _Motion.collapseGrace, () {
      if (mounted) setState(_collapsing.clear);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
    } else if (_reveal.isDismissed) {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final report = widget.report;
    final still = MediaQuery.disableAnimationsOf(context);
    final change = still ? Duration.zero : _Motion.change;
    final total = report.total;
    final selectedBytes = widget.selected
        .where((category) => category.clearable)
        .fold(0, (sum, category) => sum + report.of(category));
    final cacheBytes = StorageCategory.values
        .where((category) => category.clearable)
        .fold(0, (sum, category) => sum + report.of(category));

    var shown = 0;
    final rows = <Widget>[
      for (final category in StorageCategory.values)
        if (report.of(category) > 0 || _collapsing.contains(category))
          _RowSlot(
            key: ValueKey(category),
            visible: report.of(category) > 0,
            duration: change,
            entrance: _entrance(report.of(category) > 0 ? shown++ : shown),
            child: _UsageRow(
              category: category,
              bytes: report.of(category),
              total: total,
              duration: still ? Duration.zero : _Motion.reveal,
              selected: widget.selected.contains(category),
              onToggle: category.clearable && !widget.clearing
                  ? () => widget.onToggle(category)
                  : null,
            ),
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CountingBytes(
          bytes: total,
          duration: still ? Duration.zero : _Motion.reveal,
          builder: (context, bytes) => Text(
            formatBytes(l10n, bytes),
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 48,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.storageTotalCaption,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 18),
        _UsageBar(report: report, reveal: _sweep, duration: change),
        const SizedBox(height: 10),
        ...rows,
        const SizedBox(height: 16),
        FilledButton(
          onPressed: selectedBytes > 0 && !widget.clearing
              ? widget.onClear
              : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: widget.clearing
              ? SmallSpinner(size: 20, color: cs.onPrimary)
              : Text(
                  cacheBytes == 0
                      ? l10n.storageEmpty
                      : selectedBytes == 0
                      ? l10n.storageNothingSelected
                      : l10n.storageClear(formatBytes(l10n, selectedBytes)),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

class _CountingBytes extends StatelessWidget {
  const _CountingBytes({
    required this.bytes,
    required this.duration,
    required this.builder,
  });

  final int bytes;
  final Duration duration;
  final Widget Function(BuildContext context, int bytes) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: bytes.toDouble()),
    duration: duration,
    curve: _Motion.curve,
    builder: (context, value, _) => builder(context, value.round()),
  );
}

abstract final class _StoragePalette {
  static const List<Color> _light = [
    Color(0xFF2A78D6),
    Color(0xFFEB6834),
    Color(0xFF1BAF7A),
    Color(0xFFEDA100),
    Color(0xFFE87BA4),
    Color(0xFF008300),
  ];
  static const List<Color> _dark = [
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
  ];

  static Color of(BuildContext context, StorageCategory category) {
    final theme = Theme.of(context);
    if (!category.clearable) return theme.colorScheme.outline;
    final series = theme.brightness == Brightness.dark ? _dark : _light;
    return series[category.index];
  }
}

String _categoryLabel(AppLocalizations l10n, StorageCategory category) =>
    switch (category) {
      StorageCategory.photos => l10n.storageCategoryPhotos,
      StorageCategory.videos => l10n.storageCategoryVideos,
      StorageCategory.files => l10n.storageCategoryFiles,
      StorageCategory.voice => l10n.storageCategoryVoice,
      StorageCategory.stickers => l10n.storageCategoryStickers,
      StorageCategory.keptMedia => l10n.storageCategoryKept,
      StorageCategory.database => l10n.storageCategoryDatabase,
    };

String? _categoryHint(AppLocalizations l10n, StorageCategory category) =>
    switch (category) {
      StorageCategory.keptMedia => l10n.storageCategoryKeptHint,
      StorageCategory.database => l10n.storageCategoryDatabaseHint,
      _ => null,
    };

final Map<(String, int), NumberFormat> _percentFormats = {};

String _shareLabel(BuildContext context, int bytes, int total) {
  final locale = Localizations.localeOf(context).toString();
  final share = total == 0 ? 0.0 : bytes / total;
  final digits = share > 0 && share < 0.01 ? 1 : 0;
  final format = _percentFormats.putIfAbsent((
    locale,
    digits,
  ), () => NumberFormat.percentPattern(locale)..maximumFractionDigits = digits);
  return format.format(share);
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.report,
    required this.reveal,
    required this.duration,
  });

  static const double _height = 8;
  static const double _gap = 2;
  static const double _minPart = 3;

  final StorageReport report;
  final Animation<double> reveal;
  final Duration duration;

  List<double> _widths(double usable, List<int> sizes) {
    final total = report.total;
    if (total == 0) return [for (final _ in sizes) 0];
    final raw = [for (final size in sizes) usable * size / total];
    final visible = [
      for (final w in raw)
        if (w > 0) w,
    ];
    final small = visible.where((w) => w < _minPart).length;
    final largeSum = visible
        .where((w) => w >= _minPart)
        .fold(0.0, (a, b) => a + b);
    final rest = usable - small * _minPart;
    return [
      for (final w in raw)
        if (w <= 0)
          0
        else if (w < _minPart)
          _minPart
        else
          largeSum > 0 ? w / largeSum * rest : w,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = report.total;
    final categories = StorageCategory.values;
    final sizes = [for (final category in categories) report.of(category)];
    final description = [
      for (final category in categories)
        if (report.of(category) > 0)
          '${_categoryLabel(l10n, category)} '
              '${formatBytes(l10n, report.of(category))} '
              '${_shareLabel(context, report.of(category), total)}',
    ].join(', ');

    return Semantics(
      label: description,
      child: ExcludeSemantics(
        child: SizedBox(
          height: _height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final full = constraints.maxWidth;
              final visibleCount = sizes.where((size) => size > 0).length;
              final usable = (full - _gap * (visibleCount - 1).clamp(0, 99))
                  .clamp(0.0, double.infinity);
              final widths = _widths(usable, sizes);
              var seenVisible = false;
              final segments = <Widget>[];
              for (var i = 0; i < categories.length; i++) {
                final visible = widths[i] > 0;
                final leadingGap = visible && seenVisible ? _gap : 0.0;
                if (visible) seenVisible = true;
                segments.add(
                  AnimatedContainer(
                    key: ValueKey(categories[i]),
                    duration: duration,
                    curve: _Motion.curve,
                    width: widths[i],
                    margin: EdgeInsets.only(left: leadingGap),
                    color: _StoragePalette.of(context, categories[i]),
                    child: visible
                        ? Tooltip(
                            message:
                                '${_categoryLabel(l10n, categories[i])} · '
                                '${formatBytes(l10n, sizes[i])} · '
                                '${_shareLabel(context, sizes[i], total)}',
                            child: const SizedBox.expand(),
                          )
                        : null,
                  ),
                );
              }
              return Align(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_height / 2),
                  child: AnimatedBuilder(
                    animation: reveal,
                    builder: (context, child) => Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: reveal.value,
                      child: child,
                    ),
                    child: SizedBox(
                      width: full,
                      height: _height,
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        maxWidth: double.infinity,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: segments,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RowSlot extends StatelessWidget {
  const _RowSlot({
    super.key,
    required this.visible,
    required this.duration,
    required this.entrance,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Animation<double> entrance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: duration,
      sizeCurve: _Motion.curve,
      alignment: Alignment.topCenter,
      crossFadeState: visible
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: FadeTransition(
        opacity: entrance,
        child: SlideTransition(
          position: entrance.drive(
            Tween(begin: const Offset(0, 0.35), end: Offset.zero),
          ),
          child: child,
        ),
      ),
      secondChild: const SizedBox(width: double.infinity),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.category,
    required this.bytes,
    required this.total,
    required this.duration,
    required this.selected,
    required this.onToggle,
  });

  final StorageCategory category;
  final int bytes;
  final int total;
  final Duration duration;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hint = _categoryHint(l10n, category);

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: category.clearable
                  ? Checkbox(
                      value: selected,
                      onChanged: onToggle == null ? null : (_) => onToggle!(),
                    )
                  : Icon(
                      Symbols.lock,
                      size: 20,
                      weight: 400,
                      color: cs.onSurfaceVariant,
                    ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _StoragePalette.of(context, category),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryLabel(l10n, category),
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (hint != null)
                    Text(
                      hint,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _CountingBytes(
              bytes: bytes,
              duration: duration,
              builder: (context, shown) => Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatBytes(l10n, shown),
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _shareLabel(context, shown, total),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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

class _LimitPicker extends StatelessWidget {
  const _LimitPicker({
    required this.limit,
    required this.index,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final int limit;
  final int index;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  static String _label(AppLocalizations l10n, int bytes) =>
      bytes == AppCacheLimit.unlimited
      ? l10n.storageLimitUnlimited
      : formatBytes(l10n, bytes);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    const presets = AppCacheLimit.presets;
    final hint = cs.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _label(l10n, limit),
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Slider(
          value: index.toDouble(),
          max: (presets.length - 1).toDouble(),
          divisions: presets.length - 1,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _label(l10n, presets.first),
              style: TextStyle(color: hint, fontSize: 11),
            ),
            Text(
              _label(l10n, presets.last),
              style: TextStyle(color: hint, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          l10n.storageLimitHint,
          style: TextStyle(color: hint, fontSize: 13, height: 1.35),
        ),
      ],
    );
  }
}

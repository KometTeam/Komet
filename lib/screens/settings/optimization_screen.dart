import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:io' show Platform;

class OptimizationScreen extends StatelessWidget {
  final bool isModal;

  const OptimizationScreen({super.key, this.isModal = false});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = Theme.of(context).colorScheme;

    if (isModal) {
      return buildModalContent(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Оптимизация")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OutlinedSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("Оптимизация", colors),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.speed),
                  title: const Text("Оптимизация"),
                  subtitle: const Text("Включить оптимизацию"),
                  value: theme.optimization,
                  onChanged: (value) => theme.setOptimization(value),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.monitor),
                  title: const Text("Отображать FPS"),
                  subtitle: const Text("Показывать FPS справа сверху"),
                  value: theme.showFpsOverlay,
                  onChanged: (value) => theme.setShowFpsOverlay(value),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildSectionTitle("Статистика ресурсов", colors),
                const SizedBox(height: 8),
                const _ResourceStatsWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildModalContent(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _OutlinedSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Оптимизация", colors),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.speed),
                title: const Text("Оптимизация"),
                subtitle: const Text("Включить оптимизацию"),
                value: theme.optimization,
                onChanged: (value) => theme.setOptimization(value),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.monitor),
                title: const Text("Отображать FPS"),
                subtitle: const Text("Показывать FPS справа сверху"),
                value: theme.showFpsOverlay,
                onChanged: (value) => theme.setShowFpsOverlay(value),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildSectionTitle("Статистика ресурсов", colors),
              const SizedBox(height: 8),
              const _ResourceStatsWidget(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _OutlinedSection extends StatelessWidget {
  final Widget child;
  const _OutlinedSection({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _ResourceStatsWidget extends StatefulWidget {
  const _ResourceStatsWidget();

  @override
  State<_ResourceStatsWidget> createState() => _ResourceStatsWidgetState();
}

class _ResourceStatsWidgetState extends State<_ResourceStatsWidget> {
  final Battery _battery = Battery();
  int? _batteryLevel;
  BatteryState? _batteryState;
  double _fps = 0.0;
  double _avgMs = 0.0;
  final List<FrameTiming> _timings = <FrameTiming>[];
  static const int _sampleSize = 60;

  @override
  void initState() {
    super.initState();
    _loadBatteryInfo();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      if (mounted) {
        setState(() {
          _batteryState = state;
        });
        _loadBatteryInfo();
      }
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  Future<void> _loadBatteryInfo() async {
    if (Platform.isAndroid) {
      try {
        final batteryLevel = await _battery.batteryLevel;
        final batteryState = await _battery.batteryState;
        if (mounted) {
          setState(() {
            _batteryLevel = batteryLevel;
            _batteryState = batteryState;
          });
        }
      } catch (e) {
        
      }
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    _timings.addAll(timings);
    if (_timings.length > _sampleSize) {
      _timings.removeRange(0, _timings.length - _sampleSize);
    }
    if (_timings.isEmpty) return;
    final double avg =
        _timings
            .map((t) => (t.totalSpan.inMicroseconds) / 1000.0)
            .fold(0.0, (a, b) => a + b) /
        _timings.length;
    if (mounted) {
      setState(() {
        _avgMs = avg;
        _fps = avg > 0 ? (1000.0 / avg) : 0.0;
      });
    }
  }

  String _getBatteryStateText() {
    if (_batteryState == null) return 'Неизвестно';
    switch (_batteryState!) {
      case BatteryState.charging:
        return 'Заряжается';
      case BatteryState.discharging:
        return 'Разряжается';
      case BatteryState.full:
        return 'Полностью заряжена';
      default:
        return 'Неизвестно';
    }
  }

  Color _getBatteryColor() {
    if (_batteryLevel == null) return Colors.grey;
    if (_batteryLevel! >= 50) return Colors.green;
    if (_batteryLevel! >= 20) return Colors.orange;
    return Colors.red;
  }

  Color _getFpsColor() {
    if (_fps >= 55) return Colors.green;
    if (_fps >= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (Platform.isAndroid && _batteryLevel != null) ...[
          _StatRow(
            icon: Icons.battery_charging_full,
            label: 'Батарея',
            value: '$_batteryLevel%',
            subtitle: _getBatteryStateText(),
            valueColor: _getBatteryColor(),
          ),
          const SizedBox(height: 12),
        ],
        _StatRow(
          icon: Icons.speed,
          label: 'FPS',
          value: _fps.toStringAsFixed(1),
          subtitle: 'Кадров в секунду',
          valueColor: _getFpsColor(),
        ),
        const SizedBox(height: 12),
        _StatRow(
          icon: Icons.timer_outlined,
          label: 'Время кадра',
          value: '${_avgMs.toStringAsFixed(1)} мс',
          subtitle: 'Среднее время рендеринга',
          valueColor: _avgMs < 16.67 ? Colors.green : (_avgMs < 33.33 ? Colors.orange : Colors.red),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color valueColor;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 24, color: colors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}


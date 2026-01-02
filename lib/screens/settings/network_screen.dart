import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:gwid/api/api_service.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  NetworkStats? _networkStats;
  bool _isLoading = true;
  Timer? _updateTimer;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadNetworkStats();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNetworkStats() async {
    try {
      final stats = await _getNetworkStats();
      setState(() {
        _networkStats = stats;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<NetworkStats> _getNetworkStats() async {
    final stats = await ApiService.instance.getNetworkStatistics();

    final totalDailyTraffic = stats['totalTraffic'] as double;

    final messagesTraffic = stats['messagesTraffic'] as double;
    final mediaTraffic = stats['mediaTraffic'] as double;
    final syncTraffic = stats['syncTraffic'] as double;
    final otherTraffic = stats['otherTraffic'] as double;

    final currentSpeed = stats['currentSpeed'] as double;

    final hourlyData = stats['hourlyStats'] as List<dynamic>;
    final hourlyStats = List.generate(24, (index) {
      if (index < hourlyData.length) {
        return HourlyStats(hour: index, traffic: hourlyData[index] as double);
      }

      final hour = index;
      final isActive = hour >= 8 && hour <= 23;
      final baseTraffic = isActive ? 20.0 * 1024 * 1024 : 2.0 * 1024 * 1024;
      return HourlyStats(hour: hour, traffic: baseTraffic);
    });

    return NetworkStats(
      totalDailyTraffic: totalDailyTraffic,
      messagesTraffic: messagesTraffic,
      mediaTraffic: mediaTraffic,
      syncTraffic: syncTraffic,
      otherTraffic: otherTraffic,
      currentSpeed: currentSpeed,
      hourlyStats: hourlyStats,
      isConnected: stats['isConnected'] as bool,
      connectionType: stats['connectionType'] as String,
      signalStrength: stats['signalStrength'] as int,
      ping: stats['ping'] as int,
      jitter: stats['jitter'] as double,
      packetLoss: stats['packetLoss'] as double,
    );
  }

  void _startMonitoring() {
    if (_isMonitoring) return;

    setState(() {
      _isMonitoring = true;
    });

    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _loadNetworkStats();
    });
  }

  void _stopMonitoring() {
    _updateTimer?.cancel();
    setState(() {
      _isMonitoring = false;
    });
  }

  void _resetStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить статистику'),
        content: const Text(
          'Это действие сбросит всю статистику использования сети. '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _loadNetworkStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Статистика сброшена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    }
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сеть'),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow),
            onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
            tooltip: _isMonitoring
                ? 'Остановить мониторинг'
                : 'Начать мониторинг',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _networkStats == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 64,
                    color: colors.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Не удалось загрузить статистику сети',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadNetworkStats,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectionStatus(colors),

                  const SizedBox(height: 24),

                  _buildNetworkChart(colors),

                  const SizedBox(height: 24),

                  _buildCurrentSpeed(colors),

                  const SizedBox(height: 24),

                  _buildTrafficDetails(colors),

                  const SizedBox(height: 24),

                  _buildHourlyChart(colors),

                  const SizedBox(height: 24),

                  _buildActionButtons(colors),
                ],
              ),
            ),
    );
  }

  Widget _buildConnectionStatus(ColorScheme colors) {
    final stats = _networkStats!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: stats.isConnected
                  ? colors.primary.withValues(alpha: 0.1)
                  : colors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              stats.isConnected ? Icons.wifi : Icons.wifi_off,
              color: stats.isConnected ? colors.primary : colors.error,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.isConnected ? 'Подключено' : 'Отключено',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stats.connectionType,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (stats.isConnected) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.signal_cellular_alt,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${stats.signalStrength}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkChart(ColorScheme colors) {
    final stats = _networkStats!;
    final totalTraffic = stats.totalDailyTraffic;
    final usagePercentage = totalTraffic > 0
        ? (stats.messagesTraffic +
                  stats.mediaTraffic +
                  stats.syncTraffic +
                  stats.otherTraffic) /
              totalTraffic
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Использование сети за день',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surfaceContainerHighest,
                      ),
                    ),

                    CustomPaint(
                      size: const Size(200, 200),
                      painter: NetworkChartPainter(
                        progress: usagePercentage * _animation.value,
                        colors: colors,
                      ),
                    ),

                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatBytes(totalTraffic),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                          Text(
                            'использовано',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                'Медиа',
                _formatBytes(stats.mediaTraffic),
                colors.primary,
              ),
              _buildLegendItem(
                'Сообщения',
                _formatBytes(stats.messagesTraffic),
                colors.secondary,
              ),
              _buildLegendItem(
                'Синхронизация',
                _formatBytes(stats.syncTraffic),
                colors.tertiary,
              ),
              _buildLegendItem(
                'Другое',
                _formatBytes(stats.otherTraffic),
                colors.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              value,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentSpeed(ColorScheme colors) {
    final stats = _networkStats!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Текущая скорость',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _formatSpeed(stats.currentSpeed),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '↓',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficDetails(ColorScheme colors) {
    final stats = _networkStats!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Детали трафика',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          _buildTrafficItem(
            'Медиафайлы',
            _formatBytes(stats.mediaTraffic),
            Icons.photo_library_outlined,
            colors.primary,
            (stats.mediaTraffic / stats.totalDailyTraffic),
          ),

          _buildTrafficItem(
            'Сообщения',
            _formatBytes(stats.messagesTraffic),
            Icons.message_outlined,
            colors.secondary,
            (stats.messagesTraffic / stats.totalDailyTraffic),
          ),

          _buildTrafficItem(
            'Синхронизация',
            _formatBytes(stats.syncTraffic),
            Icons.sync,
            colors.tertiary,
            (stats.syncTraffic / stats.totalDailyTraffic),
          ),

          _buildTrafficItem(
            'Другие данные',
            _formatBytes(stats.otherTraffic),
            Icons.folder_outlined,
            colors.outline,
            (stats.otherTraffic / stats.totalDailyTraffic),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficItem(
    String title,
    String size,
    IconData icon,
    Color color,
    double percentage,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  size,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(ColorScheme colors) {
    final stats = _networkStats!;
    final maxTraffic = stats.hourlyStats
        .map((e) => e.traffic)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Активность по часам',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: stats.hourlyStats.length,
              itemBuilder: (context, index) {
                final hourStats = stats.hourlyStats[index];
                final height = maxTraffic > 0
                    ? (hourStats.traffic / maxTraffic)
                    : 0.0;

                return Container(
                  width: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: height * 100,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${hourStats.hour}',
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Действия',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
                icon: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow),
                label: Text(
                  _isMonitoring ? 'Остановить мониторинг' : 'Начать мониторинг',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _resetStats,
                icon: const Icon(Icons.refresh),
                label: const Text('Сбросить статистику'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class NetworkStats {
  final double totalDailyTraffic;
  final double messagesTraffic;
  final double mediaTraffic;
  final double syncTraffic;
  final double otherTraffic;
  final double currentSpeed;
  final List<HourlyStats> hourlyStats;
  final bool isConnected;
  final String connectionType;
  final int signalStrength;
  final int ping;
  final double jitter;
  final double packetLoss;

  NetworkStats({
    required this.totalDailyTraffic,
    required this.messagesTraffic,
    required this.mediaTraffic,
    required this.syncTraffic,
    required this.otherTraffic,
    required this.currentSpeed,
    required this.hourlyStats,
    required this.isConnected,
    required this.connectionType,
    required this.signalStrength,
    this.ping = 25,
    this.jitter = 2.5,
    this.packetLoss = 0.01,
  });
}

class HourlyStats {
  final int hour;
  final double traffic;

  HourlyStats({required this.hour, required this.traffic});
}

class NetworkChartPainter extends CustomPainter {
  final double progress;
  final ColorScheme colors;

  NetworkChartPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    paint.color = colors.surfaceContainerHighest;
    canvas.drawCircle(center, radius, paint);

    paint.color = colors.primary;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is NetworkChartPainter &&
        oldDelegate.progress != progress;
  }
}

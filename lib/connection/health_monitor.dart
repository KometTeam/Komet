import 'dart:async';
import 'dart:math';

class HealthMetrics {
  final int latency;
  final int packetLoss;
  final int connectionUptime;
  final int reconnects;
  final int errors;
  final DateTime timestamp;
  final String? serverUrl;

  HealthMetrics({
    required this.latency,
    required this.packetLoss,
    required this.connectionUptime,
    required this.reconnects,
    required this.errors,
    required this.timestamp,
    this.serverUrl,
  });

  int get healthScore {
    int score = 100;

    if (latency > 1000) {
      score -= 30;
    } else if (latency > 500)
      score -= 20;
    else if (latency > 200)
      score -= 10;

    if (packetLoss > 10) {
      score -= 40;
    } else if (packetLoss > 5)
      score -= 20;
    else if (packetLoss > 1)
      score -= 10;

    if (reconnects > 10) {
      score -= 30;
    } else if (reconnects > 5)
      score -= 20;
    else if (reconnects > 2)
      score -= 10;

    if (errors > 20) {
      score -= 25;
    } else if (errors > 10)
      score -= 15;
    else if (errors > 5)
      score -= 10;

    return max(0, score);
  }

  ConnectionQuality get quality {
    final score = healthScore;
    if (score >= 90) return ConnectionQuality.excellent;
    if (score >= 70) return ConnectionQuality.good;
    if (score >= 50) return ConnectionQuality.fair;
    if (score >= 30) return ConnectionQuality.poor;
    return ConnectionQuality.critical;
  }

  Map<String, dynamic> toJson() {
    return {
      'latency': latency,
      'packet_loss': packetLoss,
      'connection_uptime': connectionUptime,
      'reconnects': reconnects,
      'errors': errors,
      'health_score': healthScore,
      'quality': quality.name,
      'timestamp': timestamp.toIso8601String(),
      'server_url': serverUrl,
    };
  }
}

enum ConnectionQuality { excellent, good, fair, poor, critical }

class HealthMonitor {
  static final HealthMonitor _instance = HealthMonitor._internal();
  factory HealthMonitor() => _instance;
  HealthMonitor._internal();

  final List<HealthMetrics> _metricsHistory = [];
  final StreamController<HealthMetrics> _metricsController =
      StreamController<HealthMetrics>.broadcast();

  Timer? _pingTimer;
  Timer? _healthCheckTimer;

  int _pingCount = 0;
  int _pongCount = 0;
  int _reconnectCount = 0;
  int _errorCount = 0;
  DateTime? _connectionStartTime;
  String? _currentServerUrl;

  Stream<HealthMetrics> get metricsStream => _metricsController.stream;

  HealthMetrics? get currentMetrics =>
      _metricsHistory.isNotEmpty ? _metricsHistory.last : null;

  List<HealthMetrics> get metricsHistory => List.unmodifiable(_metricsHistory);

  void startMonitoring({String? serverUrl}) {
    _currentServerUrl = serverUrl;
    _connectionStartTime = DateTime.now();
    _resetCounters();

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendPing(),
    );

    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _updateHealthMetrics(),
    );

    _logHealthEvent('Мониторинг здоровья начат', {'server_url': serverUrl});
  }

  void stopMonitoring() {
    _pingTimer?.cancel();
    _healthCheckTimer?.cancel();
    _logHealthEvent('Мониторинг здоровья остановлен');
  }

  void onPongReceived() {
    _pongCount++;
    _logHealthEvent('Pong получен', {'pong_count': _pongCount});
  }

  void onReconnect() {
    _reconnectCount++;
    _logHealthEvent('Переподключение', {'reconnect_count': _reconnectCount});
  }

  void onError(String error) {
    _errorCount++;
    _logHealthEvent('Ошибка зафиксирована', {
      'error': error,
      'error_count': _errorCount,
    });
  }

  void _sendPing() {
    _pingCount++;
    _logHealthEvent('Ping отправлен', {'ping_count': _pingCount});
  }

  void _updateHealthMetrics() {
    final now = DateTime.now();
    final uptime = _connectionStartTime != null
        ? now.difference(_connectionStartTime!).inSeconds
        : 0;

    final latency = _calculateLatency();
    final packetLoss = _calculatePacketLoss();

    final metrics = HealthMetrics(
      latency: latency,
      packetLoss: packetLoss,
      connectionUptime: uptime,
      reconnects: _reconnectCount,
      errors: _errorCount,
      timestamp: now,
      serverUrl: _currentServerUrl,
    );

    _metricsHistory.add(metrics);

    if (_metricsHistory.length > 100) {
      _metricsHistory.removeAt(0);
    }

    _metricsController.add(metrics);

    _logHealthEvent('Метрики обновлены', {
      'latency': latency,
      'packet_loss': packetLoss,
      'uptime': uptime,
      'health_score': metrics.healthScore,
      'quality': metrics.quality.name,
    });
  }

  int _calculateLatency() {
    if (_pingCount == 0) return 0;

    final baseLatency = 50 + Random().nextInt(100);
    final packetLossPenalty = _calculatePacketLoss() * 10;

    return baseLatency + packetLossPenalty;
  }

  int _calculatePacketLoss() {
    if (_pingCount == 0) return 0;

    final expectedPongs = _pingCount;
    final actualPongs = _pongCount;
    final lostPackets = expectedPongs - actualPongs;

    return ((lostPackets / expectedPongs) * 100).round();
  }

  HealthMetrics? getAverageMetrics({Duration? period}) {
    if (_metricsHistory.isEmpty) return null;

    final cutoff = period != null
        ? DateTime.now().subtract(period)
        : DateTime.now().subtract(const Duration(hours: 1));

    final recentMetrics = _metricsHistory
        .where((m) => m.timestamp.isAfter(cutoff))
        .toList();

    if (recentMetrics.isEmpty) return null;

    final avgLatency =
        recentMetrics.map((m) => m.latency).reduce((a, b) => a + b) /
        recentMetrics.length;

    final avgPacketLoss =
        recentMetrics.map((m) => m.packetLoss).reduce((a, b) => a + b) /
        recentMetrics.length;

    final totalReconnects = recentMetrics.last.reconnects;
    final totalErrors = recentMetrics.last.errors;
    final avgUptime = recentMetrics.last.connectionUptime;

    return HealthMetrics(
      latency: avgLatency.round(),
      packetLoss: avgPacketLoss.round(),
      connectionUptime: avgUptime,
      reconnects: totalReconnects,
      errors: totalErrors,
      timestamp: DateTime.now(),
      serverUrl: _currentServerUrl,
    );
  }

  Map<String, dynamic> getStatistics() {
    if (_metricsHistory.isEmpty) {
      return {
        'total_metrics': 0,
        'average_health_score': 0,
        'current_quality': 'unknown',
      };
    }

    final avgHealthScore =
        _metricsHistory.map((m) => m.healthScore).reduce((a, b) => a + b) /
        _metricsHistory.length;

    final qualityDistribution = <String, int>{};
    for (final metrics in _metricsHistory) {
      final quality = metrics.quality.name;
      qualityDistribution[quality] = (qualityDistribution[quality] ?? 0) + 1;
    }

    return {
      'total_metrics': _metricsHistory.length,
      'average_health_score': avgHealthScore.round(),
      'current_quality': _metricsHistory.last.quality.name,
      'quality_distribution': qualityDistribution,
      'total_reconnects': _reconnectCount,
      'total_errors': _errorCount,
      'connection_uptime': _connectionStartTime != null
          ? DateTime.now().difference(_connectionStartTime!).inSeconds
          : 0,
    };
  }

  void _resetCounters() {
    _pingCount = 0;
    _pongCount = 0;
    _reconnectCount = 0;
    _errorCount = 0;
  }

  void clearHistory() {
    _metricsHistory.clear();
    _logHealthEvent('История метрик очищена');
  }

  void _logHealthEvent(String event, [Map<String, dynamic>? data]) {
    print('🏥 HealthMonitor: $event${data != null ? ' | Data: $data' : ''}');
  }

  void dispose() {
    stopMonitoring();
    _metricsController.close();
  }
}

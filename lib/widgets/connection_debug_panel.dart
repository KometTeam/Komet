import 'package:flutter/material.dart';
import 'dart:async';

import '../connection/connection_logger.dart';
import '../connection/connection_state.dart' as conn_state;
import '../connection/health_monitor.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/app_sizes.dart';

class ConnectionDebugPanel extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onClose;

  const ConnectionDebugPanel({super.key, this.isVisible = false, this.onClose});

  @override
  State<ConnectionDebugPanel> createState() => _ConnectionDebugPanelState();
}

class _ConnectionDebugPanelState extends State<ConnectionDebugPanel>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<LogEntry> _logs = [];
  final List<conn_state.ConnectionInfo> _stateHistory = [];
  final List<HealthMetrics> _healthMetrics = [];

  late StreamSubscription<List<LogEntry>> _logsSubscription;
  late StreamSubscription<conn_state.ConnectionInfo> _stateSubscription;
  late StreamSubscription<HealthMetrics> _healthSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    _logsSubscription = Stream.periodic(const Duration(seconds: 1))
        .asyncMap((_) async => ApiService.instance.logs.take(100).toList())
        .listen((logs) {
          if (mounted) {
            setState(() {
              _logs = logs;
            });
          }
        });

    _stateSubscription = ApiService.instance.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _stateHistory.add(state);
          if (_stateHistory.length > 50) {
            _stateHistory.removeAt(0);
          }
        });
      }
    });

    _healthSubscription = ApiService.instance.healthMetrics.listen((health) {
      if (mounted) {
        setState(() {
          _healthMetrics.add(health);
          if (_healthMetrics.length > 50) {
            _healthMetrics.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _logsSubscription.cancel();
    _stateSubscription.cancel();
    _healthSubscription.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.bug_report, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Отладка подключения',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabs: const [
        Tab(text: 'Логи'),
        Tab(text: 'Состояния'),
        Tab(text: 'Здоровье'),
        Tab(text: 'Статистика'),
      ],
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildLogsTab(),
        _buildStatesTab(),
        _buildHealthTab(),
        _buildStatsTab(),
      ],
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        _buildLogsControls(),
        Expanded(child: _buildLogsList()),
      ],
    );
  }

  Widget _buildLogsControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _clearLogs,
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Очистить'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _exportLogs,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Экспорт'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const Spacer(),
          Text(
            'Логов: ${_logs.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    if (_logs.isEmpty) {
      return const Center(child: Text('Нет логов'));
    }

    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(LogEntry log) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getLogColor(log.level).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getLogColor(log.level).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getLogIcon(log.level),
                size: 16,
                color: _getLogColor(log.level),
              ),
              const SizedBox(width: 8),
              Text(
                log.category,
                style: TextStyle(
                  color: _getLogColor(log.level),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(log.timestamp),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(log.message, style: Theme.of(context).textTheme.bodyMedium),
          if (log.data != null) ...[
            const SizedBox(height: 4),
            Text(
              'Data: ${log.data}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
          if (log.error != null) ...[
            const SizedBox(height: 4),
            Text(
              'Error: ${log.error}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.red,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatesTab() {
    return ListView.builder(
      itemCount: _stateHistory.length,
      itemBuilder: (context, index) {
        final state = _stateHistory[index];
        return _buildStateItem(state);
      },
    );
  }

  Widget _buildStateItem(conn_state.ConnectionInfo state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStateColor(state.state).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStateColor(state.state).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStateIcon(state.state),
                size: 16,
                color: _getStateColor(state.state),
              ),
              const SizedBox(width: 8),
              Text(
                _getStateText(state.state),
                style: TextStyle(
                  color: _getStateColor(state.state),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(state.timestamp),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (state.message != null) ...[
            const SizedBox(height: 4),
            Text(state.message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (state.serverUrl != null) ...[
            const SizedBox(height: 4),
            Text(
              'Сервер: ${state.serverUrl}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (state.latency != null) ...[
            const SizedBox(height: 4),
            Text(
              'Задержка: ${state.latency}ms',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthTab() {
    if (_healthMetrics.isEmpty) {
      return const Center(child: Text('Нет данных о здоровье'));
    }

    final latestHealth = _healthMetrics.last;

    return Column(
      children: [
        _buildHealthSummary(latestHealth),
        Expanded(child: _buildHealthChart()),
      ],
    );
  }

  Widget _buildHealthSummary(HealthMetrics health) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getHealthColor(health.quality).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getHealthColor(health.quality).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _getHealthIcon(health.quality),
                size: 24,
                color: _getHealthColor(health.quality),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Здоровье соединения',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${health.healthScore}/100 - ${_getHealthText(health.quality)}',
                    style: TextStyle(
                      color: _getHealthColor(health.quality),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHealthMetric('Задержка', '${health.latency}ms'),
              _buildHealthMetric('Потери', '${health.packetLoss}%'),
              _buildHealthMetric('Переподключения', '${health.reconnects}'),
              _buildHealthMetric('Ошибки', '${health.errors}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildHealthChart() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: const Center(
        child: Text('График здоровья соединения\n(в разработке)'),
      ),
    );
  }

  Widget _buildStatsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService.instance.getStatistics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Ошибка загрузки статистики: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('Нет данных для отображения'));
        }

        final stats = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatsSection('API Service', stats['api_service']),
            const SizedBox(height: 16),
            _buildStatsSection('Connection', stats['connection']),
          ],
        );
      },
    );
  }

  Widget _buildStatsSection(String title, Map<String, dynamic>? data) {
    if (data == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...data.entries.map((entry) => _buildStatsRow(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildStatsRow(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(key, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value.toString(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.blue;
      case LogLevel.info:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.critical:
        return Colors.red.shade800;
    }
  }

  IconData _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.error:
        return Icons.error;
      case LogLevel.critical:
        return Icons.dangerous;
    }
  }

  Color _getStateColor(conn_state.ConnectionState state) {
    switch (state) {
      case conn_state.ConnectionState.ready:
        return Colors.green;
      case conn_state.ConnectionState.connected:
        return Colors.blue;
      case conn_state.ConnectionState.connecting:
      case conn_state.ConnectionState.reconnecting:
        return Colors.orange;
      case conn_state.ConnectionState.error:
        return Colors.red;
      case conn_state.ConnectionState.disconnected:
      case conn_state.ConnectionState.disabled:
        return Colors.grey;
    }
  }

  IconData _getStateIcon(conn_state.ConnectionState state) {
    switch (state) {
      case conn_state.ConnectionState.ready:
        return Icons.check_circle;
      case conn_state.ConnectionState.connected:
        return Icons.link;
      case conn_state.ConnectionState.connecting:
      case conn_state.ConnectionState.reconnecting:
        return Icons.sync;
      case conn_state.ConnectionState.error:
        return Icons.error;
      case conn_state.ConnectionState.disconnected:
      case conn_state.ConnectionState.disabled:
        return Icons.link_off;
    }
  }

  String _getStateText(conn_state.ConnectionState state) {
    switch (state) {
      case conn_state.ConnectionState.ready:
        return 'Готов';
      case conn_state.ConnectionState.connected:
        return 'Подключен';
      case conn_state.ConnectionState.connecting:
        return 'Подключение';
      case conn_state.ConnectionState.reconnecting:
        return 'Переподключение';
      case conn_state.ConnectionState.error:
        return 'Ошибка';
      case conn_state.ConnectionState.disconnected:
        return 'Отключен';
      case conn_state.ConnectionState.disabled:
        return 'Отключен';
    }
  }

  Color _getHealthColor(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Colors.green;
      case ConnectionQuality.good:
        return Colors.lightGreen;
      case ConnectionQuality.fair:
        return Colors.orange;
      case ConnectionQuality.poor:
        return Colors.red;
      case ConnectionQuality.critical:
        return Colors.red.shade800;
    }
  }

  IconData _getHealthIcon(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Icons.signal_cellular_4_bar;
      case ConnectionQuality.good:
        return Icons.signal_cellular_4_bar;
      case ConnectionQuality.fair:
        return Icons.signal_cellular_4_bar;
      case ConnectionQuality.poor:
        return Icons.signal_cellular_0_bar;
      case ConnectionQuality.critical:
        return Icons.signal_cellular_0_bar;
    }
  }

  String _getHealthText(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 'Отлично';
      case ConnectionQuality.good:
        return 'Хорошо';
      case ConnectionQuality.fair:
        return 'Удовлетворительно';
      case ConnectionQuality.poor:
        return 'Плохо';
      case ConnectionQuality.critical:
        return 'Критично';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  void _clearLogs() {
    ConnectionLogger().clearLogs();
    if (mounted) {
      setState(() {
        _logs = [];
      });
    }
  }

  void _exportLogs() {}
}

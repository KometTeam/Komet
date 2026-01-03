import 'package:flutter/material.dart';
import 'dart:async';

import '../connection/connection_state.dart' as conn_state;
import '../connection/health_monitor.dart';
import 'package:gwid/api/api_service.dart';

class ConnectionStatusWidget extends StatefulWidget {
  final bool showDetails;
  final bool showHealthMetrics;
  final VoidCallback? onTap;

  const ConnectionStatusWidget({
    super.key,
    this.showDetails = false,
    this.showHealthMetrics = false,
    this.onTap,
  });

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  late StreamSubscription<conn_state.ConnectionInfo> _stateSubscription;
  late StreamSubscription<HealthMetrics> _healthSubscription;

  conn_state.ConnectionInfo? _currentState;
  HealthMetrics? _currentHealth;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    _stateSubscription = ApiService.instance.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    });

    if (widget.showHealthMetrics) {
      _healthSubscription = ApiService.instance.healthMetrics.listen((health) {
        if (mounted) {
          setState(() {
            _currentHealth = health;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    _healthSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentState == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap ?? _toggleExpanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getStatusColor().withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 8),
                _buildStatusText(),
                if (widget.showDetails) ...[
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: _getStatusColor(),
                  ),
                ],
              ],
            ),
            if (_isExpanded && widget.showDetails) ...[
              const SizedBox(height: 8),
              _buildDetails(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _getStatusColor(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return Text(
      _getStatusText(),
      style: TextStyle(
        color: _getStatusColor(),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentState?.serverUrl != null)
          _buildDetailRow('Сервер', _currentState!.serverUrl!),
        if (_currentState?.latency != null)
          _buildDetailRow('Задержка', '${_currentState!.latency}ms'),
        if (_currentState?.attemptNumber != null)
          _buildDetailRow('Попытка', '${_currentState!.attemptNumber}'),
        if (_currentState?.reconnectDelay != null)
          _buildDetailRow(
            'Переподключение',
            'через ${_currentState!.reconnectDelay!.inSeconds}с',
          ),
        if (_currentHealth != null) ...[
          const SizedBox(height: 4),
          _buildHealthMetrics(),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: _getStatusColor().withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _getStatusColor(),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetrics() {
    if (_currentHealth == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getHealthColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getHealthColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getHealthIcon(), size: 12, color: _getHealthColor()),
              const SizedBox(width: 4),
              Text(
                'Здоровье: ${_currentHealth!.healthScore}/100',
                style: TextStyle(
                  color: _getHealthColor(),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildHealthBar(),
        ],
      ),
    );
  }

  Widget _buildHealthBar() {
    final score = _currentHealth!.healthScore;
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: score / 100,
        child: Container(
          decoration: BoxDecoration(
            color: _getHealthColor(),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_currentState?.state) {
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
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (_currentState?.state) {
      case conn_state.ConnectionState.ready:
        return 'Готов';
      case conn_state.ConnectionState.connected:
        return 'Подключен';
      case conn_state.ConnectionState.connecting:
        return 'Подключение...';
      case conn_state.ConnectionState.reconnecting:
        return 'Переподключение...';
      case conn_state.ConnectionState.error:
        return 'Ошибка';
      case conn_state.ConnectionState.disconnected:
        return 'Отключен';
      case conn_state.ConnectionState.disabled:
        return 'Отключен';
      default:
        return 'Неизвестно';
    }
  }

  Color _getHealthColor() {
    if (_currentHealth == null) return Colors.grey;

    switch (_currentHealth!.quality) {
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

  IconData _getHealthIcon() {
    if (_currentHealth == null) return Icons.help_outline;

    switch (_currentHealth!.quality) {
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

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }
}

class ConnectionIndicator extends StatefulWidget {
  final double size;
  final bool showPulse;

  const ConnectionIndicator({
    super.key,
    this.size = 12.0,
    this.showPulse = true,
  });

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<conn_state.ConnectionInfo>(
      stream: ApiService.instance.connectionState,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final state = snapshot.data!;
        final color = _getStatusColor(state.state);
        final isActive =
            state.state == conn_state.ConnectionState.ready ||
            state.state == conn_state.ConnectionState.connected;

        if (widget.showPulse && isActive) {
          return _buildPulsingIndicator(color);
        } else {
          return _buildStaticIndicator(color);
        }
      },
    );
  }

  Widget _buildPulsingIndicator(Color color) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 2),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3 + (0.7 * value)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5 * value),
                blurRadius: 8 * value,
                spreadRadius: 2 * value,
              ),
            ],
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildStaticIndicator(Color color) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(conn_state.ConnectionState state) {
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
}

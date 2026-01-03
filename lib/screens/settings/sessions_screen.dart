import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'dart:async';
import 'package:gwid/app_sizes.dart';

class Session {
  final String client;
  final String location;
  final bool current;
  final int time;
  final String info;

  Session({
    required this.client,
    required this.location,
    required this.current,
    required this.time,
    required this.info,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      client: json['client'] ?? 'Неизвестное устройство',
      location: json['location'] ?? 'Неизвестное местоположение',
      current: json['current'] ?? false,
      time: json['time'] ?? 0,
      info: json['info'] ?? 'Нет дополнительной информации',
    );
  }
}

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<Session> _sessions = [];
  bool _isLoading = true;
  StreamSubscription? _apiSubscription;

  @override
  void initState() {
    super.initState();
    _listenToApi();
    _loadSessions();
  }

  void _listenToApi() {
    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (message['opcode'] == 96 && mounted) {
        final payload = message['payload'];
        if (payload != null && payload['sessions'] != null) {
          final sessionsList = payload['sessions'] as List;
          setState(() {
            _sessions = sessionsList
                .map((session) => Session.fromJson(session))
                .toList();
            _isLoading = false;
          });
        }
      }
    });
  }

  void _loadSessions() {
    setState(() => _isLoading = true);
    ApiService.instance.requestSessions();
  }

  void _terminateAllSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить другие сессии?'),
        content: const Text(
          'Все сессии, кроме текущей, будут завершены. Вы уверены?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ApiService.instance.terminateAllSessions();
      Future.delayed(const Duration(seconds: 1), _loadSessions);
    }
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} д. назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч. назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} м. назад';
    } else {
      return 'Только что';
    }
  }

  IconData _getDeviceIcon(String clientInfo) {
    final lowerInfo = clientInfo.toLowerCase();
    if (lowerInfo.contains('windows') ||
        lowerInfo.contains('linux') ||
        lowerInfo.contains('macos')) {
      return Icons.computer_outlined;
    } else if (lowerInfo.contains('iphone') || lowerInfo.contains('ios')) {
      return Icons.phone_iphone;
    } else if (lowerInfo.contains('android')) {
      return Icons.phone_android;
    }
    return Icons.web_asset;
  }

  @override
  void dispose() {
    _apiSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Активные сессии"),
        actions: [
          IconButton(onPressed: _loadSessions, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          if (_sessions.any((s) => !s.current))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _terminateAllSessions,
                  icon: const Icon(Icons.logout),
                  label: const Text("Завершить другие сессии"),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.errorContainer,
                    foregroundColor: colors.onErrorContainer,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                ? Center(
                    child: Text(
                      "Активных сессий не найдено.",
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final deviceIcon = _getDeviceIcon(session.client);

                      return Card(
                        elevation: session.current ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: session.current
                                ? colors.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(deviceIcon, size: 40, color: colors.primary),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.client,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      session.location,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Последняя активность: ${_formatTime(session.time)}",
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (session.current)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

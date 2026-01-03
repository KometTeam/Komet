import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:gwid/screens/cache_management_screen.dart';
import 'package:provider/provider.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/screens/phone_entry_screen.dart';
import 'package:gwid/screens/custom_request_screen.dart';
import 'dart:async';
import 'package:gwid/app_sizes.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Settings'),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.xxl),
        children: [
          _OutlinedSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "Performance Debug",
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.speed),
                  title: const Text("Показать FPS overlay"),
                  subtitle: const Text("Отображение FPS и производительности"),
                  trailing: Switch(
                    value: theme.debugShowPerformanceOverlay,
                    onChanged: (value) =>
                        theme.setDebugShowPerformanceOverlay(value),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.refresh),
                  title: const Text("Показать панель обновления чатов"),
                  subtitle: const Text(
                    "Debug панель для обновления списка чатов",
                  ),
                  trailing: Switch(
                    value: theme.debugShowChatsRefreshPanel,
                    onChanged: (value) =>
                        theme.setDebugShowChatsRefreshPanel(value),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.message),
                  title: const Text("Показать счётчик сообщений"),
                  subtitle: const Text("Отладочная информация о сообщениях"),
                  trailing: Switch(
                    value: theme.debugShowMessageCount,
                    onChanged: (value) => theme.setDebugShowMessageCount(value),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _OutlinedSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "Инструменты разработчика",
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.code),
                  title: const Text("Custom API Request"),
                  subtitle: const Text("Отправить сырой запрос на сервер"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CustomRequestScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _OutlinedSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "Data Management",
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever),
                  title: const Text("Очистить все данные"),
                  subtitle: const Text("Полная очистка кэшей и данных"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showClearAllDataDialog(context),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone),
                  title: const Text("Показать ввод номера"),
                  subtitle: const Text("Открыть экран ввода номера без выхода"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPhoneEntryScreen(context),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.traffic),
                  title: const Text("Статистика трафика"),
                  subtitle: const Text("Просмотр использованного трафика"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTrafficStats(context),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storage),
                  title: const Text("Использование памяти"),
                  subtitle: const Text("Просмотр статистики памяти"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showMemoryUsage(context),
                ),
                const SizedBox(height: 8),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cached),
                  title: const Text("Управление кэшем"),
                  subtitle: const Text("Настройки кэширования и статистика"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CacheManagementScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить все данные'),
        content: const Text(
          'Это действие удалит ВСЕ данные приложения:\n\n'
          '• Все кэши и сообщения\n'
          '• Настройки и профиль\n'
          '• Токен авторизации\n'
          '• История чатов\n\n'
          'После очистки приложение будет закрыто.\n'
          'Вы уверены?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performFullDataClear(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Очистить и закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _performFullDataClear(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Очистка данных...'),
            ],
          ),
        ),
      );

      await ApiService.instance.clearAllData();

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Все данные очищены. Приложение будет закрыто.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      await Future.delayed(const Duration(seconds: 2));

      if (context.mounted) {
        SystemNavigator.pop();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при очистке данных: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPhoneEntryScreen(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const PhoneEntryScreen()));
  }

  void _showTrafficStats(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Статистика трафика'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Статистика использования данных:'),
            SizedBox(height: 16),
            Text('• Отправлено сообщений: 1,247'),
            Text('• Получено сообщений: 3,891'),
            Text('• Загружено фото: 156 MB'),
            Text('• Загружено видео: 89 MB'),
            Text('• Общий трафик: 2.1 GB'),
            SizedBox(height: 16),
            Text('📅 За последние 30 дней'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showMemoryUsage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Использование памяти'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💾 Использование памяти:'),
            SizedBox(height: 16),
            Text('• Кэш сообщений: 45.2 MB'),
            Text('• Кэш контактов: 12.8 MB'),
            Text('• Кэш чатов: 8.3 MB'),
            Text('• Медиа файлы: 156.7 MB'),
            Text('• Общее использование: 223.0 MB'),
            SizedBox(height: 16),
            Text('📱 Доступно памяти: 2.1 GB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ApiService.instance.clearAllCaches();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Кэш очищен'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Очистить кэш'),
          ),
        ],
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
      client: json['client'] ?? '',
      location: json['location'] ?? '',
      current: json['current'] ?? false,
      time: json['time'] ?? 0,
      info: json['info'] ?? '',
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
  bool _isInitialLoad = true;
  StreamSubscription? _apiSubscription;

  @override
  void initState() {
    super.initState();
    _listenToApi();
  }

  void _loadSessions() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    });
    ApiService.instance.requestSessions();
  }

  void _terminateAllSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить все сессии?'),
        content: const Text(
          'Все остальные сессии будут завершены. '
          'Текущая сессия останется активной.',
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
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }
      });

      ApiService.instance.terminateAllSessions();

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadSessions();
            }
          });
        }
      });
    }
  }

  void _listenToApi() {
    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (message['opcode'] == 96 && mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });

        final payload = message['payload'];
        if (payload != null && payload['sessions'] != null) {
          final sessionsList = payload['sessions'] as List;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _sessions = sessionsList
                    .map((session) => Session.fromJson(session))
                    .toList();
              });
            }
          });
        }
      }
    });
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    String relativeTime;
    if (difference.inDays > 0) {
      relativeTime = '${difference.inDays} дн. назад';
    } else if (difference.inHours > 0) {
      relativeTime = '${difference.inHours} ч. назад';
    } else if (difference.inMinutes > 0) {
      relativeTime = '${difference.inMinutes} мин. назад';
    } else {
      relativeTime = 'Только что';
    }

    final exactTime =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return '$relativeTime ($exactTime)';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_isInitialLoad && _sessions.isEmpty) {
      _isInitialLoad = false;
      _loadSessions();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Активные сессии"),
        actions: [
          IconButton(onPressed: _loadSessions, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security,
                    size: 64,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Нет активных сессий",
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (_sessions.any((s) => !s.current))
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: _terminateAllSessions,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: colors.onError,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.logout, size: 24),
                      label: const Text(
                        "Завершить все сессии кроме текущей",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: session.current
                                ? colors.primary
                                : colors.surfaceContainerHighest,
                            child: Icon(
                              session.current
                                  ? Icons.phone_android
                                  : Icons.computer,
                              color: session.current
                                  ? colors.onPrimary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                          title: Text(
                            session.current ? "Текущая сессия" : session.client,
                            style: TextStyle(
                              fontWeight: session.current
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: session.current
                                  ? colors.primary
                                  : colors.onSurface,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                session.location,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                session.info,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(session.time),
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: session.current
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Активна",
                                    style: TextStyle(
                                      color: colors.onPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Неактивна",
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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

  @override
  void dispose() {
    _apiSubscription?.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/screens/home_screen.dart';

class ReconnectionScreen extends StatefulWidget {
  const ReconnectionScreen({super.key});

  @override
  State<ReconnectionScreen> createState() => _ReconnectionScreenState();
}

class _ReconnectionScreenState extends State<ReconnectionScreen> {
  StreamSubscription? _apiSubscription;
  String _statusMessage = 'Переподключение...';
  bool _isReconnecting = true;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startFullReconnection();
    _listenToApiMessages();
  }

  @override
  void dispose() {
    _apiSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _listenToApiMessages() {
    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (!mounted) return;

      print(
        'ReconnectionScreen: Получено сообщение: opcode=${message['opcode']}, cmd=${message['cmd']}',
      );

      if (message['opcode'] == 19 && message['cmd'] == 1) {
        final payload = message['payload'];
        print('ReconnectionScreen: Получен opcode 19, payload: $payload');
        if (payload != null && payload['token'] != null) {
          print('ReconnectionScreen: Вызываем _onReconnectionSuccess()');
          _onReconnectionSuccess();
          return;
        }
      }

      if (message['cmd'] == 3) {
        final errorPayload = message['payload'];
        String errorMessage = 'Ошибка переподключения';
        if (errorPayload != null) {
          if (errorPayload['localizedMessage'] != null) {
            errorMessage = errorPayload['localizedMessage'];
          } else if (errorPayload['message'] != null) {
            errorMessage = errorPayload['message'];
          }
        }
        _onReconnectionError(errorMessage);
      }
    });
  }

  void _onReconnectionSuccess() {
    if (!mounted) return;

    print('ReconnectionScreen: _onReconnectionSuccess() вызван');

    _timeoutTimer?.cancel();

    setState(() {
      _statusMessage = 'Переподключение успешно!';
      _isReconnecting = false;
    });

    print('ReconnectionScreen: Устанавливаем таймер для навигации...');

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        print('ReconnectionScreen: Навигация к HomeScreen...');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  void _onReconnectionError(String error) {
    if (!mounted) return;

    _timeoutTimer?.cancel();

    setState(() {
      _statusMessage = 'Ошибка: $error';
      _isReconnecting = false;
    });

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Нажмите для повторной попытки';
        });
      }
    });
  }

  Future<void> _startFullReconnection() async {
    try {
      print('ReconnectionScreen: Начинаем полное переподключение...');

      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && _isReconnecting) {
          _onReconnectionError('Таймаут переподключения');
        }
      });

      setState(() {
        _statusMessage = 'Отключение от сервера...';
      });

      ApiService.instance.disconnect();

      setState(() {
        _statusMessage = 'Очистка кэшей...';
      });

      ApiService.instance.clearAllCaches();

      setState(() {
        _statusMessage = 'Подключение к серверу...';
      });

      await ApiService.instance.performFullReconnection();

      setState(() {
        _statusMessage = 'Аутентификация...';
      });

      final hasToken = await ApiService.instance.hasToken();
      if (hasToken) {
        setState(() {
          _statusMessage = 'Аутентификация...';
        });

        await ApiService.instance.getChatsAndContacts();

        setState(() {
          _statusMessage = 'Загрузка данных...';
        });
      } else {
        _onReconnectionError('Токен аутентификации не найден');
      }
    } catch (e) {
      _onReconnectionError('Ошибка переподключения: ${e.toString()}');
    }
  }

  void _retryReconnection() {
    setState(() {
      _statusMessage = 'Переподключение...';
      _isReconnecting = true;
    });
    _startFullReconnection();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: colors.surface.withOpacity(0.95),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: _isReconnecting
                    ? CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primary,
                        ),
                      )
                    : Icon(
                        _statusMessage.contains('Ошибка')
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 60,
                        color: _statusMessage.contains('Ошибка')
                            ? colors.error
                            : colors.primary,
                      ),
              ),

              const SizedBox(height: 32),

              Text(
                'Переподключение',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 48),

              if (!_isReconnecting && _statusMessage.contains('Нажмите'))
                ElevatedButton.icon(
                  onPressed: _retryReconnection,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outline.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Выполняется полное переподключение к серверу. Пожалуйста, подождите.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

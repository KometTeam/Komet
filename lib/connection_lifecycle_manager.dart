import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gwid/api/api_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'utils/theme_provider.dart';

class ConnectionLifecycleManager extends StatefulWidget {
  final Widget child;

  const ConnectionLifecycleManager({super.key, required this.child});

  @override
  _ConnectionLifecycleManagerState createState() =>
      _ConnectionLifecycleManagerState();
}

class _ConnectionLifecycleManagerState extends State<ConnectionLifecycleManager>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isReconnecting = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WakelockPlus.enable();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        print("Возобновлено");
        ApiService.instance.setAppInForeground(true);
        ApiService.instance.sendNavEvent('WARM_START');
        _checkAndReconnectIfNeeded();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        ApiService.instance.setAppInForeground(false);
        if (state == AppLifecycleState.paused) {
          ApiService.instance.sendNavEvent('GO', screenTo: 1, screenFrom: 150);
        }
        break;
    }
  }

  Future<void> _checkAndReconnectIfNeeded() async {
    if (ApiService.instance.isConnecting) {
      print("🔄 Подключение уже в процессе, пропускаем проверку (ранняя)");
      return;
    }
    
    final hasToken = await ApiService.instance.hasToken();
    if (!hasToken) {
      print("🔒 Токен отсутствует, переподключение не требуется");
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    
    if (ApiService.instance.isConnecting) {
      print("🔄 Подключение уже в процессе, пропускаем проверку");
      return;
    }
    
    final bool actuallyConnected = ApiService.instance.isActuallyConnected;
    print("🔍 Проверка соединения:");
    print("   - isOnline: ${ApiService.instance.isOnline}");
    print("   - isActuallyConnected: $actuallyConnected");

    if (!actuallyConnected) {
      print("🔌 Соединение потеряно. Запускаем переподключение...");
      if (mounted) {
        setState(() {
          _isReconnecting = true;
        });
        _animationController.forward();
      }

      try {
        await ApiService.instance.performFullReconnection();
        print("✅ Переподключение выполнено успешно");
        if (mounted) {
          await _animationController.reverse();
          if (!mounted) return;
          setState(() {
            _isReconnecting = false;
          });
        }
      } catch (e) {
        print("❌ Ошибка при переподключении: $e");
        Future.delayed(const Duration(seconds: 3), () async {
          if (!ApiService.instance.isActuallyConnected) {
            print("🔁 Повторная попытка переподключения...");
            try {
              await ApiService.instance.performFullReconnection();
              if (mounted) {
                await _animationController.reverse();
                if (!mounted) return;
                setState(() {
                  _isReconnecting = false;
                });
              }
            } catch (e) {
              print("❌ Повторная попытка не удалась: $e");
              if (mounted) {
                await _animationController.reverse();
                if (!mounted) return;
                setState(() {
                  _isReconnecting = false;
                });
              }
            }
          }
        });
      }
    } else {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final accentColor = theme.accentColor;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [widget.child]),
    );
  }
}

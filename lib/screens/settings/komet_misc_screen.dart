import 'package:flutter/material.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class KometMiscScreen extends StatefulWidget {
  final bool isModal;

  const KometMiscScreen({super.key, this.isModal = false});

  @override
  State<KometMiscScreen> createState() => _KometMiscScreenState();
}

class _KometMiscScreenState extends State<KometMiscScreen> {
  bool? _isBatteryOptimizationDisabled;
  bool _isAutoUpdateEnabled = false;
  bool _showUpdateNotification = true;
  bool _enableWebVersionCheck = false;
  bool _showSpoofUpdateDialog = true;
  bool _showSferumButton = true;

  @override
  void initState() {
    super.initState();
    _checkBatteryOptimizationStatus();
    _loadUpdateSettings();
  }

  Future<void> _loadUpdateSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoUpdateEnabled = prefs.getBool('auto_update_enabled') ?? false;
      _showUpdateNotification =
          prefs.getBool('show_update_notification') ?? true;
      _enableWebVersionCheck =
          prefs.getBool('enable_web_version_check') ?? false;
      _showSpoofUpdateDialog =
          prefs.getBool('show_spoof_update_dialog') ?? true;
      _showSferumButton =
          prefs.getBool('show_sferum_button') ?? true;
    });
  }

  Future<void> _checkBatteryOptimizationStatus() async {
    bool? isDisabled =
        await DisableBatteryOptimization.isBatteryOptimizationDisabled;
    if (mounted) {
      setState(() {
        _isBatteryOptimizationDisabled = isDisabled;
      });
    }
  }

  Future<void> _requestDisableBatteryOptimization() async {
    await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkBatteryOptimizationStatus();
    });
  }

  Future<void> _updateSettings(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    String subtitleText;
    Color statusColor;
    final defaultTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    final isDesktopOrIOS =
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isIOS;

    if (isDesktopOrIOS) {
      subtitleText = "Недоступно";
      statusColor = Colors.grey;
    } else if (_isBatteryOptimizationDisabled == null) {
      subtitleText = "Проверка статуса...";
      statusColor = Colors.grey;
    } else if (_isBatteryOptimizationDisabled == true) {
      subtitleText = "Разрешено";
      statusColor = Colors.green;
    } else {
      subtitleText = "Не разрешено";
      statusColor = Colors.orange;
    }

    if (widget.isModal) {
      return buildModalContent(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Komet Misc")),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(
                Icons.battery_charging_full_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text("Фоновая работа"),
              subtitle: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: defaultTextColor),
                  children: <TextSpan>[
                    const TextSpan(text: 'Статус: '),
                    TextSpan(
                      text: subtitleText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: isDesktopOrIOS ? null : _requestDisableBatteryOptimization,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              isDesktopOrIOS
                  ? 'Фоновая работа недоступна на данной платформе.'
                  : 'Для стабильной работы приложения в фоновом режиме рекомендуется отключить оптимизацию расхода заряда батареи.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ),

          const Divider(height: 20),

          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.wifi_find_outlined,
                    color: _enableWebVersionCheck
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: const Text("Проверка версии через web"),
                  subtitle: Text(
                    _enableWebVersionCheck
                        ? "Проверяет актуальную версию на web.max.ru"
                        : "Проверка версии отключена",
                  ),
                  value: _enableWebVersionCheck,
                  onChanged: (bool value) {
                    setState(() {
                      _enableWebVersionCheck = value;
                    });
                    _updateSettings('enable_web_version_check', value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    Icons.system_update_alt_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text("Автообновление сессии"),
                  subtitle: const Text("Версия будет обновляться в фоне"),
                  value: _isAutoUpdateEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      _isAutoUpdateEnabled = value;
                    });
                    _updateSettings('auto_update_enabled', value);
                  },
                ),

                SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_active_outlined,

                    color: _isAutoUpdateEnabled
                        ? Colors.grey
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text("Уведомлять о новой версии"),
                  subtitle: Text(
                    _isAutoUpdateEnabled
                        ? "Недоступно при автообновлении"
                        : "Показывать диалог при запуске",
                  ),
                  value: _showUpdateNotification,

                  onChanged: _isAutoUpdateEnabled
                      ? null
                      : (bool value) {
                          setState(() {
                            _showUpdateNotification = value;
                          });
                          _updateSettings('show_update_notification', value);
                        },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    Icons.sync_problem_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text("Диалог обновлений спуфа"),
                  subtitle: const Text(
                    "Показывать диалог проверки обновлений спуфа при запуске",
                  ),
                  value: _showSpoofUpdateDialog,
                  onChanged: (bool value) {
                    setState(() {
                      _showSpoofUpdateDialog = value;
                    });
                    _updateSettings('show_spoof_update_dialog', value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    Icons.remove_red_eye,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text("Показывать кнопку Сферум?"),
                  subtitle: const Text(
                    "Показывать кнопку Сферум в главном меню. Для применения нужен перезапуск приложения.",
                  ),
                  value: _showSferumButton,
                  onChanged: (bool value) {
                    setState(() {
                      _showSferumButton = value;
                    });
                    _updateSettings('show_sferum_button', value);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              'Автообновление автоматически изменит версию вашей сессии на последнюю доступную без дополнительных уведомлений.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalSettings(
    BuildContext context,
    String subtitleText,
    Color statusColor,
    Color? defaultTextColor,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.3),
            ),
          ),

          Center(
            child: Container(
              width: 400,
              height: 600,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Назад',
                        ),
                        const Expanded(
                          child: Text(
                            "Komet Misc",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Закрыть',
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.battery_charging_full),
                            title: const Text("Оптимизация батареи"),
                            subtitle: Text(subtitleText),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: statusColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap:
                                Platform.isWindows ||
                                    Platform.isMacOS ||
                                    Platform.isLinux ||
                                    Platform.isIOS
                                ? null
                                : _requestDisableBatteryOptimization,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text("Автообновления"),
                                subtitle: const Text(
                                  "Автоматически проверять обновления",
                                ),
                                value: _isAutoUpdateEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _isAutoUpdateEnabled = value;
                                  });
                                  _updateSettings('auto_update_enabled', value);
                                },
                              ),
                              SwitchListTile(
                                title: const Text("Уведомления об обновлениях"),
                                subtitle: const Text(
                                  "Показывать уведомления о доступных обновлениях",
                                ),
                                value: _showUpdateNotification,
                                onChanged: (value) {
                                  setState(() {
                                    _showUpdateNotification = value;
                                  });
                                  _updateSettings(
                                    'show_update_notification',
                                    value,
                                  );
                                },
                              ),
                              SwitchListTile(
                                title: const Text("Диалог обновлений спуфа"),
                                subtitle: const Text(
                                  "Показывать диалог проверки обновлений спуфа при запуске",
                                ),
                                value: _showSpoofUpdateDialog,
                                onChanged: (value) {
                                  setState(() {
                                    _showSpoofUpdateDialog = value;
                                  });
                                  _updateSettings(
                                    'show_spoof_update_dialog',
                                    value,
                                  );
                                },
                              ),
                              SwitchListTile(
                                title: const Text("Проверка веб-версии"),
                                subtitle: const Text(
                                  "Проверять обновления через веб-интерфейс",
                                ),
                                value: _enableWebVersionCheck,
                                onChanged: (value) {
                                  setState(() {
                                    _enableWebVersionCheck = value;
                                  });
                                  _updateSettings(
                                    'enable_web_version_check',
                                    value,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildModalContent(BuildContext context) {
    String subtitleText;
    Color statusColor;
    final defaultTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    final isDesktopOrIOS =
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isIOS;

    if (isDesktopOrIOS) {
      subtitleText = "Недоступно";
      statusColor = Colors.grey;
    } else if (_isBatteryOptimizationDisabled == null) {
      subtitleText = "Проверка статуса...";
      statusColor = Colors.grey;
    } else if (_isBatteryOptimizationDisabled == true) {
      subtitleText = "Разрешено";
      statusColor = Colors.green;
    } else {
      subtitleText = "Не разрешено";
      statusColor = Colors.orange;
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Icon(
              Icons.battery_charging_full_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text("Фоновая работа"),
            subtitle: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: defaultTextColor),
                children: <TextSpan>[
                  const TextSpan(text: 'Статус: '),
                  TextSpan(
                    text: subtitleText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: isDesktopOrIOS ? null : _requestDisableBatteryOptimization,
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: Icon(
                  Icons.system_update_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text("Автообновления"),
                subtitle: const Text(
                  "Автоматически проверять и устанавливать обновления",
                ),
                value: _isAutoUpdateEnabled,
                onChanged: (value) {
                  setState(() {
                    _isAutoUpdateEnabled = value;
                  });
                  _updateSettings('auto_update_enabled', value);
                },
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: Icon(
                  Icons.notifications_active_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text("Уведомления об обновлениях"),
                subtitle: const Text(
                  "Показывать уведомления о доступных обновлениях",
                ),
                value: _showUpdateNotification,
                onChanged: (value) {
                  setState(() {
                    _showUpdateNotification = value;
                  });
                  _updateSettings('show_update_notification', value);
                },
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: Icon(
                  Icons.sync_problem_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text("Диалог обновлений спуфа"),
                subtitle: const Text(
                  "Показывать диалог проверки обновлений спуфа при запуске",
                ),
                value: _showSpoofUpdateDialog,
                onChanged: (value) {
                  setState(() {
                    _showSpoofUpdateDialog = value;
                  });
                  _updateSettings('show_spoof_update_dialog', value);
                },
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: Icon(
                  Icons.web_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text("Проверка веб-версии"),
                subtitle: const Text(
                  "Проверять обновления веб-версии приложения",
                ),
                value: _enableWebVersionCheck,
                onChanged: (value) {
                  setState(() {
                    _enableWebVersionCheck = value;
                  });
                  _updateSettings('enable_web_version_check', value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

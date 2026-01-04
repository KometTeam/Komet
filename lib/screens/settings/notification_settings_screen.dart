import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/services/notification_settings_service.dart';
import 'dart:io' show Platform;

class NotificationSettingsScreen extends StatefulWidget {
  final bool isModal;

  const NotificationSettingsScreen({super.key, this.isModal = false});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _isLoading = false;

  // Новые настройки
  bool _notificationsEnabled = true;
  bool _privateChatsEnabled = true;
  bool _groupsEnabled = true;
  bool _channelsEnabled = true;
  bool _reactionsEnabled = true;
  VibrationMode _vibrationMode = VibrationMode.short;

  final _settingsService = NotificationSettingsService();

  Widget buildModalContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final isDesktopOrIOS =
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isIOS;

    if (isDesktopOrIOS) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 48, color: colors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Фоновые уведомления недоступны',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isIOS
                        ? 'На iOS фоновые уведомления не поддерживаются системой.'
                        : 'На настольных платформах (Windows, macOS, Linux) фоновые уведомления отключены.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Глобальные настройки
              _OutlinedSection(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.notifications_outlined),
                      title: const Text("Уведомления"),
                      subtitle: const Text("Включить все уведомления"),
                      value: _notificationsEnabled,
                      onChanged: (value) async {
                        await _settingsService.setNotificationsEnabled(value);
                        setState(() => _notificationsEnabled = value);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Настройки обновлены'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Настройки по типу чата
              _OutlinedSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        top: 8,
                        bottom: 4,
                      ),
                      child: Text(
                        'Уведомления из чатов',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.person_outline),
                      title: const Text("Личные чаты"),
                      value: _privateChatsEnabled,
                      onChanged: _notificationsEnabled
                          ? (value) async {
                              await _settingsService.setPrivateChatsEnabled(
                                value,
                              );
                              setState(() => _privateChatsEnabled = value);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Настройки обновлены'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.group_outlined),
                      title: const Text("Группы"),
                      value: _groupsEnabled,
                      onChanged: _notificationsEnabled
                          ? (value) async {
                              await _settingsService.setGroupsEnabled(value);
                              setState(() => _groupsEnabled = value);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Настройки обновлены'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.campaign_outlined),
                      title: const Text("Каналы"),
                      value: _channelsEnabled,
                      onChanged: _notificationsEnabled
                          ? (value) async {
                              await _settingsService.setChannelsEnabled(value);
                              setState(() => _channelsEnabled = value);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Настройки обновлены'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.favorite_outline),
                      title: const Text("Реакции"),
                      subtitle: const Text(
                        "Уведомления о реакциях на сообщения",
                      ),
                      value: _reactionsEnabled,
                      onChanged: _notificationsEnabled
                          ? (value) async {
                              await _settingsService.setReactionsEnabled(value);
                              setState(() => _reactionsEnabled = value);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Настройки обновлены'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Настройки вибрации
              _OutlinedSection(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.vibration_outlined),
                      title: const Text("Вибрация"),
                      trailing: Text(
                        _getVibrationDescription(_vibrationMode),
                        style: TextStyle(color: colors.primary),
                      ),
                      onTap: _notificationsEnabled
                          ? () => _showVibrationDialog()
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);

    try {
      // Загружаем новые настройки
      _notificationsEnabled = await _settingsService.areNotificationsEnabled();
      _privateChatsEnabled = await _settingsService.arePrivateChatsEnabled();
      _groupsEnabled = await _settingsService.areGroupsEnabled();
      _channelsEnabled = await _settingsService.areChannelsEnabled();
      _reactionsEnabled = await _settingsService.areReactionsEnabled();
      _vibrationMode = await _settingsService.getVibrationMode();

      setState(() {});
    } catch (e) {
      print('Ошибка загрузки настроек: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showVibrationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Вибрация'),
          children: [
            RadioListTile<VibrationMode>(
              title: const Text('Без вибрации'),
              value: VibrationMode.none,
              groupValue: _vibrationMode,
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
            RadioListTile<VibrationMode>(
              title: const Text('Короткая'),
              value: VibrationMode.short,
              groupValue: _vibrationMode,
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
            RadioListTile<VibrationMode>(
              title: const Text('Длинная'),
              value: VibrationMode.long,
              groupValue: _vibrationMode,
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
          ],
        );
      },
    ).then((selectedValue) async {
      if (selectedValue != null) {
        await _settingsService.setVibrationMode(selectedValue);
        setState(() => _vibrationMode = selectedValue);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Настройки вибрации обновлены'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
  }

  String _getVibrationDescription(VibrationMode mode) {
    switch (mode) {
      case VibrationMode.none:
        return 'Выключена';
      case VibrationMode.short:
        return 'Короткая';
      case VibrationMode.long:
        return 'Длинная';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (widget.isModal) {
      return buildModalContent(context);
    }

    final isDesktopOrIOS =
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isIOS;

    if (isDesktopOrIOS) {
      return Scaffold(
        appBar: AppBar(title: const Text('Уведомления')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: colors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Фоновые уведомления недоступны',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Platform.isIOS
                          ? 'На iOS фоновые уведомления не поддерживаются системой.'
                          : 'На настольных платформах (Windows, macOS, Linux) фоновые уведомления отключены.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Глобальные настройки
                _OutlinedSection(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text("Уведомления"),
                        subtitle: const Text("Включить все уведомления"),
                        value: _notificationsEnabled,
                        onChanged: (value) async {
                          await _settingsService.setNotificationsEnabled(value);
                          setState(() => _notificationsEnabled = value);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Настройки обновлены'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Настройки по типу чата
                _OutlinedSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          top: 8,
                          bottom: 4,
                        ),
                        child: Text(
                          'Уведомления из чатов',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.person_outline),
                        title: const Text("Личные чаты"),
                        value: _privateChatsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) async {
                                await _settingsService.setPrivateChatsEnabled(
                                  value,
                                );
                                setState(() => _privateChatsEnabled = value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Настройки обновлены'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.group_outlined),
                        title: const Text("Группы"),
                        value: _groupsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) async {
                                await _settingsService.setGroupsEnabled(value);
                                setState(() => _groupsEnabled = value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Настройки обновлены'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.campaign_outlined),
                        title: const Text("Каналы"),
                        value: _channelsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) async {
                                await _settingsService.setChannelsEnabled(
                                  value,
                                );
                                setState(() => _channelsEnabled = value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Настройки обновлены'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.favorite_outline),
                        title: const Text("Реакции"),
                        subtitle: const Text(
                          "Уведомления о реакциях на сообщения",
                        ),
                        value: _reactionsEnabled,
                        onChanged: _notificationsEnabled
                            ? (value) async {
                                await _settingsService.setReactionsEnabled(
                                  value,
                                );
                                setState(() => _reactionsEnabled = value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Настройки обновлены'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Настройки вибрации
                _OutlinedSection(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.vibration_outlined),
                        title: const Text("Вибрация"),
                        trailing: Text(
                          _getVibrationDescription(_vibrationMode),
                          style: TextStyle(color: colors.primary),
                        ),
                        onTap: _notificationsEnabled
                            ? () => _showVibrationDialog()
                            : null,
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

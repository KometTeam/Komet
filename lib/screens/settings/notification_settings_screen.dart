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
  String _chatsPushNotification = 'ON';
  bool _mCallPushNotification = true;
  bool _pushDetails = true;
  String _chatsPushSound = 'DEFAULT';
  String _pushSound = 'DEFAULT';
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
                      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 4),
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
                      onChanged: _notificationsEnabled ? (value) async {
                        await _settingsService.setPrivateChatsEnabled(value);
                        setState(() => _privateChatsEnabled = value);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Настройки обновлены'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.group_outlined),
                      title: const Text("Группы"),
                      value: _groupsEnabled,
                      onChanged: _notificationsEnabled ? (value) async {
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
                      } : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.campaign_outlined),
                      title: const Text("Каналы"),
                      value: _channelsEnabled,
                      onChanged: _notificationsEnabled ? (value) async {
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
                      } : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.favorite_outline),
                      title: const Text("Реакции"),
                      subtitle: const Text("Уведомления о реакциях на сообщения"),
                      value: _reactionsEnabled,
                      onChanged: _notificationsEnabled ? (value) async {
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
                      } : null,
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
                      onTap: _notificationsEnabled ? () => _showVibrationDialog() : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Старые настройки (совместимость)
              _OutlinedSection(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.chat_bubble_outline),
                      title: const Text("Уведомления из чатов (старое)"),
                      value: _chatsPushNotification == 'ON',
                      onChanged: (value) =>
                          _updateNotificationSetting(chatsPush: value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.phone_outlined),
                      title: const Text("Уведомления о звонках"),
                      value: _mCallPushNotification,
                      onChanged: (value) =>
                          _updateNotificationSetting(mCallPush: value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.visibility_outlined),
                      title: const Text("Показывать текст"),
                      subtitle: const Text("Показывать превью сообщения"),
                      value: _pushDetails,
                      onChanged: (value) =>
                          _updateNotificationSetting(pushDetails: value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _OutlinedSection(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.music_note_outlined),
                      title: const Text("Звук в чатах"),
                      trailing: Text(
                        _getSoundDescription(_chatsPushSound),
                        style: TextStyle(color: colors.primary),
                      ),
                      onTap: () => _showSoundDialog(
                        "Звук уведомлений чатов",
                        _chatsPushSound,
                        (value) =>
                            _updateNotificationSetting(chatsSound: value),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: const Text("Общий звук"),
                      trailing: Text(
                        _getSoundDescription(_pushSound),
                        style: TextStyle(color: colors.primary),
                      ),
                      onTap: () => _showSoundDialog(
                        "Общий звук уведомлений",
                        _pushSound,
                        (value) => _updateNotificationSetting(pushSound: value),
                      ),
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

  Future<void> _updateNotificationSetting({
    bool? chatsPush,
    bool? mCallPush,
    bool? pushDetails,
    String? chatsSound,
    String? pushSound,
  }) async {
    try {
      await ApiService.instance.updatePrivacySettings(
        chatsPushNotification: chatsPush,
        mCallPushNotification: mCallPush,
        pushDetails: pushDetails,
        chatsPushSound: chatsSound,
        pushSound: pushSound,
      );

      if (chatsPush != null) {
        setState(() => _chatsPushNotification = chatsPush ? 'ON' : 'OFF');
      }
      if (mCallPush != null) setState(() => _mCallPushNotification = mCallPush);
      if (pushDetails != null) setState(() => _pushDetails = pushDetails);
      if (chatsSound != null) setState(() => _chatsPushSound = chatsSound);
      if (pushSound != null) setState(() => _pushSound = pushSound);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Настройки уведомлений обновлены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showSoundDialog(
    String title,
    String currentValue,
    Function(String) onSelect,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(title),
          children: [
            RadioListTile<String>(
              title: const Text('Стандартный звук'),
              value: 'DEFAULT',
              groupValue: currentValue,
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
            RadioListTile<String>(
              title: const Text('Без звука'),
              value: '_NONE_',
              groupValue: currentValue,
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
          ],
        );
      },
    ).then((selectedValue) {
      if (selectedValue != null) {
        onSelect(selectedValue);
      }
    });
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

  String _getSoundDescription(String sound) {
    switch (sound) {
      case 'DEFAULT':
        return 'Стандартный';
      case '_NONE_':
        return 'Без звука';
      default:
        return 'Неизвестно';
    }
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
                        padding: const EdgeInsets.only(left: 8, top: 8, bottom: 4),
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
                        onChanged: _notificationsEnabled ? (value) async {
                          await _settingsService.setPrivateChatsEnabled(value);
                          setState(() => _privateChatsEnabled = value);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Настройки обновлены'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.group_outlined),
                        title: const Text("Группы"),
                        value: _groupsEnabled,
                        onChanged: _notificationsEnabled ? (value) async {
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
                        } : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.campaign_outlined),
                        title: const Text("Каналы"),
                        value: _channelsEnabled,
                        onChanged: _notificationsEnabled ? (value) async {
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
                        } : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.favorite_outline),
                        title: const Text("Реакции"),
                        subtitle: const Text("Уведомления о реакциях на сообщения"),
                        value: _reactionsEnabled,
                        onChanged: _notificationsEnabled ? (value) async {
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
                        } : null,
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
                        onTap: _notificationsEnabled ? () => _showVibrationDialog() : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Старые настройки (совместимость)
                _OutlinedSection(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.chat_bubble_outline),
                        title: const Text("Уведомления из чатов (старое)"),
                        value: _chatsPushNotification == 'ON',
                        onChanged: (value) =>
                            _updateNotificationSetting(chatsPush: value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.phone_outlined),
                        title: const Text("Уведомления о звонках"),
                        value: _mCallPushNotification,
                        onChanged: (value) =>
                            _updateNotificationSetting(mCallPush: value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.visibility_outlined),
                        title: const Text("Показывать текст"),
                        subtitle: const Text("Показывать превью сообщения"),
                        value: _pushDetails,
                        onChanged: (value) =>
                            _updateNotificationSetting(pushDetails: value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _OutlinedSection(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.music_note_outlined),
                        title: const Text("Звук в чатах"),
                        trailing: Text(
                          _getSoundDescription(_chatsPushSound),
                          style: TextStyle(color: colors.primary),
                        ),
                        onTap: () => _showSoundDialog(
                          "Звук в чатах",
                          _chatsPushSound,
                          (value) =>
                              _updateNotificationSetting(chatsSound: value),
                        ),
                      ),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: const Text("Общий звук"),
                        trailing: Text(
                          _getSoundDescription(_pushSound),
                          style: TextStyle(color: colors.primary),
                        ),
                        onTap: () => _showSoundDialog(
                          "Общий звук уведомлений",
                          _pushSound,
                          (value) =>
                              _updateNotificationSetting(pushSound: value),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModalSettings(BuildContext context) {
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
                            "Уведомления",
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
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _OutlinedSection(
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      secondary: const Icon(
                                        Icons.chat_bubble_outline,
                                      ),
                                      title: const Text("Уведомления из чатов"),
                                      value: _chatsPushNotification == 'ON',
                                      onChanged: (value) =>
                                          _updateNotificationSetting(
                                            chatsPush: value,
                                          ),
                                    ),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      secondary: const Icon(
                                        Icons.phone_outlined,
                                      ),
                                      title: const Text(
                                        "Уведомления о звонках",
                                      ),
                                      value: _mCallPushNotification,
                                      onChanged: (value) =>
                                          _updateNotificationSetting(
                                            mCallPush: value,
                                          ),
                                    ),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      secondary: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      title: const Text("Показывать текст"),
                                      subtitle: const Text(
                                        "Показывать превью сообщения",
                                      ),
                                      value: _pushDetails,
                                      onChanged: (value) =>
                                          _updateNotificationSetting(
                                            pushDetails: value,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _OutlinedSection(
                                child: Column(
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.music_note_outlined,
                                      ),
                                      title: const Text("Звук в чатах"),
                                      trailing: Text(
                                        _getSoundDescription(_chatsPushSound),
                                        style: TextStyle(color: colors.primary),
                                      ),
                                      onTap: () => _showSoundDialog(
                                        "Звук уведомлений чатов",
                                        _chatsPushSound,
                                        (value) => _updateNotificationSetting(
                                          chatsSound: value,
                                        ),
                                      ),
                                    ),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.notifications_active_outlined,
                                      ),
                                      title: const Text("Общий звук"),
                                      trailing: Text(
                                        _getSoundDescription(_pushSound),
                                        style: TextStyle(color: colors.primary),
                                      ),
                                      onTap: () => _showSoundDialog(
                                        "Общий звук уведомлений",
                                        _pushSound,
                                        (value) => _updateNotificationSetting(
                                          pushSound: value,
                                        ),
                                      ),
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
        border: Border.all(color: colors.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

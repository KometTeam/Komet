import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
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
              _OutlinedSection(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.chat_bubble_outline),
                      title: const Text("Уведомления из чатов"),
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

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
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
            RadioGroup<String>(
              groupValue: currentValue,
              onChanged: (v) => Navigator.of(context).pop(v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: 'DEFAULT',
                    title: const Text('Стандартный звук'),
                  ),
                  RadioListTile<String>(
                    value: '_NONE_',
                    title: const Text('Без звука'),
                  ),
                ],
              ),
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
                _OutlinedSection(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.chat_bubble_outline),
                        title: const Text("Уведомления из чатов"),
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
              color: Colors.black.withValues(alpha: 0.3),
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
                    color: Colors.black.withValues(alpha: 0.3),
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
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

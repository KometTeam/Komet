import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gwid/screens/password_management_screen.dart';
import 'package:gwid/app_sizes.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isHidden = false;
  bool _isLoading = false;
  String _searchByPhone = 'ALL';
  String _incomingCall = 'ALL';
  String _chatsInvite = 'ALL';
  bool _contentLevelAccess = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();

    ApiService.instance.messages.listen((message) {
      if (message['type'] == 'privacy_settings_updated' && mounted) {
        _loadCurrentSettings();
      }
    });
  }

  Future<void> _loadCurrentSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isHidden = prefs.getBool('privacy_hidden') ?? false;
        _searchByPhone = prefs.getString('privacy_search_by_phone') ?? 'ALL';
        _incomingCall = prefs.getString('privacy_incoming_call') ?? 'ALL';
        _chatsInvite = prefs.getString('privacy_chats_invite') ?? 'ALL';
        _contentLevelAccess =
            prefs.getBool('privacy_content_level_access') ?? false;
      });
    } catch (e) {
      print('Ошибка загрузки настроек приватности: $e');
    }
  }

  Future<void> _savePrivacySetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      print('Ошибка сохранения настройки $key: $e');
    }
  }

  Future<void> _updateHiddenStatus(bool hidden) async {
    setState(() => _isLoading = true);
    try {
      await ApiService.instance.updatePrivacySettings(
        hidden: hidden ? 'true' : 'false',
      );
      await _savePrivacySetting('privacy_hidden', hidden);
      if (mounted) {
        setState(() => _isHidden = hidden);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hidden ? 'Статус онлайн скрыт' : 'Статус онлайн виден',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePrivacyOption({
    String? searchByPhone,
    String? incomingCall,
    String? chatsInvite,
    bool? contentLevelAccess,
  }) async {
    try {
      await ApiService.instance.updatePrivacySettings(
        searchByPhone: searchByPhone,
        incomingCall: incomingCall,
        chatsInvite: chatsInvite,
        contentLevelAccess: contentLevelAccess,
      );

      if (searchByPhone != null) {
        await _savePrivacySetting('privacy_search_by_phone', searchByPhone);
        if (mounted) setState(() => _searchByPhone = searchByPhone);
      }
      if (incomingCall != null) {
        await _savePrivacySetting('privacy_incoming_call', incomingCall);
        if (mounted) setState(() => _incomingCall = incomingCall);
      }
      if (chatsInvite != null) {
        await _savePrivacySetting('privacy_chats_invite', chatsInvite);
        if (mounted) setState(() => _chatsInvite = chatsInvite);
      }
      if (contentLevelAccess != null) {
        await _savePrivacySetting(
          'privacy_content_level_access',
          contentLevelAccess,
        );
        if (mounted) setState(() => _contentLevelAccess = contentLevelAccess);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Настройки приватности обновлены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar(e);
    }
  }

  void _showErrorSnackBar(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка обновления: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showOptionDialog(
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
            _buildDialogOption(
              'Все пользователи',
              'ALL',
              currentValue,
              onSelect,
            ),
            _buildDialogOption(
              'Только контакты',
              'CONTACTS',
              currentValue,
              onSelect,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogOption(
    String title,
    String value,
    String groupValue,
    Function(String) onSelect,
  ) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: (newValue) {
        if (newValue != null) {
          onSelect(newValue);
          Navigator.of(context).pop();
        }
      },
    );
  }

  String _getPrivacyDescription(String value) {
    switch (value) {
      case 'ALL':
        return 'Все пользователи';
      case 'CONTACTS':
        return 'Только контакты';
      case 'NOBODY':
        return 'Никто';
      default:
        return 'Неизвестно';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Приватность')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _OutlinedSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Статус онлайн", colors),
                  if (_isLoading) const LinearProgressIndicator(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      _isHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    title: const Text("Скрыть статус онлайн"),
                    subtitle: Text(
                      _isHidden
                          ? "Другие не видят, что вы онлайн"
                          : "Другие видят ваш статус онлайн",
                    ),
                    value: _isHidden,
                    onChanged: _isLoading ? null : _updateHiddenStatus,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _OutlinedSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Взаимодействие", colors),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.search),
                    title: const Text("Кто может найти меня по номеру"),
                    subtitle: Text(_getPrivacyDescription(_searchByPhone)),
                    onTap: () => _showOptionDialog(
                      "Кто может найти вас?",
                      _searchByPhone,
                      (value) => _updatePrivacyOption(searchByPhone: value),
                    ),
                  ),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_callback_outlined),
                    title: const Text("Кто может звонить мне"),
                    subtitle: Text(_getPrivacyDescription(_incomingCall)),
                    onTap: () => _showOptionDialog(
                      "Кто может вам звонить?",
                      _incomingCall,
                      (value) => _updatePrivacyOption(incomingCall: value),
                    ),
                  ),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.group_add_outlined),
                    title: const Text("Кто может приглашать в чаты"),
                    subtitle: Text(_getPrivacyDescription(_chatsInvite)),
                    onTap: () => _showOptionDialog(
                      "Кто может приглашать вас в чаты?",
                      _chatsInvite,
                      (value) => _updatePrivacyOption(chatsInvite: value),
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
                  _buildSectionTitle("Пароль аккаунта", colors),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: const Text("Установить пароль"),
                    subtitle: const Text(
                      "Добавить пароль для дополнительной защиты аккаунта",
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const PasswordManagementScreen(),
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
                  _buildSectionTitle("Уровень контента", colors),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      _contentLevelAccess
                          ? Icons.shield_outlined
                          : Icons.visibility_outlined,
                    ),
                    title: const Text("Безопасный режим"),
                    subtitle: Text(
                      _contentLevelAccess
                          ? "Показывать только безопасный контент"
                          : "Показывать весь доступный контент",
                    ),
                    value: _contentLevelAccess,
                    onChanged: (value) =>
                        _updatePrivacyOption(contentLevelAccess: value),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _OutlinedSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Прочтение сообщений", colors),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.mark_chat_read_outlined),
                    title: const Text("Читать сообщения при входе"),
                    subtitle: const Text(
                      "Отмечать чат прочитанным при открытии",
                    ),

                    value: theme.debugReadOnEnter,
                    onChanged: (value) => theme.setDebugReadOnEnter(value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.send_and_archive_outlined),
                    title: const Text("Читать при отправке сообщения"),
                    subtitle: const Text(
                      "Отмечать чат прочитанным при отправке сообщения",
                    ),

                    value: theme.debugReadOnAction,
                    onChanged: (value) => theme.setDebugReadOnAction(value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
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

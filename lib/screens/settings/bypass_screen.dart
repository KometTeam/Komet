import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BypassScreen extends StatefulWidget {
  final bool isModal;

  const BypassScreen({super.key, this.isModal = false});

  @override
  State<BypassScreen> createState() => _BypassScreenState();
}

class _BypassScreenState extends State<BypassScreen> {
  bool _kometAutoCompleteEnabled = false;
  bool _specialMessagesEnabled = true;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _kometAutoCompleteEnabled =
          prefs.getBool('komet_auto_complete_enabled') ?? false;
      _specialMessagesEnabled =
          prefs.getBool('special_messages_enabled') ?? true;
      _isLoadingSettings = false;
    });
  }

  Future<void> _saveSpecialMessages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('special_messages_enabled', value);
    setState(() {
      _specialMessagesEnabled = value;
    });
  }

  Future<void> _saveKometAutoComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('komet_auto_complete_enabled', value);
    setState(() {
      _kometAutoCompleteEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isModal) {
      final colors = Theme.of(context).colorScheme;
      return _buildModalSettings(context, colors);
    }
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Специальные возможности и фишки")),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          // Обход блокировки
          Text(
            "ОБХОД БЛОКИРОВКИ",
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return SwitchListTile(
                title: const Text(
                  "Обход блокировки",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  "Разрешить отправку сообщений заблокированным пользователям",
                ),
                value: themeProvider.blockBypass,
                onChanged: (value) {
                  themeProvider.setBlockBypass(value);
                },
                secondary: Icon(
                  themeProvider.blockBypass
                      ? Icons.psychology
                      : Icons.psychology_outlined,
                  color: themeProvider.blockBypass
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Фишки (цветные никнеймы, скоро)
          Text(
            "ФИШКИ (KOMET.COLOR)",
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          if (!_isLoadingSettings) ...[
            SwitchListTile(
              title: const Text(
                'Авто-дополнение уникальных сообщений',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Показывать панель выбора цвета при вводе komet.color#',
              ),
              value: _kometAutoCompleteEnabled,
              onChanged: (value) {
                _saveKometAutoComplete(value);
              },
              secondary: Icon(
                _kometAutoCompleteEnabled
                    ? Icons.auto_awesome
                    : Icons.auto_awesome_outlined,
                color: _kometAutoCompleteEnabled
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              title: const Text(
                'Включить список особых сообщений',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Показывать кнопку для быстрой вставки шаблонов особых сообщений',
              ),
              value: _specialMessagesEnabled,
              onChanged: (value) {
                _saveSpecialMessages(value);
              },
              secondary: Icon(
                _specialMessagesEnabled
                    ? Icons.auto_fix_high
                    : Icons.auto_fix_high_outlined,
                color: _specialMessagesEnabled
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModalSettings(BuildContext context, ColorScheme colors) {
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text("Специальные возможности и фишки"),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          Text(
            "ОБХОД БЛОКИРОВКИ",
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return SwitchListTile(
                title: const Text(
                  "Обход блокировки",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  "Разрешить отправку сообщений заблокированным пользователям",
                ),
                value: themeProvider.blockBypass,
                onChanged: (value) {
                  themeProvider.setBlockBypass(value);
                },
                secondary: Icon(
                  themeProvider.blockBypass
                      ? Icons.psychology
                      : Icons.psychology_outlined,
                  color: themeProvider.blockBypass
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          Text(
            "ФИШКИ (KOMET.COLOR)",
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          if (!_isLoadingSettings) ...[
            SwitchListTile(
              title: const Text(
                'Авто-дополнение уникальных сообщений',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Показывать панель выбора цвета при вводе komet.color#',
              ),
              value: _kometAutoCompleteEnabled,
              onChanged: (value) {
                _saveKometAutoComplete(value);
              },
              secondary: Icon(
                _kometAutoCompleteEnabled
                    ? Icons.auto_awesome
                    : Icons.auto_awesome_outlined,
                color: _kometAutoCompleteEnabled
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              title: const Text(
                'Включить список особых сообщений',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Показывать кнопку для быстрой вставки шаблонов особых сообщений',
              ),
              value: _specialMessagesEnabled,
              onChanged: (value) {
                _saveSpecialMessages(value);
              },
              secondary: Icon(
                _specialMessagesEnabled
                    ? Icons.auto_fix_high
                    : Icons.auto_fix_high_outlined,
                color: _specialMessagesEnabled
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

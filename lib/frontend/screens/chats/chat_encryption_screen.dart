import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/storage/chat_encryption_store.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/animated_slash_icon.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/primary_loading_button.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';
import '../../../core/config/app_fonts.dart';

class ChatEncryptionScreen extends StatefulWidget {
  final int accountId;
  final int chatId;

  const ChatEncryptionScreen({
    super.key,
    required this.accountId,
    required this.chatId,
  });

  @override
  State<ChatEncryptionScreen> createState() => _ChatEncryptionScreenState();
}

class _ChatEncryptionScreenState extends State<ChatEncryptionScreen> {
  final _keyController = TextEditingController();
  final ValueNotifier<bool> _saving = ValueNotifier(false);

  bool _loading = true;
  bool _enabled = false;
  bool _keyVisible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _saving.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = ChatEncryptionStore.instance;
    await store.load();
    final key = await store.readKey(widget.accountId, widget.chatId);
    if (!mounted) return;
    setState(() {
      _enabled = store.isEnabled(widget.accountId, widget.chatId);
      _keyController.text = key ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (widget.accountId == 0) {
      showCustomNotification(context, 'Профиль ещё не загружен');
      return;
    }
    final key = _keyController.text.trim();
    if (_enabled && key.isEmpty) {
      showCustomNotification(context, 'Введите ключ шифрования');
      return;
    }
    _saving.value = true;
    final store = ChatEncryptionStore.instance;
    if (key.isEmpty) {
      await store.deleteKey(widget.accountId, widget.chatId);
    } else {
      await store.writeKey(widget.accountId, widget.chatId, key);
    }
    await store.setEnabled(widget.accountId, widget.chatId, _enabled);
    if (!mounted) return;
    _saving.value = false;
    showCustomNotification(
      context,
      _enabled ? 'Шифрование включено' : 'Шифрование отключено',
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurface, weight: 400),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Шифрование сообщений',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: displayFontOf(context),
          ),
        ),
      ),
      body: _loading
          ? Center(child: SmallSpinner(size: 36, color: cs.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsCard(
                    children: [
                      SettingsToggleTile(
                        icon: _enabled ? Symbols.lock : Symbols.lock_open,
                        label: 'Шифровать сообщения',
                        subtitle:
                            'Текст сообщений в этом чате будет зашифрован '
                            'ключом ниже',
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GlossyPill(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(20),
                    depth: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ключ',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _keyController,
                          obscureText: !_keyVisible,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: InputDecoration(
                            hintText: 'Введите ключ',
                            filled: true,
                            fillColor: cs.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              icon: AnimatedSlashIcon(
                                icon: Symbols.visibility,
                                slashedIcon: Symbols.visibility_off,
                                slashed: _keyVisible,
                                color: cs.onSurfaceVariant,
                              ),
                              onPressed: () =>
                                  setState(() => _keyVisible = !_keyVisible),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ключ хранится только на этом устройстве. '
                          'Собеседник должен ввести такой же ключ, иначе он '
                          'не прочитает сообщения.',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryLoadingButton(
                      loading: _saving,
                      onPressed: _save,
                      child: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

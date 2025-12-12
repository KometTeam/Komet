import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gwid/services/chat_encryption_service.dart';

class ChatEncryptionSettingsScreen extends StatefulWidget {
  final int chatId;
  final bool isPasswordSet;

  const ChatEncryptionSettingsScreen({
    super.key,
    required this.chatId,
    required this.isPasswordSet,
  });

  @override
  State<ChatEncryptionSettingsScreen> createState() =>
      _ChatEncryptionSettingsScreenState();
}

class _ChatEncryptionSettingsScreenState
    extends State<ChatEncryptionSettingsScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _sendEncrypted = true;
  bool _isPasswordCurrentlySet = false;

  @override
  void initState() {
    super.initState();
    _sendEncrypted = true;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final cfg = await ChatEncryptionService.getConfigForChat(widget.chatId);
    if (!mounted) return;
    if (cfg != null) {
      _passwordController.text = cfg.password;
      _isPasswordCurrentlySet = cfg.password.isNotEmpty;
      _sendEncrypted = cfg.sendEncrypted;
    } else {
      _isPasswordCurrentlySet = widget.isPasswordSet;
      _sendEncrypted = true;
    }
    setState(() {});
  }

  Future<void> _savePassword() async {
    final password = _passwordController.text;
    
    final effectiveSendEncrypted =
        password.isNotEmpty ? _sendEncrypted : false;

    await ChatEncryptionService.setPasswordForChat(widget.chatId, password);
    await ChatEncryptionService.setSendEncryptedForChat(
      widget.chatId,
      effectiveSendEncrypted,
    );
    if (!mounted) return;
    setState(() {
      _isPasswordCurrentlySet = password.isNotEmpty;
      _sendEncrypted = effectiveSendEncrypted;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Пароль шифрования сохранён'),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пароль от шифрования'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID чата: ${widget.chatId}',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lock),
                const SizedBox(width: 8),
                Text(
                  _isPasswordCurrentlySet
                      ? 'Пароль шифрования установлен'
                      : 'Пароль шифрования не установлен',
                  style: textTheme.bodyMedium?.copyWith(
                    color: _isPasswordCurrentlySet ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль от шифрования',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Отправлять зашифрованные сообщения в этом чате'),
              value: _sendEncrypted,
              onChanged: _isPasswordCurrentlySet
                  ? (value) {
                      setState(() {
                        _sendEncrypted = value;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              'Пароль от расшифровки ЧУЖИХ сообщений будет тот же что и ваш',
              style: GoogleFonts.manrope(
                textStyle: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _savePassword,
                child: const Text('Сохранить пароль'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ТУТОРИАЛ',
              style: GoogleFonts.manrope(
                textStyle: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Согласуйте с другим человеком пароль. Если вы хотите обмениваться зашифрованными сообщениями друг с другом, у вас на чатах должен стоять один и тот же пароль.',
              style: GoogleFonts.manrope(
                textStyle: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';

class PasswordManagementScreen extends StatefulWidget {
  const PasswordManagementScreen({super.key});

  @override
  State<PasswordManagementScreen> createState() =>
      _PasswordManagementScreenState();
}

class _PasswordManagementScreenState extends State<PasswordManagementScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _hintController = TextEditingController();

  StreamSubscription? _apiSubscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _listenToApiMessages();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _hintController.dispose();
    _apiSubscription?.cancel();
    super.dispose();
  }

  void _listenToApiMessages() {
    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (!mounted) return;

      if (message['type'] == 'password_set_success') {
        setState(() {
          _isLoading = false;
        });

        _clearFields();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Пароль успешно установлен!'),
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
          ),
        );
      }

      if (message['cmd'] == 3 && message['opcode'] == 116) {
        setState(() {
          _isLoading = false;
        });

        final errorPayload = message['payload'];
        String errorMessage = 'Неизвестная ошибка';
        if (errorPayload != null) {
          if (errorPayload['localizedMessage'] != null) {
            errorMessage = errorPayload['localizedMessage'];
          } else if (errorPayload['message'] != null) {
            errorMessage = errorPayload['message'];
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    });
  }

  void _clearFields() {
    _passwordController.clear();
    _confirmPasswordController.clear();
    _hintController.clear();
  }

  void _setPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final hint = _hintController.text.trim();

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Введите пароль'),
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Пароль должен содержать минимум 6 символов'),
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    if (password.length > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Пароль не должен превышать 30 символов'),
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    if (!password.contains(RegExp(r'[A-Z]')) ||
        !password.contains(RegExp(r'[a-z]'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Пароль должен содержать заглавные и строчные буквы',
          ),
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Пароль должен содержать цифры'),
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Пароль должен содержать специальные символы (!@#\$%^&*)',
          ),
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Пароли не совпадают'),
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.instance.setAccountPassword(password, hint);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка установки пароля: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Пароль аккаунта')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: colors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Пароль аккаунта',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Пароль добавляет дополнительную защиту к вашему аккаунту. '
                        'После установки пароля для входа потребуется не только SMS-код, '
                        'но и пароль.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Установить пароль',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Новый пароль',
                    hintText: 'Введите пароль',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Подтвердите пароль',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _hintController,
                  decoration: InputDecoration(
                    labelText: 'Подсказка для пароля (необязательно)',
                    hintText: 'Например: "Мой любимый цвет"',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lightbulb_outline),
                  ),
                  maxLength: 30,
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Требования к паролю:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Не менее 6 символов\n'
                        '• Содержать заглавные и строчные буквы\n'
                        '• Включать цифры и специальные символы (!@#\$%^&*)\n'
                        '• Максимум 30 символов',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _setPassword,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.onPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.lock),
                    label: Text(
                      _isLoading ? 'Установка...' : 'Установить пароль',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

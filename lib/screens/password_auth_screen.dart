import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/screens/home_screen.dart';
import 'package:gwid/screens/phone_entry_screen.dart';
import 'package:gwid/services/whitelist_service.dart';
import 'package:gwid/app_sizes.dart';

class PasswordAuthScreen extends StatefulWidget {
  const PasswordAuthScreen({super.key});

  @override
  State<PasswordAuthScreen> createState() => _PasswordAuthScreenState();
}

class _PasswordAuthScreenState extends State<PasswordAuthScreen> {
  final TextEditingController _passwordController = TextEditingController();
  StreamSubscription? _apiSubscription;
  bool _isLoading = false;
  String? _hint;
  String? _email;

  @override
  void initState() {
    super.initState();

    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (message['type'] == 'password_required' && mounted) {
        setState(() {
          _hint = message['hint'];
          _email = message['email'];
        });
      }

      if (message['opcode'] == 115 && message['cmd'] == 1 && mounted) {
        final payload = message['payload'];
        if (payload != null &&
            payload['tokenAttrs']?['LOGIN']?['token'] != null) {
          final String finalToken = payload['tokenAttrs']['LOGIN']['token'];
          final userId = payload['tokenAttrs']?['LOGIN']?['userId'];

          print(
            'Успешная аутентификация паролем! Токен: $finalToken, UserID: $userId',
          );

          (() async {
            if (!mounted) return;
            setState(() => _isLoading = true);

            try {
              await ApiService.instance.saveToken(
                finalToken,
                userId: userId?.toString(),
              );

              final chatsResult = ApiService.instance.lastChatsPayload;
              int? userIdInt;
              if (chatsResult != null) {
                final profileJson = chatsResult['profile'];
                if (profileJson != null) {
                  final profile = Profile.fromJson(profileJson);
                  userIdInt = profile.id;
                }
              }
              if (userIdInt == null && userId != null) {
                userIdInt = int.tryParse(userId);
              }

              final whitelistService = WhitelistService();
              final isAllowed = await whitelistService.checkAndValidate(
                userIdInt,
              );

              if (!isAllowed) {
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const PhoneEntryScreen(),
                    ),
                    (route) => false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('АЛО ТЫ НЕ В ВАЙТЛИСТЕ'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
                return;
              }

              ApiService.instance.clearPasswordAuthData();

              if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Пароль верный! Вход выполнен.'),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdBorder,
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(AppSpacing.lg),
                  ),
                );

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              }
            } catch (e) {
              if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка входа: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          })();
        }
      }

      if (message['opcode'] == 115 && message['cmd'] == 3 && mounted) {
        setState(() {
          _isLoading = false;
        });

        final error = message['payload'];
        String errorMessage = 'Ошибка аутентификации';

        if (error != null) {
          if (error['localizedMessage'] != null) {
            errorMessage = error['localizedMessage'];
          } else if (error['message'] != null) {
            errorMessage = error['message'];
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdBorder,
            ),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(AppSpacing.lg),
          ),
        );
      }
    });

    final authData = ApiService.instance.getPasswordAuthData();
    _hint = authData['hint'];
    _email = authData['email'];
  }

  void _submitPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Введите пароль'),
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdBorder,
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(AppSpacing.lg),
        ),
      );
      return;
    }

    final authData = ApiService.instance.getPasswordAuthData();
    final trackId = authData['trackId'];

    if (trackId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ошибка: отсутствует идентификатор сессии'),
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdBorder,
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(AppSpacing.lg),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.instance.sendPassword(trackId, password);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отправки пароля: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdBorder,
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(AppSpacing.lg),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ввод пароля'),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_email != null)
                    Container(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: AppRadius.mdBorder,
                        border: Border.all(
                          color: colors.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Аккаунт защищен паролем',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: AppFontSize.xl,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _email!,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: AppFontSize.lg,
                            ),
                          ),
                          if (_hint != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Подсказка: $_hint',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: AppFontSize.lg,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSpacing.xxxl * 1.5),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      hintText: 'Введите пароль от аккаунта',
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.mdBorder,
                      ),
                      prefixIcon: const Icon(Icons.lock),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                    ),
                    onSubmitted: (_) => _submitPassword(),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  SizedBox(
                    width: double.infinity,
                    height: AppAccessibility.buttonMinHeight,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submitPassword,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdBorder,
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: AppIconSize.md,
                              height: AppIconSize.md,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Войти'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _apiSubscription?.cancel();
    super.dispose();
  }
}

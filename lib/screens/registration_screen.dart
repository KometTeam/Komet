import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/screens/home_screen.dart';
import 'package:gwid/screens/phone_entry_screen.dart';
import 'package:gwid/services/whitelist_service.dart';

class RegistrationScreen extends StatefulWidget {
  final String registerToken;
  final String phoneNumber;

  const RegistrationScreen({
    super.key,
    required this.registerToken,
    required this.phoneNumber,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final FocusNode _firstNameFocusNode = FocusNode();
  final FocusNode _lastNameFocusNode = FocusNode();
  StreamSubscription? _apiSubscription;
  bool _isLoading = false;
  bool _isNavigating = false;
  bool _isButtonEnabled = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    _firstNameController.addListener(_checkFields);
    _lastNameController.addListener(_checkFields);

    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (message['opcode'] == 23 && mounted && !_isNavigating) {
        _isNavigating = true;
        print('Получен ответ opcode 23 (регистрация), полное сообщение: $message');
        
        final payload = message['payload'];
        print('Payload при регистрации: $payload');

        if (payload != null && payload['error'] != null) {
          final error = payload['error'];
          print('Ошибка регистрации: $error');
          
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isNavigating = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка регистрации: $error'),
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
          return;
        }

        String? finalToken;
        String? userId;

        if (payload != null) {
          finalToken = payload['token'];
          userId = payload['userId']?.toString();
        }
        
        if (finalToken == null && message['token'] != null) {
          finalToken = message['token']?.toString();
        }
        if (userId == null && message['userId'] != null) {
          userId = message['userId']?.toString();
        }
        
        if (finalToken != null) {
          print('Найден токен регистрации: ${finalToken.substring(0, 20)}..., UserID: $userId');
        }

        if (finalToken != null) {
          print('Успешная регистрация! Токен: ${finalToken.substring(0, 20)}..., UserID: $userId');

          SchedulerBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            setState(() => _isLoading = true);

            try {
              print('Начинаем сохранение токена после регистрации...');
              await ApiService.instance.saveToken(finalToken!, userId: userId);
              print('Токен сохранен, переподключение завершено');

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

              if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Регистрация завершена! Добро пожаловать!'),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(10),
                  ),
                );
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              }
            } catch (e, stackTrace) {
              print('Ошибка при регистрации: $e');
              print('StackTrace: $stackTrace');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isNavigating = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка при регистрации: ${e.toString()}'),
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
          });
        } else {
          print('Токен не найден в ответе регистрации');
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isNavigating = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Ошибка регистрации. Попробуйте снова.'),
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
      }
    });
  }

  void _checkFields() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final enabled = firstName.isNotEmpty && lastName.isNotEmpty;
    if (enabled != _isButtonEnabled) {
      setState(() => _isButtonEnabled = enabled);
    }
  }

  void _register() async {
    if (!_isButtonEnabled || _isLoading) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Пожалуйста, заполните все поля'),
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        "firstName": firstName,
        "lastName": lastName,
        "token": widget.registerToken,
        "tokenType": "REGISTER",
      };

      print('Отправляем регистрацию с payload: $payload');
      await ApiService.instance.sendRawRequest(23, payload);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подключения: ${e.toString()}'),
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
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(colors.surface, colors.primary, 0.05)!,
              colors.surface,
              Color.lerp(colors.surface, colors.tertiary, 0.05)!,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Регистрация',
                                style: GoogleFonts.manrope(
                                  textStyle: textTheme.headlineSmall,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Создайте свой профиль',
                                style: GoogleFonts.manrope(
                                  textStyle: textTheme.bodyMedium,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          children: [
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colors.surfaceContainerHighest,
                                    colors.surfaceContainer,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colors.outline.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colors.primaryContainer
                                              .withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.person_add_outlined,
                                          color: colors.primary,
                                          size: 28,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Добро пожаловать!',
                                    style: GoogleFonts.manrope(
                                      textStyle: textTheme.titleLarge,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Номер ${widget.phoneNumber} подтверждён. Теперь заполните информацию о себе.',
                                    style: GoogleFonts.manrope(
                                      textStyle: textTheme.bodyMedium,
                                      color: colors.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    'Имя',
                                    style: GoogleFonts.manrope(
                                      textStyle: textTheme.labelLarge,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _firstNameController,
                                    focusNode: _firstNameFocusNode,
                                    autofocus: true,
                                    textCapitalization: TextCapitalization.words,
                                    style: GoogleFonts.manrope(
                                      textStyle: textTheme.titleMedium,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Введите ваше имя',
                                      prefixIcon: const Icon(Icons.person_outline),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      filled: true,
                                      fillColor: colors.surfaceContainerHighest,
                                    ),
                                    onFieldSubmitted: (_) {
                                      _lastNameFocusNode.requestFocus();
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Фамилия',
                                    style: GoogleFonts.manrope(
                                      textStyle: textTheme.labelLarge,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _lastNameController,
                                    focusNode: _lastNameFocusNode,
                                    textCapitalization: TextCapitalization.words,
                                    style: GoogleFonts.manrope(
                                      textStyle: textTheme.titleMedium,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Введите вашу фамилию',
                                      prefixIcon:
                                          const Icon(Icons.person_outline),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      filled: true,
                                      fillColor: colors.surfaceContainerHighest,
                                    ),
                                    onFieldSubmitted: (_) {
                                      if (_isButtonEnabled) {
                                        _register();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color:
                                    colors.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: colors.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Вы сможете изменить эти данные позже в настройках профиля.',
                                      style: GoogleFonts.manrope(
                                        textStyle: textTheme.bodySmall,
                                        color: colors.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _isButtonEnabled ? _register : null,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Завершить регистрацию',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Завершаем регистрацию...',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.titleMedium,
                            color: colors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _apiSubscription?.cancel();
    super.dispose();
  }
}

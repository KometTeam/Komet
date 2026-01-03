import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/screens/home_screen.dart';
import 'package:gwid/screens/password_auth_screen.dart';
import 'package:gwid/screens/phone_entry_screen.dart';
import 'package:gwid/screens/registration_screen.dart';
import 'package:gwid/services/whitelist_service.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String otpToken;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.otpToken,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  StreamSubscription? _apiSubscription;
  bool _isLoading = false;
  bool _isNavigating = false;
  bool _isShowingError = false;
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

    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (message['type'] == 'password_required' && mounted && !_isNavigating) {
        _isNavigating = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (context) => const PasswordAuthScreen(),
                  ),
                )
                .then((_) {
                  if (mounted) {
                    setState(() => _isNavigating = false);
                  }
                });
          }
        });
        return;
      }

      if (message['opcode'] == 18 && mounted && !_isNavigating) {
        _isNavigating = true;
        print('Получен ответ opcode 18, полное сообщение: $message');
        final payload = message['payload'];
        print('Payload при авторизации: $payload');

        String? finalToken;
        String? userId;
        String? registerToken;

        if (payload != null) {
          final tokenAttrs = payload['tokenAttrs'];
          print('tokenAttrs: $tokenAttrs');

          // Проверяем наличие REGISTER токена
          if (tokenAttrs != null && tokenAttrs['REGISTER'] != null) {
            registerToken = tokenAttrs['REGISTER']['token']?.toString();
            print('Найден REGISTER токен: ${registerToken?.substring(0, 20)}...');
            
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) { 
                setState(() => _isLoading = false);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => RegistrationScreen(
                      registerToken: registerToken!,
                      phoneNumber: widget.phoneNumber,
                    ),
                  ),
                );
              }
            });
            return;
          }

          // Проверяем наличие LOGIN токена
          if (tokenAttrs != null && tokenAttrs['LOGIN'] != null) {
            final loginToken = tokenAttrs['LOGIN']['token'];
            final loginUserId =
                tokenAttrs['LOGIN']['userId'] ??
                payload['payload']?['profile']?['contact']?['id'] ??
                payload['profile']?['contact']?['id'];

            if (loginToken != null) {
              finalToken = loginToken.toString();
              userId = loginUserId?.toString();
              print(
                'Найден LOGIN токен: ${finalToken.substring(0, 20)}..., UserID: $userId',
              );
            }
          }
        }

        if (finalToken != null) {
          print(
            'Успешная авторизация! Токен: ${finalToken.substring(0, 20)}..., UserID: $userId',
          );

          SchedulerBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            setState(() => _isLoading = true);

            try {
              print('Начинаем сохранение токена и переподключение...');
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
                    content: const Text('Код верный! Вход выполнен.'),
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
              print('Ошибка при переподключении: $e');
              print('StackTrace: $stackTrace');
              if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ошибка при переподключении: ${e.toString()}',
                    ),
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
          print('Токен LOGIN не найден в ответе, возможно неверный код');
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isLoading = false);
              if (!_isShowingError) {
                _handleIncorrectCode();
              }
            }
          });
        }
      }
    });
  }

  void _verifyCode(String code) async {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
    });

    try {
      await ApiService.instance.verifyCode(widget.otpToken, code);
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

  void _handleIncorrectCode() {
    if (_isShowingError) return;
    _isShowingError = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Неверный код. Попробуйте снова.'),
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
      ),
    ).closed.then((_) {
      if (mounted) {
        _isShowingError = false;
      }
    });
    _pinController.clear();
    _pinFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: GoogleFonts.manrope(
        fontSize: 22,
        color: colors.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.2), width: 1),
      ),
    );

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
                          onPressed: () => Navigator.of(context).pop(),
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
                                'Подтверждение',
                                style: GoogleFonts.manrope(
                                  textStyle: textTheme.headlineSmall,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Введите код из SMS',
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.mail_outline,
                                          color: colors.primary,
                                          size: 28,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Код отправлен',
                                    style: GoogleFonts.manrope(
                                      textStyle: textTheme.titleLarge,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Мы отправили 6-значный код на номер:',
                                    style: GoogleFonts.manrope(
                                      textStyle: textTheme.bodyMedium,
                                      color: colors.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.phoneNumber,
                                    style: GoogleFonts.manrope(
                                      textStyle: textTheme.titleMedium,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Center(
                                    child: Pinput(
                                      length: 6,
                                      controller: _pinController,
                                      focusNode: _pinFocusNode,
                                      autofocus: true,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      androidSmsAutofillMethod:
                                          AndroidSmsAutofillMethod
                                              .smsUserConsentApi,
                                      defaultPinTheme: defaultPinTheme,
                                      focusedPinTheme: defaultPinTheme.copyWith(
                                        decoration: defaultPinTheme.decoration!
                                            .copyWith(
                                              border: Border.all(
                                                color: colors.primary,
                                                width: 2,
                                              ),
                                            ),
                                      ),
                                      errorPinTheme: defaultPinTheme.copyWith(
                                        decoration: defaultPinTheme.decoration!
                                            .copyWith(
                                              border: Border.all(
                                                color: colors.error,
                                                width: 2,
                                              ),
                                            ),
                                      ),
                                      onCompleted: (pin) => _verifyCode(pin),
                                      onChanged: (value) {
                                        if (_isShowingError && value.isNotEmpty) {
                                          _isShowingError = false;
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest
                                    .withOpacity(0.5),
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
                                      'Код действителен в течение 10 минут. Если код не пришёл, проверьте правильность номера.',
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
                          'Проверяем код...',
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
    _pinController.dispose();
    _pinFocusNode.dispose();
    _apiSubscription?.cancel();
    super.dispose();
  }
}

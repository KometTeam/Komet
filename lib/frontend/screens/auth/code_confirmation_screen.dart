import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../chats/chat_list_screen.dart';
import 'password_2fa_screen.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';

class CodeConfirmationScreen extends StatefulWidget {
  final String phoneNumber;
  final String token;

  const CodeConfirmationScreen({
    super.key,
    required this.phoneNumber,
    required this.token,
  });

  @override
  State<CodeConfirmationScreen> createState() => _CodeConfirmationScreenState();
}

class _CodeConfirmationScreenState extends State<CodeConfirmationScreen>
    with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _timerSeconds = 30;
  Timer? _timer;
  Timer? _errorTimer;

  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _errorTimer?.cancel();
    _shakeController.dispose();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timerSeconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  void _showError(String message) {
    _errorTimer?.cancel();
    _shakeController.forward(from: 0);
    setState(() => _errorMessage = message);
    _errorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  void _resendCode() {
    if (_timerSeconds == 0) {
      _startTimer();
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) return;

    try {
      final result = await accountModule.verifyCode(
        _codeController.text,
        widget.token,
      );

      if (!mounted) return;

      if (result.requiresPassword) {
        final trackId = result.challengeTrackId;

        if (trackId == null) {
          showCustomNotification(context, 'Ошибка: отсутствуют данные для 2FA');
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                Password2FAScreen(trackId: trackId, hint: result.challengeHint),
          ),
        );
        return;
      }

      await accountModule.login();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ChatListScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasError = _errorMessage != null;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurfaceVariant),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                widget.phoneNumber,
                style: GoogleFonts.inter(
                  color: cs.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Мы отправили SMS с кодом подтверждения на ваш номер телефона.',
                style: TextStyle(
                  color: cs.outline,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                ),
                child: Stack(
                  children: [
                    Opacity(
                      opacity: 0,
                      child: SizedBox(
                        height: 0,
                        width: 0,
                        child: TextField(
                          controller: _codeController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (value) {
                            if (hasError) setState(() => _errorMessage = null);
                            setState(() {});
                            if (value.length == 6) _verifyCode();
                          },
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _focusNode.requestFocus(),
                      child: FittedBox(
                        child: Row(
                          children: List.generate(6, (index) {
                            final isFocused =
                                _codeController.text.length == index &&
                                _focusNode.hasFocus;
                            final hasValue =
                                _codeController.text.length > index;
                            final char = hasValue
                                ? _codeController.text[index]
                                : '';

                            Color borderColor;
                            if (hasError && hasValue) {
                              borderColor = cs.error;
                            } else if (isFocused) {
                              borderColor = cs.primary;
                            } else if (hasValue) {
                              borderColor = cs.outlineVariant;
                            } else {
                              borderColor = Colors.transparent;
                            }

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 54,
                              margin: EdgeInsets.only(
                                right: index == 5 ? 0 : 10,
                              ),
                              decoration: BoxDecoration(
                                color: hasError && hasValue
                                    ? cs.error.withValues(alpha: 0.1)
                                    : cs.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: borderColor,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 100),
                                transitionBuilder:
                                    (
                                      Widget child,
                                      Animation<double> animation,
                                    ) {
                                      return ScaleTransition(
                                        scale: animation,
                                        child: FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                      );
                                    },
                                child: Text(
                                  char,
                                  key: ValueKey<String>(
                                    char +
                                        index.toString() +
                                        (hasError ? 'e' : ''),
                                  ),
                                  style: TextStyle(
                                    color: hasError && hasValue
                                        ? cs.error
                                        : cs.onSurface,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: hasError
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AnimatedOpacity(
                          opacity: hasError ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: cs.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              GestureDetector(
                onTap: _resendCode,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: _timerSeconds > 0 ? cs.outline : cs.tertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  child: Text(
                    _timerSeconds > 0
                        ? 'Отправить повторно через $_timerSeconds сек.'
                        : 'Отправить код по SMS',
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: () {
                      if (_codeController.text.length == 6) _verifyCode();
                    },
                    backgroundColor: _codeController.text.length == 6
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      color: _codeController.text.length == 6
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

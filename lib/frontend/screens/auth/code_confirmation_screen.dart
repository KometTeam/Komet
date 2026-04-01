import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../chats/chat_list_screen.dart';
import 'password_2fa_screen.dart';
import '../../../main.dart';

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

class _CodeConfirmationScreenState extends State<CodeConfirmationScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _timerSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  void _resendCode() {
    if (_timerSeconds == 0) {
      _startTimer();
      // TODO: вызвать accountModule.resendCode
      print('Resending code to ${widget.phoneNumber}');
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: отсутствуют данные для 2FA')),
          );
          return;
        }
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => Password2FAScreen(
              trackId: trackId,
              hint: result.challengeHint,
            ),
          ),
        );
        return;
      }

      // Если 2FA не требуется, делаем login
      final loginResult = await accountModule.login();
      
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ChatListScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  void _navigateToChats() {
    _verifyCode();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              Stack(
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
                          setState(() {});
                          if (value.length == 6) {
                            _navigateToChats();
                          }
                        },
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    child:                       FittedBox(
                      child: Row(
                        children: List.generate(6, (index) {
                          bool isFocused = _codeController.text.length == index && _focusNode.hasFocus;
                          bool hasValue = _codeController.text.length > index;
                          String char = hasValue ? _codeController.text[index] : '';

                          return Container(
                            width: 44,
                            height: 54,
                            margin: EdgeInsets.only(right: index == 5 ? 0 : 10),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isFocused
                                    ? cs.primary
                                    : (hasValue ? cs.outlineVariant : Colors.transparent),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 100),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(opacity: animation, child: child),
                                );
                              },
                              child: Text(
                                char,
                                key: ValueKey<String>(char + index.toString()),
                                style: TextStyle(
                                  color: cs.onSurface,
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
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _resendCode,
                child: Text(
                  _timerSeconds > 0
                      ? 'Отправить повторно через $_timerSeconds сек.'
                      : 'Отправить код по SMS',
                  style: TextStyle(
                    color: cs.tertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: () {
                      if (_codeController.text.length == 6) {
                        _navigateToChats();
                      }
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
                      color: _codeController.text.length == 6 ? cs.onPrimaryContainer : cs.onSurfaceVariant,
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

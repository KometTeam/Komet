import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../chats/chat_list_screen.dart';
import '../../../main.dart';

class Password2FAScreen extends StatefulWidget {
  final String trackId;
  final String? hint;

  const Password2FAScreen({
    super.key,
    required this.trackId,
    this.hint,
  });

  @override
  State<Password2FAScreen> createState() => _Password2FAScreenState();
}

class _Password2FAScreenState extends State<Password2FAScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkPassword() async {
    if (_passwordController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await accountModule.checkPassword(
        password: _passwordController.text,
        trackId: widget.trackId,
      );

      if (!mounted) return;

      // После успешной 2FA делаем login
      final loginResult = await accountModule.login();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ChatListScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Неверный пароль: $e')),
      );
    }
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
                'Двухфакторная аутентификация',
                style: GoogleFonts.inter(
                  color: cs.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Введите пароль для завершения входа',
                style: TextStyle(
                  color: cs.outline,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              if (widget.hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Подсказка: ${widget.hint}',
                  style: TextStyle(
                    color: cs.tertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                autofocus: true,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Пароль',
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                onSubmitted: (_) => _checkPassword(),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: _isLoading ? null : _checkPassword,
                    backgroundColor: _passwordController.text.isNotEmpty
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : Icon(
                            Icons.arrow_forward,
                            color: _passwordController.text.isNotEmpty
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

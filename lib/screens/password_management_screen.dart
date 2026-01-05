import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';

enum TwoFAStep {
  start,
  password,
  hint,
  email,
  verifyEmail,
  complete,
}

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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  StreamSubscription? _apiSubscription;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  TwoFAStep _currentStep = TwoFAStep.start;
  String? _trackId;
  int _codeLength = 6;
  int _blockingDuration = 60;
  String? _maskedEmail;

  String _savedPassword = '';
  String _savedHint = '';

  Timer? _resendTimer;
  int _resendCountdown = 0;

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
    _emailController.dispose();
    _codeController.dispose();
    _apiSubscription?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _listenToApiMessages() {
    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (!mounted) return;

      switch (message['type']) {
        case '2fa_setup_started':
          setState(() {
            _isLoading = false;
            _trackId = message['trackId'];
            _currentStep = TwoFAStep.password;
          });
          break;

        case '2fa_password_set':
          setState(() {
            _isLoading = false;
            _currentStep = TwoFAStep.hint;
          });
          break;

        case '2fa_hint_set':
          setState(() {
            _isLoading = false;
            _currentStep = TwoFAStep.email;
          });
          break;

        case '2fa_email_set':
          setState(() {
            _isLoading = false;
            _blockingDuration = message['blockingDuration'] ?? 60;
            _codeLength = message['codeLength'] ?? 6;
            _currentStep = TwoFAStep.verifyEmail;
            _startResendTimer();
          });
          break;

        case '2fa_email_verified':
          setState(() {
            _maskedEmail = message['email'];
          });
          _confirmSetup();
          break;

        case '2fa_setup_complete':
          setState(() {
            _isLoading = false;
            _currentStep = TwoFAStep.complete;
          });
          _showSuccessSnackBar('Двухфакторная аутентификация успешно включена!');
          break;

        case '2fa_error':
          setState(() {
            _isLoading = false;
          });
          _handleError(message);
          break;
      }
    });
  }

  void _handleError(Map<String, dynamic> message) {
    final payload = message['payload'];
    String errorMessage = 'Произошла ошибка';

    if (payload != null) {
      if (payload['localizedMessage'] != null) {
        errorMessage = payload['localizedMessage'];
      } else if (payload['message'] != null) {
        errorMessage = payload['message'];
      }
    }

    _showErrorSnackBar(errorMessage);
  }

  void _startResendTimer() {
    _resendCountdown = _blockingDuration;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  // Step 1: Start 2FA setup
  void _startSetup() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.instance.start2FASetup();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Ошибка: ${e.toString()}');
    }
  }

  // Step 2: Set password
  void _setPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!_validatePassword(password, confirmPassword)) return;

    _savedPassword = password;

    setState(() => _isLoading = true);
    try {
      await ApiService.instance.set2FAPassword(_trackId!, password);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Ошибка: ${e.toString()}');
    }
  }

  bool _validatePassword(String password, String confirmPassword) {
    if (password.isEmpty) {
      _showWarningSnackBar('Введите пароль');
      return false;
    }

    if (password.length < 6) {
      _showWarningSnackBar('Пароль должен содержать минимум 6 символов');
      return false;
    }

    if (password.length > 30) {
      _showWarningSnackBar('Пароль не должен превышать 30 символов');
      return false;
    }

    if (!password.contains(RegExp(r'[A-Z]')) ||
        !password.contains(RegExp(r'[a-z]'))) {
      _showWarningSnackBar(
        'Пароль должен содержать заглавные и строчные буквы',
      );
      return false;
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      _showWarningSnackBar('Пароль должен содержать цифры');
      return false;
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      _showWarningSnackBar(
        'Пароль должен содержать специальные символы (!@#\$%^&*)',
      );
      return false;
    }

    if (password != confirmPassword) {
      _showWarningSnackBar('Пароли не совпадают');
      return false;
    }

    return true;
  }

  // Step 3: Set hint
  void _setHint() async {
    final hint = _hintController.text.trim();
    _savedHint = hint;

    setState(() => _isLoading = true);
    try {
      await ApiService.instance.set2FAHint(_trackId!, hint);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Ошибка: ${e.toString()}');
    }
  }

  // Step 4: Set email
  void _setEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showWarningSnackBar('Введите email');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showWarningSnackBar('Введите корректный email');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.instance.set2FAEmail(_trackId!, email);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Ошибка: ${e.toString()}');
    }
  }

  // Step 5: Verify email code
  void _verifyEmailCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showWarningSnackBar('Введите код');
      return;
    }

    if (code.length != _codeLength) {
      _showWarningSnackBar('Код должен содержать $_codeLength символов');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.instance.verify2FAEmailCode(_trackId!, code);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Ошибка: ${e.toString()}');
    }
  }

  // Step 6: Confirm setup
  void _confirmSetup() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.instance.confirm2FASetup(
        _trackId!,
        _savedPassword,
        _savedHint,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Ошибка: ${e.toString()}');
    }
  }

  void _resendCode() async {
    if (_resendCountdown > 0) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.instance.set2FAEmail(_trackId!, _emailController.text.trim());
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Ошибка: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Двухфакторная аутентификация'),
        leading: _currentStep != TwoFAStep.start && _currentStep != TwoFAStep.complete
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _isLoading ? null : () => _goBack(),
              )
            : null,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: _buildCurrentStep(colors),
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

  void _goBack() {
    setState(() {
      switch (_currentStep) {
        case TwoFAStep.password:
          _currentStep = TwoFAStep.start;
          _trackId = null;
          break;
        case TwoFAStep.hint:
          _currentStep = TwoFAStep.password;
          break;
        case TwoFAStep.email:
          _currentStep = TwoFAStep.hint;
          break;
        case TwoFAStep.verifyEmail:
          _currentStep = TwoFAStep.email;
          _resendTimer?.cancel();
          break;
        default:
          break;
      }
    });
  }

  Widget _buildCurrentStep(ColorScheme colors) {
    switch (_currentStep) {
      case TwoFAStep.start:
        return _buildStartStep(colors);
      case TwoFAStep.password:
        return _buildPasswordStep(colors);
      case TwoFAStep.hint:
        return _buildHintStep(colors);
      case TwoFAStep.email:
        return _buildEmailStep(colors);
      case TwoFAStep.verifyEmail:
        return _buildVerifyEmailStep(colors);
      case TwoFAStep.complete:
        return _buildCompleteStep(colors);
    }
  }

  Widget _buildStepIndicator(ColorScheme colors) {
    final steps = ['Пароль', 'Подсказка', 'Email', 'Код', 'Готово'];
    final currentIndex = _currentStep.index - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index <= currentIndex;
          final isCurrent = index == currentIndex;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index <= currentIndex
                              ? colors.primary
                              : colors.outline.withValues(alpha: 0.3),
                        ),
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? colors.primary : colors.surfaceContainerHighest,
                        border: isCurrent
                            ? Border.all(color: colors.primary, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isActive && index < currentIndex
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: colors.onPrimary,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? colors.onPrimary
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < currentIndex
                              ? colors.primary
                              : colors.outline.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? colors.primary : colors.onSurfaceVariant,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStartStep(ColorScheme colors) {
    return Column(
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
                  Icon(Icons.security, color: colors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Защитите свой аккаунт',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Двухфакторная аутентификация добавляет дополнительный уровень защиты. '
                'После включения для входа в аккаунт потребуется не только SMS-код, '
                'но и пароль.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoCard(
          colors,
          icon: Icons.lock_outline,
          title: 'Надёжный пароль',
          description: 'Придумайте пароль с заглавными и строчными буквами, цифрами и специальными символами',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          colors,
          icon: Icons.lightbulb_outline,
          title: 'Подсказка',
          description: 'Добавьте подсказку, которая поможет вспомнить пароль',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          colors,
          icon: Icons.email_outlined,
          title: 'Email для восстановления',
          description: 'Укажите email для восстановления доступа к аккаунту',
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _startSetup,
            icon: const Icon(Icons.security),
            label: const Text('Включить двухфакторную аутентификацию'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(colors),
        Text(
          'Создайте пароль',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Придумайте надёжный пароль для защиты аккаунта',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Пароль',
            hintText: 'Введите пароль',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Подтвердите пароль',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildPasswordRequirements(colors),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _setPassword,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Продолжить'),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.primary),
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
            '• От 6 до 30 символов\n'
            '• Заглавные и строчные буквы\n'
            '• Цифры\n'
            '• Специальные символы (!@#\$%^&*)',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintStep(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(colors),
        Text(
          'Добавьте подсказку',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Подсказка поможет вспомнить пароль, если вы его забудете',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _hintController,
          decoration: InputDecoration(
            labelText: 'Подсказка для пароля',
            hintText: 'Например: "Мой любимый цвет"',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.lightbulb_outline),
          ),
          maxLength: 30,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.tertiaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.tips_and_updates, color: colors.tertiary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Подсказка будет видна при вводе пароля. Не используйте сам пароль в качестве подсказки.',
                  style: TextStyle(
                    color: colors.onTertiaryContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _setHint,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Продолжить'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailStep(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(colors),
        Text(
          'Email для восстановления',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Укажите email для восстановления доступа к аккаунту',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'example@mail.com',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user, color: colors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'На указанный email будет отправлен код подтверждения',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _setEmail,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Отправить код'),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyEmailStep(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(colors),
        Text(
          'Подтвердите email',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Введите $_codeLength-значный код, отправленный на ${_emailController.text}',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: _codeLength,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: '• ' * _codeLength,
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _resendCountdown > 0 ? null : _resendCode,
            child: Text(
              _resendCountdown > 0
                  ? 'Отправить повторно через $_resendCountdown сек'
                  : 'Отправить код повторно',
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyEmailCode,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Подтвердить'),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteStep(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Готово!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Двухфакторная аутентификация успешно включена',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          if (_maskedEmail != null) ...[
            const SizedBox(height: 8),
            Text(
              'Email для восстановления: $_maskedEmail',
              style: TextStyle(color: colors.primary, fontSize: 14),
            ),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Готово'),
            ),
          ),
        ],
      ),
    );
  }
}

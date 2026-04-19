import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart' show accountModule;
import '../../../backend/modules/account.dart' show TwoFactorDetails;
import '../../../core/storage/app_database.dart';
import '../../widgets/custom_notification.dart';

class PasswordEntryScreen extends StatefulWidget {
  const PasswordEntryScreen({super.key});

  @override
  State<PasswordEntryScreen> createState() => _PasswordEntryScreenState();
}

class _PasswordEntryScreenState extends State<PasswordEntryScreen> {
  bool _isLoading = true;
  bool _is2faEnabled = false;
  String? _email;
  String? _hint;

  @override
  void initState() {
    super.initState();
    _check2faStatus();
  }

  Future<void> _check2faStatus() async {
    try {
      final profile = await AppDatabase.loadActiveProfile();
      if (mounted) {
        setState(() {
          _is2faEnabled = profile?.profileOptions?.contains(2) ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Ошибка: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildAppBar(context, cs)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildMainSection(cs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Symbols.arrow_back,
              color: cs.onSurface,
              size: 24,
              weight: 400,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            'Пароль для входа',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSection(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _is2faEnabled ? Symbols.lock : Symbols.lock_open,
                    color: cs.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _is2faEnabled
                            ? 'Пароль установлен'
                            : 'Пароль не установлен',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _is2faEnabled
                            ? 'Используется для дополнительной защиты'
                            : 'Двухфакторная аутентификация',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
          _buildActionRow(
            cs,
            icon: Symbols.settings,
            label: _is2faEnabled ? 'Изменить пароль' : 'Установить пароль',
            isLast: _is2faEnabled,
            onTap: () => _navigateToPasswordSetup(context, cs),
          ),
          if (_is2faEnabled) ...[
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
            _buildActionRow(
              cs,
              icon: Icons.email_outlined,
              label: 'Изменить почту',
              isLast: false,
              onTap: () => _navigateToEmailChange(context, cs),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
            _buildActionRow(
              cs,
              icon: Icons.delete_outline,
              label: 'Удалить пароль',
              isLast: true,
              textColor: cs.error,
              onTap: () => _showRemoveConfirmation(context, cs),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required bool isLast,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: textColor ?? cs.onSurfaceVariant,
                    size: 22,
                    weight: 400,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: textColor ?? cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Symbols.chevron_right,
                    color: cs.outline,
                    size: 20,
                    weight: 400,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }

  void _navigateToPasswordSetup(BuildContext context, ColorScheme cs) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TwoFactorSetupScreen()),
    );
  }

  void _navigateToEmailChange(BuildContext context, ColorScheme cs) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TwoFactorEmailChangeScreen(),
      ),
    );
  }

  void _showRemoveConfirmation(BuildContext context, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить пароль?', style: TextStyle(color: cs.onSurface)),
        content: Text(
          'Вы уверены, что хотите удалить пароль для входа? Это ослабит защиту вашего аккаунта.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: cs.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TwoFactorRemoveScreen(),
                ),
              );
            },
            child: Text('Удалить', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }
}

class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final _passwordController = TextEditingController();
  final _hintController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  int _step = 0;
  bool _isLoading = false;
  String? _trackId;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _hintController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (_step) {
        case 0:
          final trackId = await accountModule.create2faTrack();
          setState(() {
            _trackId = trackId;
            _step = 1;
          });
          break;
        case 1:
          if (_passwordController.text.length < 6) {
            setState(
              () => _errorMessage = 'Пароль должен быть минимум 6 символов',
            );
            break;
          }
          await accountModule.set2faPassword(
            _trackId!,
            _passwordController.text,
          );
          setState(() => _step = 2);
          break;
        case 2:
          if (_hintController.text.isNotEmpty) {
            await accountModule.set2faHint(_trackId!, _hintController.text);
          }
          setState(() => _step = 3);
          break;
        case 3:
          if (!_emailController.text.contains('@')) {
            setState(() => _errorMessage = 'Введите корректный email');
            break;
          }
          await accountModule.verify2faEmail(_trackId!, _emailController.text);
          setState(() => _step = 4);
          break;
        case 4:
          if (_codeController.text.length != 6) {
            setState(() => _errorMessage = 'Введите 6-значный код');
            break;
          }
          await accountModule.verify2faCode(_trackId!, _codeController.text);
          await accountModule.confirm2fa(
            trackId: _trackId!,
            password: _passwordController.text,
            hint: _hintController.text.isEmpty ? null : _hintController.text,
          );
          if (mounted) {
            showCustomNotification(context, 'Пароль установлен');
            Navigator.popUntil(
              context,
              (route) =>
                  route.isFirst || route.settings.name == 'SecurityScreen',
            );
          }
          break;
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Установка пароля',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildStepContent(cs),
    );
  }

  Widget _buildStepContent(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIndicator(cs),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Symbols.error, color: cs.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: cs.onErrorContainer,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildCurrentStep(cs),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _nextStep,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : Text(_step == 4 ? 'Установить пароль' : 'Продолжить'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme cs) {
    final steps = ['Пароль', 'Подсказка', 'Почта', 'Код', 'Готово'];
    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index <= _step;
        final isCurrent = index == _step;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? cs.primary : cs.surfaceContainerHighest,
                ),
                child: Center(
                  child: isActive
                      ? Icon(Symbols.check, color: cs.onPrimary, size: 16)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[index],
                style: TextStyle(
                  color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep(ColorScheme cs) {
    switch (_step) {
      case 0:
        return _buildPasswordField(cs);
      case 1:
        return _buildPasswordConfirmField(cs);
      case 2:
        return _buildHintField(cs);
      case 3:
        return _buildEmailField(cs);
      case 4:
        return _buildCodeField(cs);
      default:
        return const SizedBox();
    }
  }

  Widget _buildPasswordField(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Придумайте пароль',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Минимум 6 символов',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Введите пароль',
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordConfirmField(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Подтвердите пароль',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Введите пароль ещё раз',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Повторите пароль',
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHintField(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Подсказка для пароля',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Необязательно',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _hintController,
          decoration: InputDecoration(
            hintText: 'Введите подсказку (необязательно)',
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Привяжите email',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Для восстановления пароля',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'example@mail.ru',
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeField(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Введите код',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Код отправлен на ${_emailController.text}',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class TwoFactorManageScreen extends StatefulWidget {
  const TwoFactorManageScreen({super.key});

  @override
  State<TwoFactorManageScreen> createState() => _TwoFactorManageScreenState();
}

class _TwoFactorManageScreenState extends State<TwoFactorManageScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _trackId;
  TwoFactorDetails? _details;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _trackId = await accountModule.enter2faPanel();
      await accountModule.check2faPassword(_trackId!, _passwordController.text);
      final details = await accountModule.get2faDetails(_trackId!);
      setState(() {
        _isAuthenticated = true;
        _details = details;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Неверный пароль');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Управление паролем',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isAuthenticated ? _buildManageContent(cs) : _buildAuthContent(cs),
    );
  }

  Widget _buildAuthContent(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Введите текущий пароль',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Пароль',
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _authenticate,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Text('Продолжить'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageContent(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(Symbols.lock, color: cs.primary, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Пароль установлен',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_details?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _details!.email!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                ],
                if (_details?.hint != null && _details!.hint!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Подсказка: ${_details!.hint}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TwoFactorPasswordChangeScreen(),
                  ),
                );
              },
              icon: const Icon(Symbols.edit),
              label: const Text('Изменить пароль'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.outline),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TwoFactorPasswordChangeScreen extends StatefulWidget {
  const TwoFactorPasswordChangeScreen({super.key});

  @override
  State<TwoFactorPasswordChangeScreen> createState() =>
      _TwoFactorPasswordChangeScreenState();
}

class _TwoFactorPasswordChangeScreenState
    extends State<TwoFactorPasswordChangeScreen> {
  final _passwordController = TextEditingController();
  final _hintController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Пароль должен быть минимум 6 символов');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trackId = await accountModule.enter2faPanel();
      await accountModule.check2faPassword(trackId, _passwordController.text);
      await accountModule.update2faPassword(
        trackId: trackId,
        newPassword: _passwordController.text,
        hint: _hintController.text.isEmpty ? null : _hintController.text,
      );
      if (mounted) {
        showCustomNotification(context, 'Пароль изменён');
        Navigator.popUntil(
          context,
          (route) => route.isFirst || route.settings.name == 'SecurityScreen',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Изменить пароль',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Новый пароль',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Введите новый пароль',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Подсказка',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hintController,
              decoration: InputDecoration(
                hintText: 'Введите подсказку (необязательно)',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _changePassword,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TwoFactorEmailChangeScreen extends StatefulWidget {
  const TwoFactorEmailChangeScreen({super.key});

  @override
  State<TwoFactorEmailChangeScreen> createState() =>
      _TwoFactorEmailChangeScreenState();
}

class _TwoFactorEmailChangeScreenState
    extends State<TwoFactorEmailChangeScreen> {
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  int _step = 0;
  bool _isLoading = false;
  String? _trackId;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (_step) {
        case 0:
          _trackId = await accountModule.enter2faPanel();
          await accountModule.check2faPassword(
            _trackId!,
            _passwordController.text,
          );
          setState(() => _step = 1);
          break;
        case 1:
          if (!_emailController.text.contains('@')) {
            setState(() => _errorMessage = 'Введите корректный email');
            break;
          }
          await accountModule.verify2faEmail(_trackId!, _emailController.text);
          setState(() => _step = 2);
          break;
        case 2:
          if (_codeController.text.length != 6) {
            setState(() => _errorMessage = 'Введите 6-значный код');
            break;
          }
          await accountModule.verify2faCode(_trackId!, _codeController.text);
          await accountModule.update2faEmail(
            trackId: _trackId!,
            email: _emailController.text,
            code: _codeController.text,
          );
          if (mounted) {
            showCustomNotification(context, 'Почта изменена');
            Navigator.popUntil(
              context,
              (route) =>
                  route.isFirst || route.settings.name == 'SecurityScreen',
            );
          }
          break;
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Изменить почту',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_step == 0) ...[
              Text(
                'Введите текущий пароль',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Пароль',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ] else ...[
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                ),
              if (_step == 1) ...[
                Text(
                  'Новая почта',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'example@mail.ru',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Введите код',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Код отправлен на ${_emailController.text}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _nextStep,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : Text(_step == 2 ? 'Сохранить' : 'Продолжить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TwoFactorRemoveScreen extends StatefulWidget {
  const TwoFactorRemoveScreen({super.key});

  @override
  State<TwoFactorRemoveScreen> createState() => _TwoFactorRemoveScreenState();
}

class _TwoFactorRemoveScreenState extends State<TwoFactorRemoveScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _remove2fa() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trackId = await accountModule.enter2faPanel();
      await accountModule.check2faPassword(trackId, _passwordController.text);
      await accountModule.remove2fa(trackId);
      if (mounted) {
        showCustomNotification(context, 'Пароль удалён');
        Navigator.popUntil(
          context,
          (route) => route.isFirst || route.settings.name == 'SecurityScreen',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Удаление пароля',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Symbols.warning, color: cs.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Внимание! После удаления пароля защита вашего аккаунта ослабнет.',
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Введите пароль для подтверждения',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Пароль',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _remove2fa,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onError,
                        ),
                      )
                    : const Text('Удалить пароль'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

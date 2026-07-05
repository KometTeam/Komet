import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart' show accountModule;
import '../../../backend/modules/account.dart' show TwoFactorDetails;
import '../../../core/storage/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/primary_loading_button.dart';

class PasswordEntryScreen extends StatefulWidget {
  const PasswordEntryScreen({super.key});

  @override
  State<PasswordEntryScreen> createState() => _PasswordEntryScreenState();
}

class _PasswordEntryScreenState extends State<PasswordEntryScreen> {
  bool _isLoading = true;
  bool _is2faEnabled = false;
  bool _isAuthenticated = false;
  TwoFactorDetails? _details;

  final _passwordController = TextEditingController();
  final ValueNotifier<bool> _isVerifying = ValueNotifier(false);
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _check2faStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _isVerifying.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_passwordController.text.isEmpty) return;
    _isVerifying.value = true;
    setState(() => _errorMessage = null);
    try {
      final trackId = await accountModule.enter2faPanel();
      await accountModule.check2faPassword(trackId, _passwordController.text);
      final details = await accountModule.get2faDetails(trackId);
      if (!mounted) return;
      setState(() {
        _isAuthenticated = true;
        _details = details;
      });
      _passwordController.clear();
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(
            context,
          )!.passwordEntryWrongPassword,
        );
      }
    } finally {
      if (mounted) _isVerifying.value = false;
    }
  }

  Future<String?> _promptPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.passwordEntryConfirmTitle),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.passwordEntryCurrentPasswordHint,
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.spoofDialogCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(l10n.passwordEntryContinue),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openWithPassword(
    Widget Function(String password) builder,
  ) async {
    final password = await _promptPassword();
    if (password == null || password.isEmpty || !mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => builder(password)));
  }

  Future<void> _check2faStatus() async {
    try {
      bool is2faEnabled;
      try {
        is2faEnabled = (await accountModule.get2faStatus()).enabled;
      } catch (_) {
        final profile = await AppDatabase.loadActiveProfile();
        is2faEnabled = profile?.profileOptions?.contains(2) ?? false;
      }
      if (mounted) {
        setState(() {
          _is2faEnabled = is2faEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.contactProfileLoadError(e.toString()),
        );
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
                child: _buildBody(cs),
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
            AppLocalizations.of(context)!.securityPasswordTitle,
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

  Widget _buildBody(ColorScheme cs) {
    if (!_is2faEnabled) return _buildSetupSection(cs);
    if (!_isAuthenticated) return _buildPasswordGate(cs);
    return _buildManageSection(cs);
  }

  Widget _buildSetupSection(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      child: Column(
        children: [
          _buildHeaderTile(
            cs,
            icon: Symbols.lock_open,
            title: l10n.passwordEntryNotSetTitle,
            subtitle: l10n.passwordEntry2faSubtitle,
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
          _buildActionRow(
            cs,
            icon: Symbols.settings,
            label: l10n.passwordEntrySetupAction,
            isLast: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TwoFactorSetupScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordGate(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      depth: 6,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Symbols.lock, color: cs.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.passwordEntryGateMessage,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
            _PasswordField(
              controller: _passwordController,
              hintText: l10n.passwordEntryGenericPasswordHint,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PrimaryLoadingButton(
                loading: _isVerifying,
                onPressed: _authenticate,
                child: Text(l10n.passwordEntryContinue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageSection(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        GlossyPill(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(20),
          depth: 6,
          child: SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Symbols.lock, color: cs.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.passwordEntrySetTitle,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_details?.email != null &&
                          _details!.email!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _details!.email!,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (_details?.hint != null &&
                          _details!.hint!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.passwordEntryHintPrefix(_details!.hint!),
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlossyPill(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          depth: 6,
          child: Column(
            children: [
              _buildActionRow(
                cs,
                icon: Symbols.password,
                label: l10n.passwordEntryChangePasswordAction,
                isLast: false,
                onTap: () => _openWithPassword(
                  (pwd) => TwoFactorPasswordChangeScreen(currentPassword: pwd),
                ),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
              _buildActionRow(
                cs,
                icon: Icons.email_outlined,
                label: l10n.passwordEntryChangeEmailAction,
                isLast: false,
                onTap: () => _openWithPassword(
                  (pwd) => TwoFactorEmailChangeScreen(currentPassword: pwd),
                ),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
              _buildActionRow(
                cs,
                icon: Icons.delete_outline,
                label: l10n.passwordEntryDeleteAction,
                isLast: true,
                textColor: cs.error,
                onTap: () => _openWithPassword(
                  (pwd) => TwoFactorRemoveScreen(currentPassword: pwd),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderTile(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
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
            child: Icon(icon, color: cs.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
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
}

class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _hintController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  int _step = 0;
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  String? _trackId;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _hintController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    final l10n = AppLocalizations.of(context)!;
    _isLoading.value = true;
    setState(() => _errorMessage = null);

    try {
      switch (_step) {
        case 0:
          if (_passwordController.text.length < 6) {
            setState(() => _errorMessage = l10n.passwordEntryMinPasswordError);
            break;
          }
          final trackId = await accountModule.create2faTrack();
          if (!mounted) return;
          setState(() {
            _trackId = trackId;
            _step = 1;
          });
          break;
        case 1:
          if (_confirmController.text != _passwordController.text) {
            setState(() => _errorMessage = l10n.passwordEntryMismatchError);
            break;
          }
          await accountModule.set2faPassword(
            _trackId!,
            _passwordController.text,
          );
          if (!mounted) return;
          setState(() => _step = 2);
          break;
        case 2:
          if (_hintController.text.isNotEmpty) {
            await accountModule.set2faHint(_trackId!, _hintController.text);
          }
          if (!mounted) return;
          setState(() => _step = 3);
          break;
        case 3:
          if (_emailController.text.isEmpty) {
            await _finishSetup(withEmail: false);
            break;
          }
          if (!_emailController.text.contains('@')) {
            setState(() => _errorMessage = l10n.passwordEntryInvalidEmailError);
            break;
          }
          await accountModule.verify2faEmail(_trackId!, _emailController.text);
          if (!mounted) return;
          setState(() => _step = 4);
          break;
        case 4:
          if (_codeController.text.length != 6) {
            setState(() => _errorMessage = l10n.passwordEntryInvalidCodeError);
            break;
          }
          await accountModule.verify2faCode(_trackId!, _codeController.text);
          await _finishSetup(withEmail: true);
          break;
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  Future<void> _finishSetup({required bool withEmail}) async {
    await accountModule.confirm2fa(
      trackId: _trackId!,
      password: _passwordController.text,
      hint: _hintController.text.isEmpty ? null : _hintController.text,
      withEmail: withEmail,
    );
    if (mounted) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.passwordEntrySetTitle,
      );
      Navigator.popUntil(context, ModalRoute.withName('SecurityScreen'));
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
          AppLocalizations.of(context)!.passwordEntrySetupTitle,
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
    final l10n = AppLocalizations.of(context)!;
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
            child: PrimaryLoadingButton(
              loading: _isLoading,
              onPressed: _nextStep,
              child: Text(
                _step == 4
                    ? l10n.passwordEntrySetupAction
                    : l10n.passwordEntryContinue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      l10n.passwordEntryStepPassword,
      l10n.passwordEntryStepHint,
      l10n.passwordEntryStepEmail,
      l10n.passwordEntryStepCode,
      l10n.loginDone,
    ];
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.passwordEntryChoosePassword,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.passwordEntryMinCharsHint,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 16),
        _PasswordField(
          controller: _passwordController,
          hintText: l10n.passwordEntryEnterPasswordHint,
        ),
      ],
    );
  }

  Widget _buildPasswordConfirmField(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.passwordEntryConfirmTitle,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.passwordEntryEnterAgain,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 16),
        _PasswordField(
          controller: _confirmController,
          hintText: l10n.passwordEntryRepeatHint,
        ),
      ],
    );
  }

  Widget _buildHintField(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.passwordEntryHintForPassword,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.passwordEntryOptional,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _hintController,
          decoration: InputDecoration(
            hintText: l10n.passwordEntryHintFieldHint,
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.passwordEntryLinkEmail,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.passwordEntryEmailPurpose,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: l10n.passwordEntryEmailHintOptional,
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.passwordEntryEnterCode,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.passwordEntryCodeSentTo(_emailController.text),
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

class TwoFactorPasswordChangeScreen extends StatefulWidget {
  final String currentPassword;

  const TwoFactorPasswordChangeScreen({
    super.key,
    required this.currentPassword,
  });

  @override
  State<TwoFactorPasswordChangeScreen> createState() =>
      _TwoFactorPasswordChangeScreenState();
}

class _TwoFactorPasswordChangeScreenState
    extends State<TwoFactorPasswordChangeScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _hintController = TextEditingController();
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
    _hintController.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context)!;
    if (_newPasswordController.text.length < 6) {
      setState(() => _errorMessage = l10n.passwordEntryMinPasswordError);
      return;
    }
    if (_confirmController.text != _newPasswordController.text) {
      setState(() => _errorMessage = l10n.passwordEntryMismatchError);
      return;
    }

    _isLoading.value = true;
    setState(() => _errorMessage = null);

    try {
      final trackId = await accountModule.enter2faPanel();
      await accountModule.check2faPassword(trackId, widget.currentPassword);
      await accountModule.update2faPassword(
        trackId: trackId,
        newPassword: _newPasswordController.text,
        hint: _hintController.text.isEmpty ? null : _hintController.text,
      );
      if (mounted) {
        showCustomNotification(context, l10n.passwordEntryChangedNotif);
        Navigator.popUntil(context, ModalRoute.withName('SecurityScreen'));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
          l10n.passwordEntryChangePasswordAction,
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
            Text(
              l10n.passwordEntryNewPassword,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller: _newPasswordController,
              hintText: l10n.passwordEntryNewPasswordHint,
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller: _confirmController,
              hintText: l10n.passwordEntryRepeatNewPasswordHint,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.passwordEntryStepHint,
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
                hintText: l10n.passwordEntryHintFieldHint,
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
              child: PrimaryLoadingButton(
                loading: _isLoading,
                onPressed: _changePassword,
                child: Text(l10n.editProfileSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TwoFactorEmailChangeScreen extends StatefulWidget {
  final String currentPassword;

  const TwoFactorEmailChangeScreen({super.key, required this.currentPassword});

  @override
  State<TwoFactorEmailChangeScreen> createState() =>
      _TwoFactorEmailChangeScreenState();
}

class _TwoFactorEmailChangeScreenState
    extends State<TwoFactorEmailChangeScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  int _step = 0;
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  String? _trackId;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<String> _ensureTrack() async {
    if (_trackId != null) return _trackId!;
    final trackId = await accountModule.enter2faPanel();
    await accountModule.check2faPassword(trackId, widget.currentPassword);
    _trackId = trackId;
    return trackId;
  }

  Future<void> _nextStep() async {
    final l10n = AppLocalizations.of(context)!;
    _isLoading.value = true;
    setState(() => _errorMessage = null);

    try {
      switch (_step) {
        case 0:
          if (!_emailController.text.contains('@')) {
            setState(() => _errorMessage = l10n.passwordEntryInvalidEmailError);
            break;
          }
          final trackId = await _ensureTrack();
          await accountModule.verify2faEmail(trackId, _emailController.text);
          if (!mounted) return;
          setState(() => _step = 1);
          break;
        case 1:
          if (_codeController.text.length != 6) {
            setState(() => _errorMessage = l10n.passwordEntryInvalidCodeError);
            break;
          }
          await accountModule.verify2faCode(_trackId!, _codeController.text);
          await accountModule.commit2faEmailChange(_trackId!);
          if (mounted) {
            showCustomNotification(
              context,
              l10n.passwordEntryEmailChangedNotif,
            );
            Navigator.popUntil(context, ModalRoute.withName('SecurityScreen'));
          }
          break;
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
          l10n.passwordEntryChangeEmailAction,
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
            if (_step == 0) ...[
              Text(
                l10n.passwordEntryNewEmail,
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
                  hintText: l10n.passwordEntryEmailHint,
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
                l10n.passwordEntryEnterCode,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.passwordEntryCodeSentTo(_emailController.text),
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: PrimaryLoadingButton(
                loading: _isLoading,
                onPressed: _nextStep,
                child: Text(
                  _step == 1
                      ? l10n.editProfileSave
                      : l10n.passwordEntryContinue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TwoFactorRemoveScreen extends StatefulWidget {
  final String currentPassword;

  const TwoFactorRemoveScreen({super.key, required this.currentPassword});

  @override
  State<TwoFactorRemoveScreen> createState() => _TwoFactorRemoveScreenState();
}

class _TwoFactorRemoveScreenState extends State<TwoFactorRemoveScreen> {
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  String? _errorMessage;

  @override
  void dispose() {
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _remove2fa() async {
    final l10n = AppLocalizations.of(context)!;
    _isLoading.value = true;
    setState(() => _errorMessage = null);

    try {
      final trackId = await accountModule.enter2faPanel();
      await accountModule.check2faPassword(trackId, widget.currentPassword);
      await accountModule.remove2fa(trackId);
      if (mounted) {
        showCustomNotification(context, l10n.passwordEntryRemovedNotif);
        Navigator.popUntil(context, ModalRoute.withName('SecurityScreen'));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
          l10n.passwordEntryRemoveTitle,
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
                      l10n.passwordEntryRemoveWarning,
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
            SizedBox(
              width: double.infinity,
              child: PrimaryLoadingButton(
                loading: _isLoading,
                onPressed: _remove2fa,
                background: cs.error,
                foreground: cs.onError,
                child: Text(l10n.passwordEntryDeleteAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;

  const _PasswordField({required this.controller, required this.hintText});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      decoration: InputDecoration(
        hintText: widget.hintText,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _visible ? Symbols.visibility_off : Symbols.visibility,
            color: cs.onSurfaceVariant,
          ),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}

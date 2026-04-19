import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/core/config/countries.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/l10n/terms_of_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'code_confirmation_screen.dart';
import 'select_country_screen.dart';
import 'proxy_settings_sheet.dart';
import 'server_settings_sheet.dart';
import '../profile/spoof_screen.dart';
import '../../widgets/custom_notification.dart';
import '../../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  late CountryName _selectedCountry;
  bool _isPhoneValid = false;
  bool _isTOSRead = false;
  String? _phoneError;
  Timer? _phoneErrorTimer;

  @override
  void initState() {
    super.initState();
    _selectedCountry = countriesByCode['RU'] ?? allCountries.first;
    _clampCountryToAllowed();
    _checkTOS();
  }

  void _clampCountryToAllowed() {
    final allowed = api.registrationCountries;
    if (allowed.any((c) => c.code == _selectedCountry.code)) return;
    _selectedCountry = allowed.firstWhere(
      (c) => c.code == 'RU',
      orElse: () => allowed.first,
    );
  }

  @override
  void dispose() {
    _phoneErrorTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkTOS() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isTOSRead = prefs.getBool('IsReadeTOS') ?? false;
      });
    }
  }

  Future<void> _markTOSRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('IsReadeTOS', true);
    if (mounted) {
      setState(() {
        _isTOSRead = true;
      });
    }
  }

  void _showCountryPicker() async {
    final result = await Navigator.push<CountryName>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectCountryScreen(
          selectedCountry: _selectedCountry,
          countries: api.registrationCountries,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedCountry = result;
        _phoneController.clear();
        _isPhoneValid = false;
      });
    }
  }

  String _countryDisplayName(CountryName country) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'ru' ? country.ru : country.en;
  }

  String _phoneMaskHint(CountryName country) {
    return country.phoneMask.replaceAll('#', '0');
  }

  void _showLanguagePicker() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final appContext = context;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    l10n.loginLanguage,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    l10n.languageNameRu,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    KometApp.stateOf(appContext)?.applyLocale(const Locale('ru'));
                  },
                ),
                ListTile(
                  title: Text(
                    l10n.languageNameEn,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    KometApp.stateOf(appContext)?.applyLocale(const Locale('en'));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTOS(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final termsLocale = Localizations.localeOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        double progress = _isTOSRead ? 1.0 : 0.0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cs = Theme.of(context).colorScheme;
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 1.0,
              snap: true,
              snapSizes: const [0.7, 1.0],
              expand: false,
              builder: (context, scrollController) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.loginTermsOfUse,
                          style: GoogleFonts.inter(
                            color: cs.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: NotificationListener<ScrollUpdateNotification>(
                        onNotification:
                            (ScrollUpdateNotification notification) {
                              if (_isTOSRead) return false;
                              final metrics = notification.metrics;
                              if (metrics.maxScrollExtent > 0) {
                                double newProgress =
                                    metrics.pixels / metrics.maxScrollExtent;
                                newProgress = newProgress.clamp(0.0, 1.0);
                                if (newProgress >= 0.99 && !_isTOSRead) {
                                  _markTOSRead();
                                  setModalState(() {
                                    progress = 1.0;
                                  });
                                } else {
                                  setModalState(() {
                                    progress = newProgress;
                                  });
                                }
                              }
                              return false;
                            },
                        child: ListView(
                          controller: scrollController,
                          children: [
                            Text(
                              termsOfServiceBody(termsLocale),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 48,
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(
                            right: progress == 1.0 ? 56.0 : 0.0,
                          ),
                          child: Container(
                            height: 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress < 1.0 ? progress : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: progress == 1.0 ? 1.0 : 0.0,
                          curve: Curves.easeIn,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            transform: Matrix4.translationValues(
                              progress == 1.0 ? 0 : 20,
                              0,
                              0,
                            ),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Symbols.check,
                              color: cs.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPhoneError(String message) {
    _phoneErrorTimer?.cancel();
    setState(() => _phoneError = message);
    _phoneErrorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _phoneError = null);
    });
  }

  void _showPhoneConfirmationDialog(String formattedPhone) {
    final screenContext = context;
    final l10n = AppLocalizations.of(screenContext)!;

    showGeneralDialog(
      context: screenContext,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final cs = Theme.of(context).colorScheme;
        final curve = Curves.easeOutQuart.transform(anim1.value);
        return Opacity(
          opacity: anim1.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - curve)),
            child: Transform.scale(
              scale: 0.8 + (0.2 * curve),
              child: AlertDialog(
                backgroundColor: cs.surfaceContainerHigh,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.loginConfirmPhoneTitle,
                      style: GoogleFonts.inter(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_selectedCountry.phoneCode} $formattedPhone',
                      style: GoogleFonts.inter(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          l10n.loginEdit,
                          style: GoogleFonts.inter(
                            color: cs.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);

                          final fullPhone =
                              '${_selectedCountry.phoneCode}${_phoneController.text}';

                          try {
                            final result = await accountModule.requestCode(
                              fullPhone,
                            );

                            if (!screenContext.mounted) return;
                            Navigator.push(
                              screenContext,
                              MaterialPageRoute(
                                builder: (context) => CodeConfirmationScreen(
                                  phoneNumber:
                                      '${_selectedCountry.phoneCode} $formattedPhone',
                                  token: result.token,
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!screenContext.mounted) return;
                            _showPhoneError(e.toString());
                          }
                        },
                        child: Text(
                          l10n.loginDone,
                          style: GoogleFonts.inter(
                            color: cs.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _validateAndSubmit() {
    if (!_isTOSRead) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.loginReadTermsNotification,
      );
      return;
    }
    _showPhoneConfirmationDialog(_phoneController.text);
  }

  void _showServerSettingsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: const ServerSettingsSheet(),
        );
      },
    );
  }

  void _showProxySettingsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: const ProxySettingsSheet(),
        );
      },
    );
  }

  void _showSecurityOptions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Symbols.security, color: cs.onSurface),
                  title: Text(
                    l10n.loginSpoofRedacted,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SpoofScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.vpn_lock, color: cs.onSurface),
                  title: Text(
                    l10n.loginProxy,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showProxySettingsSheet(context);
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.dns, color: cs.onSurface),
                  title: Text(
                    l10n.loginChangeServer,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showServerSettingsSheet(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOtherLoginMethods(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Symbols.qr_code_2, color: cs.onSurface),
                  title: Text(
                    l10n.loginSignInWithQr,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.key, color: cs.onSurface),
                  title: Text(
                    l10n.loginSignInWithToken,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.description, color: cs.onSurface),
                  title: Text(
                    l10n.loginSignInWithSessionFile,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -500) {
            _showTOS(context);
          }
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 44),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: () => _showSecurityOptions(context),
                                icon: Icon(
                                  Symbols.admin_panel_settings,
                                  color: cs.onSurfaceVariant,
                                  weight: 400,
                                ),
                              ),
                              IconButton(
                                onPressed: _showLanguagePicker,
                                icon: Icon(
                                  Symbols.language,
                                  color: cs.onSurfaceVariant,
                                  weight: 400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 74),
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/komet.png',
                                  height: 80,
                                  color: cs.onSurface,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.loginTitle,
                                  style: GoogleFonts.inter(
                                    color: cs.onSurface,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.loginSubtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                          InkWell(
                            onTap: _showCountryPicker,
                            borderRadius: BorderRadius.circular(50),
                            child: _buildInputField(
                              label: l10n.loginCountry,
                              content: Row(
                                children: [
                                  Text(
                                    _countryDisplayName(_selectedCountry),
                                    style: GoogleFonts.inter(
                                      color: cs.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildInputField(
                            label: l10n.loginPhoneNumber,
                            content: Row(
                              children: [
                                Text(
                                  _selectedCountry.phoneCode,
                                  style: GoogleFonts.inter(
                                    color: cs.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: cs.outlineVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    key: ValueKey(_selectedCountry.code),
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      _PhoneInputFormatter(_selectedCountry),
                                    ],
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _phoneMaskHint(_selectedCountry),
                                      hintStyle: TextStyle(
                                        color: cs.outline,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) {
                                      final digits = value.replaceAll(
                                        RegExp(r'\D'),
                                        '',
                                      );
                                      setState(() {
                                        _isPhoneValid =
                                            digits.length ==
                                            _selectedCountry.phoneDigits;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topLeft,
                            child: _phoneError != null
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      _phoneError!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => _showOtherLoginMethods(context),
                            child: Text(
                              l10n.loginOtherSignInMethods,
                              style: GoogleFonts.inter(
                                color: cs.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.inter(
                                        color: cs.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: l10n.loginTermsIntro,
                                          style: GoogleFonts.inter(
                                            color: cs.onSurface,
                                            fontSize: 14,
                                            height: 1.4,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        TextSpan(
                                          text: l10n.loginTermsLink,
                                          style: GoogleFonts.inter(
                                            color: cs.primary,
                                            fontSize: 14,
                                            height: 1.4,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => _showTOS(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: FloatingActionButton(
                                  onPressed: _isPhoneValid
                                      ? _validateAndSubmit
                                      : null,
                                  backgroundColor: _isPhoneValid
                                      ? cs.primaryContainer
                                      : cs.surfaceContainerHighest,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: _isPhoneValid
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required String label, required Widget content}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: cs.primary, width: 1.5),
                borderRadius: BorderRadius.circular(50),
              ),
              child: content,
            ),
            Positioned(
              top: -10,
              left: 20,
              child: Container(
                color: cs.surface,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: cs.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  final CountryName country;
  _PhoneInputFormatter(this.country);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (newValue.text.length < oldValue.text.length) {
      final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
      if (text.length == oldDigits.length && text.isNotEmpty) {
        text = text.substring(0, text.length - 1);
      }
    }

    if (text.length > country.phoneDigits) {
      text = text.substring(0, country.phoneDigits);
    }

    final buffer = StringBuffer();
    int digitIdx = 0;

    for (int i = 0; i < country.phoneGroupSizes.length; i++) {
      if (digitIdx >= text.length) break;

      buffer.write(country.phoneGroupSeparators[i]);

      final groupSize = country.phoneGroupSizes[i];
      final remainingDigits = text.length - digitIdx;
      final digitsToTake = remainingDigits < groupSize
          ? remainingDigits
          : groupSize;

      buffer.write(text.substring(digitIdx, digitIdx + digitsToTake));
      digitIdx += digitsToTake;

      if (digitIdx == text.length &&
          i < country.phoneGroupSeparators.length - 1) {}
    }

    if (digitIdx == text.length && text.length == country.phoneDigits) {
      if (country.phoneGroupSeparators.length >
          country.phoneGroupSizes.length) {
        buffer.write(country.phoneGroupSeparators.last);
      }
    }

    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

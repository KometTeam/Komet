import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/screens/otp_screen.dart';
import 'package:gwid/utils/proxy_service.dart';
import 'package:gwid/screens/registration_screen.dart';
import 'package:gwid/screens/settings/auth_settings_screen.dart';
import 'package:gwid/screens/token_auth_screen.dart';
import 'package:gwid/screens/tos_screen.dart'; // Импорт экрана ToS
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:platform_info/platform_info.dart';

class Country {
  final String name;
  final String code;
  final String flag;
  final String mask;
  final int digits;

  const Country({
    required this.name,
    required this.code,
    required this.flag,
    required this.mask,
    required this.digits,
  });
}

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();

  static const List<Country> _countries = [
    Country(
      name: 'Россия',
      code: '+7',
      flag: '🇷🇺',
      mask: '+7 (###) ###-##-##',
      digits: 10,
    ),
    Country(
      name: 'Азербайджан',
      code: '+994',
      flag: '🇦🇿',
      mask: '+994 (##) ###-##-##',
      digits: 9,
    ),
    Country(
      name: 'Армения',
      code: '+374',
      flag: '🇦🇲',
      mask: '+374 (##) ###-###',
      digits: 8,
    ),
    Country(
      name: 'Казахстан',
      code: '+7',
      flag: '🇰🇿',
      mask: '+7 (###) ###-##-##',
      digits: 10,
    ),
    Country(
      name: 'Кыргызстан',
      code: '+996',
      flag: '🇰🇬',
      mask: '+996 (###) ###-###',
      digits: 9,
    ),
    Country(
      name: 'Молдова',
      code: '+373',
      flag: '🇲🇩',
      mask: '+373 (####) ####',
      digits: 8,
    ),
    Country(
      name: 'Таджикистан',
      code: '+992',
      flag: '🇹🇯',
      mask: '+992 (##) ###-##-##',
      digits: 9,
    ),
    Country(
      name: 'Узбекистан',
      code: '+998',
      flag: '🇺🇿',
      mask: '+998 (##) ###-##-##',
      digits: 9,
    ),
    Country(
      name: 'Беларусь',
      code: '+375',
      flag: '🇧🇾',
      mask: '+375 (##) ###-##-##',
      digits: 9,
    ),
    Country(
      name: 'Свое',
      code: '',
      flag: '',
      mask: '',
      digits: 0, // Без ограничения
    ),
  ];

  Country _selectedCountry = _countries[0];
  late MaskTextInputFormatter _maskFormatter;
  bool _isButtonEnabled = false;
  bool _isLoading = false;
  bool _hasCustomAnonymity = false;
  bool _hasProxyConfigured = false;
  StreamSubscription? _apiSubscription;
  bool _showContent = false;
  bool _isTosAccepted = false; // Состояние для отслеживания принятия соглашения
  String _customPrefix = ''; // Для "Свой префикс"

  late final AnimationController _animationController;
  late final Animation<Alignment> _topAlignmentAnimation;
  late final Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _topAlignmentAnimation =
        AlignmentTween(
          begin: Alignment.topLeft,
          end: Alignment.topRight,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
    _bottomAlignmentAnimation =
        AlignmentTween(
          begin: Alignment.bottomRight,
          end: Alignment.bottomLeft,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _animationController.repeat(reverse: true);

    _initializeMaskFormatter();
    _checkAnonymitySettings();
    _checkProxySettings();
    _phoneController.addListener(_onPhoneChanged);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showContent = true);
    });

    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (message['opcode'] == 17 && mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isLoading = false);
        });
        final payload = message['payload'];
        if (payload != null && payload['token'] != null) {
          final String token = payload['token'];
          final String prefix = _selectedCountry.mask.isEmpty
              ? _customPrefix
              : _selectedCountry.code;
          final String fullPhoneNumber =
              prefix + _maskFormatter.getUnmaskedText();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  OTPScreen(phoneNumber: fullPhoneNumber, otpToken: token),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось запросить код. Попробуйте позже.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  void _initializeMaskFormatter() {
    if (_selectedCountry.mask.isEmpty) {
      // Для "Свой префикс" - без маски, только цифры
      _maskFormatter = MaskTextInputFormatter(
        mask: '',
        filter: {"#": RegExp(r'[0-9]')},
        type: MaskAutoCompletionType.lazy,
      );
    } else {
      final mask = _selectedCountry.mask
          .replaceFirst(RegExp(r'^\+\d+\s?'), '')
          .trim();
      _maskFormatter = MaskTextInputFormatter(
        mask: mask,
        filter: {"#": RegExp(r'[0-9]')},
        type: MaskAutoCompletionType.lazy,
      );
    }
  }

  void _onPhoneChanged() {
    final text = _phoneController.text;
    if (text.isNotEmpty) {
      Country? detectedCountry = _detectCountryFromInput(text);
      if (detectedCountry != null && detectedCountry != _selectedCountry) {
        if (_shouldClearFieldForCountry(text, detectedCountry)) {
          _phoneController.clear();
        }
        setState(() {
          _selectedCountry = detectedCountry;
          _initializeMaskFormatter();
        });
      }
    }

    // Для "Свой префикс" проверяем минимальную длину (например, 5 цифр)
    final isFull = _selectedCountry.mask.isEmpty
        ? _maskFormatter.getUnmaskedText().length >= 5
        : _maskFormatter.getUnmaskedText().length == _selectedCountry.digits;
    if (isFull != _isButtonEnabled) {
      setState(() => _isButtonEnabled = isFull);
    }
  }

  bool _shouldClearFieldForCountry(String input, Country country) {
    final cleanInput = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (country.code == '+7') {
      return !(cleanInput.startsWith('+7') || cleanInput.startsWith('7'));
    } else if (country.code == '+375') {
      return !(cleanInput.startsWith('+375') || cleanInput.startsWith('375'));
    }
    return true;
  }

  Country? _detectCountryFromInput(String input) {
    final cleanInput = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanInput.startsWith('+7') || cleanInput.startsWith('7')) {
      return _countries.firstWhere((c) => c.code == '+7');
    } else if (cleanInput.startsWith('+375') || cleanInput.startsWith('375')) {
      return _countries.firstWhere((c) => c.code == '+375');
    }
    return null;
  }

  void _onCountryChanged(Country? country) async {
    if (country != null && country != _selectedCountry) {
      // Если выбран "Свой префикс", показываем диалог для ввода префикса
      if (country.mask.isEmpty) {
        final prefix = await _showCustomPrefixDialog();
        if (prefix == null || prefix.isEmpty) {
          return; // Отменено
        }
        setState(() {
          _selectedCountry = country;
          _customPrefix = prefix.startsWith('+') ? prefix : '+$prefix';
          _phoneController.clear();
          _initializeMaskFormatter();
          _isButtonEnabled = false;
        });
      } else {
        setState(() {
          _selectedCountry = country;
          _customPrefix = '';
          _phoneController.clear();
          _initializeMaskFormatter();
          _isButtonEnabled = false;
        });
      }
    }
  }

  Future<String?> _showCustomPrefixDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final textTheme = Theme.of(context).textTheme;
        return AlertDialog(
          title: Text(
            'Введите код страны',
            style: GoogleFonts.manrope(
              textStyle: textTheme.titleLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '+123',
              prefixText: '+',
              border: const OutlineInputBorder(),
            ),
            style: GoogleFonts.manrope(textStyle: textTheme.titleMedium),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Отмена', style: GoogleFonts.manrope()),
            ),
            FilledButton(
              onPressed: () {
                final prefix = controller.text.trim();
                if (prefix.isNotEmpty) {
                  Navigator.of(context).pop(prefix);
                }
              },
              child: Text('OK', style: GoogleFonts.manrope()),
            ),
          ],
        );
      },
    );
  }

  void _checkAnonymitySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final anonymityEnabled = prefs.getBool('anonymity_enabled') ?? false;
    if (mounted) setState(() => _hasCustomAnonymity = anonymityEnabled);
  }

  Future<void> _checkProxySettings() async {
    final settings = await ProxyService.instance.loadProxySettings();
    if (mounted) {
      setState(() {
        _hasProxyConfigured = settings.isEnabled && settings.host.isNotEmpty;
      });
    }
  }

  void _requestOtp() async {
    if (!_isButtonEnabled || _isLoading || !_isTosAccepted) return;
    setState(() => _isLoading = true);
    final String prefix = _selectedCountry.mask.isEmpty
        ? _customPrefix
        : _selectedCountry.code;
    final String fullPhoneNumber = prefix + _maskFormatter.getUnmaskedText();
    try {
      ApiService.instance.errorStream.listen((error) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog(error);
        }
      });
      await ApiService.instance.requestOtp(fullPhoneNumber);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Ошибка подключения: ${e.toString()}');
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Ошибка валидации'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: _topAlignmentAnimation.value,
                    end: _bottomAlignmentAnimation.value,
                    colors: [
                      Color.lerp(colors.surface, colors.primary, 0.2)!,
                      Color.lerp(colors.surface, colors.tertiary, 0.15)!,
                      colors.surface,
                      Color.lerp(colors.surface, colors.secondary, 0.15)!,
                      Color.lerp(colors.surface, colors.primary, 0.25)!,
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      opacity: _showContent ? 1.0 : 0.0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 48),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primary.withOpacity(0.1),
                              ),
                              child: const Image(
                                image: AssetImage(
                                  'assets/images/komet_512.png',
                                ),
                                width: 75,
                                height: 75,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Komet',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              textStyle: textTheme.headlineLarge,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Введите номер телефона для входа',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              textStyle: textTheme.titleMedium,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 48),
                          _PhoneInput(
                            phoneController: _phoneController,
                            maskFormatter: _maskFormatter,
                            selectedCountry: _selectedCountry,
                            countries: _countries,
                            onCountryChanged: _onCountryChanged,
                            customPrefix: _customPrefix,
                          ),
                          
                          (Platform.instance.android || Platform.instance.windows) ? Column(
                            children: [
                            const SizedBox(height: 16),
                            Center(
                            child: TextButton(
                              onPressed: _isTosAccepted
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const RegistrationScreen(),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Text(
                                'зарегистрироваться',
                                style: GoogleFonts.manrope(
                                  color: _isTosAccepted
                                      ? colors.primary
                                      : colors.onSurfaceVariant.withOpacity(
                                          0.5,
                                        ),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _isTosAccepted
                                      ? colors.primary
                                      : colors.onSurfaceVariant.withOpacity(
                                          0.5,
                                        ),
                                ),
                              ),
                            ),
                            )]
                          ) : const SizedBox(),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Checkbox(
                                value: _isTosAccepted,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _isTosAccepted = value ?? false;
                                  });
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: GoogleFonts.manrope(
                                      textStyle: textTheme.bodySmall,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Я принимаю '),
                                      TextSpan(
                                        text: 'Пользовательское соглашение',
                                        style: TextStyle(
                                          color: colors.primary,
                                          decoration: TextDecoration.underline,
                                          decorationColor: colors.primary,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const TosScreen(),
                                              ),
                                            );
                                          },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _isButtonEnabled && _isTosAccepted
                                ? _requestOtp
                                : null,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'Далее',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _isTosAccepted
                                ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TokenAuthScreen(),
                                    ),
                                  )
                                : null,
                            icon: const Icon(Icons.vpn_key_outlined),
                            label: Text(
                              'Альтернативные способы входа',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _SettingsButton(
                            hasCustomAnonymity: _hasCustomAnonymity,
                            hasProxyConfigured: _hasProxyConfigured,
                            onRefresh: () {
                              _checkAnonymitySettings();
                              _checkProxySettings();
                            },
                          ),
                          const SizedBox(height: 24),
                          Text.rich(
                            textAlign: TextAlign.center,
                            TextSpan(
                              style: GoogleFonts.manrope(
                                textStyle: textTheme.bodySmall,
                                color: colors.onSurfaceVariant.withOpacity(0.8),
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'Используя Komet, вы принимаете на себя всю ответственность за использование стороннего клиента.\n',
                                ),
                                TextSpan(
                                  text: '@TeamKomet',
                                  style: TextStyle(
                                    color: colors.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: colors.primary,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () async {
                                      final Uri url = Uri.parse(
                                        'https://t.me/TeamKomet',
                                      );
                                      if (!await launchUrl(url)) {
                                        debugPrint('Could not launch $url');
                                      }
                                    },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: colors.scrim.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Отправляем код...',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _apiSubscription?.cancel();
    super.dispose();
  }
}

class _PhoneInput extends StatelessWidget {
  final TextEditingController phoneController;
  final MaskTextInputFormatter maskFormatter;
  final Country selectedCountry;
  final List<Country> countries;
  final ValueChanged<Country?> onCountryChanged;
  final String customPrefix;

  const _PhoneInput({
    required this.phoneController,
    required this.maskFormatter,
    required this.selectedCountry,
    required this.countries,
    required this.onCountryChanged,
    required this.customPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: phoneController,
      inputFormatters: [maskFormatter],
      keyboardType: TextInputType.number,
      style: GoogleFonts.manrope(
        textStyle: Theme.of(context).textTheme.titleMedium,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: maskFormatter.getMask()?.replaceAll('#', '0'),
        prefixIcon: _CountryPicker(
          selectedCountry: selectedCountry,
          countries: countries,
          onCountryChanged: onCountryChanged,
          customPrefix: customPrefix,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      autofocus: true,
    );
  }
}

class _CountryPicker extends StatelessWidget {
  final Country selectedCountry;
  final List<Country> countries;
  final ValueChanged<Country?> onCountryChanged;
  final String customPrefix;

  const _CountryPicker({
    required this.selectedCountry,
    required this.countries,
    required this.onCountryChanged,
    required this.customPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Country>(
          value: selectedCountry,
          onChanged: onCountryChanged,
          icon: Icon(Icons.keyboard_arrow_down, color: colors.onSurfaceVariant),
          selectedItemBuilder: (BuildContext context) {
            return countries.map<Widget>((Country country) {
              final displayText = country.mask.isEmpty
                  ? (customPrefix.isNotEmpty ? customPrefix : country.name)
                  : country.code;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayText,
                      style: GoogleFonts.manrope(
                        textStyle: textTheme.titleMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          items: countries.map((Country country) {
            return DropdownMenuItem<Country>(
              value: country,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (country.flag.isNotEmpty) ...[
                    Text(country.flag, style: textTheme.titleMedium),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    country.code.isEmpty ? 'Свое' : country.code,
                    style: GoogleFonts.manrope(
                      textStyle: textTheme.titleMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final bool hasCustomAnonymity;
  final bool hasProxyConfigured;
  final VoidCallback onRefresh;

  const _SettingsButton({
    required this.hasCustomAnonymity,
    required this.hasProxyConfigured,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hasAnySettings = hasCustomAnonymity || hasProxyConfigured;

    return Card(
      elevation: 0,
      color: hasAnySettings
          ? colors.primaryContainer.withOpacity(0.3)
          : colors.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasAnySettings
              ? colors.primary.withOpacity(0.3)
              : colors.outline.withOpacity(0.3),
          width: hasAnySettings ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AuthSettingsScreen()),
          );
          onRefresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: hasAnySettings
                          ? colors.primary.withOpacity(0.15)
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tune_outlined,
                      color: hasAnySettings
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Настройки',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.titleMedium,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasAnySettings
                              ? 'Настроены дополнительные параметры'
                              : 'Прокси и анонимность',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.bodySmall,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: colors.onSurfaceVariant,
                    size: 16,
                  ),
                ],
              ),
              if (hasAnySettings) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasCustomAnonymity) ...[
                        Icon(
                          Icons.verified_user,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Анонимность',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.labelSmall,
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      if (hasCustomAnonymity && hasProxyConfigured) ...[
                        const SizedBox(width: 12),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (hasProxyConfigured) ...[
                        Icon(Icons.vpn_key, size: 16, color: colors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Прокси',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.labelSmall,
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

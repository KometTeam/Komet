import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gwid/api/api_registration_service.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

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

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  static const List<Country> _countries = [
    Country(
      name: 'Россия',
      code: '+7',
      flag: '🇷🇺',
      mask: '+7 (###) ###-##-##',
      digits: 10,
    ),
    Country(
      name: 'Беларусь',
      code: '+375',
      flag: '🇧🇾',
      mask: '+375 (##) ###-##-##',
      digits: 9,
    ),
  ];

  Country _selectedCountry = _countries[0];
  late MaskTextInputFormatter _maskFormatter;
  bool _isButtonEnabled = false;
  bool _isLoading = false;
  bool _showCodeInput = false;
  bool _showContent = false;
  String? _registrationToken;
  final RegistrationService _registrationService = RegistrationService();

  late final AnimationController _animationController;
  late final Animation<Alignment> _topAlignmentAnimation;
  late final Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();
    print('🎬 RegistrationScreen инициализирован');

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
    _phoneController.addListener(_onPhoneChanged);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  void _initializeMaskFormatter() {
    final mask = _selectedCountry.mask
        .replaceFirst(RegExp(r'^\+\d+\s?'), '')
        .trim();
    _maskFormatter = MaskTextInputFormatter(
      mask: mask,
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );
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
    final isFull =
        _maskFormatter.getUnmaskedText().length == _selectedCountry.digits;
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

  void _onCountryChanged(Country? country) {
    if (country != null && country != _selectedCountry) {
      setState(() {
        _selectedCountry = country;
        _phoneController.clear();
        _initializeMaskFormatter();
        _isButtonEnabled = false;
      });
    }
  }

  Future<void> _startRegistration() async {
    if (!_isButtonEnabled || _isLoading) return;

    print('🔄 Начинаем процесс регистрации...');
    setState(() => _isLoading = true);

    try {
      final fullPhoneNumber =
          _selectedCountry.code + _maskFormatter.getUnmaskedText();
      print('📞 Номер телефона: $fullPhoneNumber');

      
      final token = await _registrationService.startRegistration(
        fullPhoneNumber,
      );
      print('✅ Токен получен: ${token.substring(0, 20)}...');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _showCodeInput = true;
          _registrationToken = token;
        });
        print('✅ Переходим к вводу кода');
      }
    } catch (e) {
      print('❌ Ошибка в процессе регистрации: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка регистрации: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyRegistrationCode(String code) async {
    if (_registrationToken == null || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      print('🔐 Код подтверждения: $code');

      
      final registerToken = await _registrationService.verifyCode(
        _registrationToken!,
        code,
      );

      
      await _registrationService.completeRegistration(registerToken);

      print('✅ Регистрация завершена успешно!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Регистрация завершена успешно!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ Ошибка при завершении регистрации: $e');
      if (mounted) {
        setState(() => _isLoading = false);

        
        if (e.toString().contains('ACCOUNT_EXISTS')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'А зачем... Аккаунт на таком номере уже существует!',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
                            'Модуль регистрации',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              textStyle: textTheme.headlineMedium,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 48),
                          if (!_showCodeInput) ...[
                            _PhoneInput(
                              phoneController: _phoneController,
                              maskFormatter: _maskFormatter,
                              selectedCountry: _selectedCountry,
                              countries: _countries,
                              onCountryChanged: _onCountryChanged,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _isButtonEnabled && !_isLoading
                                  ? _startRegistration
                                  : null,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                'Отправить код',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Введите код подтверждения',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                textStyle: textTheme.titleMedium,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: '000000',
                                counterText: '',
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.length == 6) {
                                  _verifyRegistrationCode(value);
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Назад',
                              style: GoogleFonts.manrope(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
                      _showCodeInput ? 'Регистрируем...' : 'Отправляем код...',
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
    _codeController.dispose();
    _registrationService.disconnect();
    super.dispose();
  }
}

class _PhoneInput extends StatelessWidget {
  final TextEditingController phoneController;
  final MaskTextInputFormatter maskFormatter;
  final Country selectedCountry;
  final List<Country> countries;
  final ValueChanged<Country?> onCountryChanged;

  const _PhoneInput({
    required this.phoneController,
    required this.maskFormatter,
    required this.selectedCountry,
    required this.countries,
    required this.onCountryChanged,
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

  const _CountryPicker({
    required this.selectedCountry,
    required this.countries,
    required this.onCountryChanged,
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
          items: countries.map((Country country) {
            return DropdownMenuItem<Country>(
              value: country,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(country.flag, style: textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Text(
                    country.code,
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

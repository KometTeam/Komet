import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/screens/home_screen.dart';
import 'package:gwid/screens/phone_entry_screen.dart';
import 'package:gwid/services/whitelist_service.dart';
import 'package:gwid/utils/proxy_service.dart';
import 'package:gwid/utils/proxy_settings.dart';
import 'package:gwid/screens/settings/qr_scanner_screen.dart';
import 'package:gwid/screens/settings/session_spoofing_screen.dart';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart' as crypto;

class TokenAuthScreen extends StatefulWidget {
  const TokenAuthScreen({super.key});

  @override
  State<TokenAuthScreen> createState() => _TokenAuthScreenState();
}

class _TokenAuthScreenState extends State<TokenAuthScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
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
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _processLogin({
    required String token,
    Map<String, dynamic>? spoofData,
    ProxySettings? proxySettings,
  }) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (spoofData != null && spoofData.isNotEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Настройки анонимности из файла применены!'),
          ),
        );
      }
      if (proxySettings != null) {
        await ProxyService.instance.saveProxySettings(proxySettings);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Настройки прокси из файла применены!'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      await ApiService.instance.saveToken(token);

      final chatsResult = ApiService.instance.lastChatsPayload;
      int? userId;
      if (chatsResult != null) {
        final profileJson = chatsResult['profile'];
        if (profileJson != null) {
          final profile = Profile.fromJson(profileJson);
          userId = profile.id;
        }
      }

      final whitelistService = WhitelistService();
      final isAllowed = await whitelistService.checkAndValidate(userId);

      if (!isAllowed) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const PhoneEntryScreen()),
            (Route<dynamic> route) => false,
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

      if (mounted && whitelistService.isEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('проверка на ивана пройдена, успешно'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ошибка входа: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loginWithToken() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите токен для входа')));
      return;
    }
    _processLogin(token: token);
  }

  Future<void> _loadSessionFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'ksession'],
    );
    if (result == null || result.files.single.path == null) return;
    final filePath = result.files.single.path!;
    setState(() => _isLoading = true);
    try {
      final fileContent = await File(filePath).readAsString();
      Map<String, dynamic> jsonData = json.decode(fileContent);
      String finalJsonPayload;
      if (jsonData['encrypted'] == true) {
        final password = await _showPasswordDialog();
        if (password == null || password.isEmpty) {
          setState(() => _isLoading = false);
          return;
        }
        final iv = encrypt.IV.fromBase64(jsonData['iv_base64']);
        final encryptedData = encrypt.Encrypted.fromBase64(
          jsonData['data_base64'],
        );
        final keyBytes = utf8.encode(password);
        final keyHash = crypto.sha256.convert(keyBytes);
        final key = encrypt.Key(Uint8List.fromList(keyHash.bytes));
        final encrypter = encrypt.Encrypter(
          encrypt.AES(key, mode: encrypt.AESMode.cbc),
        );
        finalJsonPayload = encrypter.decrypt(encryptedData, iv: iv);
      } else {
        finalJsonPayload = fileContent;
      }
      final Map<String, dynamic> sessionData = json.decode(finalJsonPayload);
      final String? token = sessionData['token'];
      if (token == null || token.isEmpty) {
        throw Exception('Файл сессии не содержит токена.');
      }
      await _processLogin(
        token: token,
        spoofData: sessionData['spoof_data'] is Map<String, dynamic>
            ? sessionData['spoof_data']
            : null,
        proxySettings: sessionData['proxy_settings'] is Map<String, dynamic>
            ? ProxySettings.fromJson(sessionData['proxy_settings'])
            : null,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processQrData(String qrData) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final decoded = jsonDecode(qrData) as Map<String, dynamic>;

      if (decoded['type'] != 'komet_auth_v1' ||
          decoded['token'] == null ||
          decoded['timestamp'] == null) {
        throw Exception("Неверный формат QR-кода.");
      }

      final int qrTimestamp = decoded['timestamp'];
      final String token = decoded['token'];

      final int now = DateTime.now().millisecondsSinceEpoch;
      const int oneMinuteInMillis = 60 * 1000;

      if ((now - qrTimestamp) > oneMinuteInMillis) {
        throw Exception("QR-код устарел. Пожалуйста, сгенерируйте новый.");
      }

      await _processLogin(token: token);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showQrSourceSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Камера'),
              onTap: () {
                Navigator.of(context).pop();
                _scanWithCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () {
                Navigator.of(context).pop();
                _scanFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanWithCamera() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (result != null) await _processQrData(result);
  }

  Future<void> _scanFromGallery() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final controller = MobileScannerController();
    final result = await controller.analyzeImage(image.path);
    await controller.dispose();
    if (result != null &&
        result.barcodes.isNotEmpty &&
        result.barcodes.first.rawValue != null) {
      await _processQrData(result.barcodes.first.rawValue!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR-код на изображении не найден.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<String?> _showPasswordDialog() {
    final passwordController = TextEditingController();
    bool isPasswordVisible = false;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Введите пароль'),
          content: TextField(
            controller: passwordController,
            obscureText: !isPasswordVisible,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Пароль от файла сессии',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setStateDialog(
                  () => isPasswordVisible = !isPasswordVisible,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(passwordController.text),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                                'Другие способы входа',
                                style: GoogleFonts.manrope(
                                  textStyle: textTheme.headlineSmall,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Выберите удобный способ авторизации',
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
                          padding: const EdgeInsets.all(24.0),
                          children: [
                            _AuthMethodCard(
                              icon: Icons.devices_other_outlined,
                              title: 'Подмена данных сессии',
                              description:
                                  'Настройте тип устройства и параметры сессии для корректной работы с токеном.',
                              buttonLabel: 'Настроить',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SessionSpoofingScreen(),
                                  ),
                                );
                              },
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colors.surfaceContainerHighest,
                                  colors.surfaceContainer,
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _AuthMethodCard(
                              icon: Icons.qr_code_scanner_rounded,
                              title: 'Вход по QR-коду',
                              description:
                                  'Отсканируйте QR-код с другого устройства, чтобы быстро войти.',
                              buttonLabel: 'Сканировать',
                              onPressed: _showQrSourceSelection,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color.lerp(
                                    colors.primaryContainer,
                                    colors.primary,
                                    0.2,
                                  )!,
                                  colors.primaryContainer,
                                ],
                              ),
                              hasWarning: true,
                            ),
                            const SizedBox(height: 16),
                            _AuthMethodCard(
                              icon: Icons.file_open_outlined,
                              title: 'Вход по файлу сессии',
                              description:
                                  'Загрузите ранее экспортированный .json или .ksession файл для восстановления сессии.',
                              buttonLabel: 'Загрузить файл',
                              onPressed: _loadSessionFile,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colors.surfaceContainerHighest,
                                  colors.surfaceContainer,
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _TokenAuthCard(
                              controller: _tokenController,
                              onPressed: _loginWithToken,
                            ),
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
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;
  final Gradient gradient;
  final bool hasWarning;

  const _AuthMethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    required this.gradient,
    this.hasWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
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
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: colors.onSurfaceVariant, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.manrope(
                  textStyle: textTheme.titleLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.manrope(
                  textStyle: textTheme.bodyMedium,
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (hasWarning) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: colors.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Токены привязаны к типу устройства. Перед входом убедитесь, что в настройках подмены сессии выбран правильный тип устройства (Android, iOS или Desktop), с которого был получен токен.',
                          style: GoogleFonts.manrope(
                            textStyle: TextStyle(
                              fontSize: 13,
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    buttonLabel,
                    style: GoogleFonts.manrope(
                      textStyle: textTheme.labelLarge,
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    color: colors.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenAuthCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onPressed;

  const _TokenAuthCard({required this.controller, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
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
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.vpn_key_outlined,
                      color: colors.onSurfaceVariant,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Вход по токену',
                style: GoogleFonts.manrope(
                  textStyle: textTheme.titleLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Введите токен авторизации (AUTH_TOKEN) вручную.',
                style: GoogleFonts.manrope(
                  textStyle: textTheme.bodyMedium,
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colors.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Токены привязаны к типу устройства. Перед входом убедитесь, что в настройках подмены сессии выбран правильный тип устройства (Android, iOS или Desktop), с которого был получен токен.',
                        style: GoogleFonts.manrope(
                          textStyle: TextStyle(
                            fontSize: 13,
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Токен',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Войти с токеном',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

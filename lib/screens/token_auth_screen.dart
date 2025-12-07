import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gwid/api/api_service.dart';
import 'package:gwid/screens/home_screen.dart';
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

class _TokenAuthScreenState extends State<TokenAuthScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _tokenController.dispose();
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
      const int oneMinuteInMillis = 60 * 1000; // 60 секунд

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
    return Scaffold(
      appBar: AppBar(title: const Text('Другие способы входа')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AuthCard(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Вход по QR-коду',
                subtitle:
                    'Отсканируйте QR-код с другого устройства, чтобы быстро войти.',
                buttonLabel: 'Сканировать QR-код',
                onPressed: _showQrSourceSelection,
              ),

              const SizedBox(height: 20),

              _AuthCard(
                icon: Icons.file_open_outlined,
                title: 'Вход по файлу сессии',
                subtitle:
                    'Загрузите ранее экспортированный .json или .ksession файл для восстановления сессии.',
                buttonLabel: 'Загрузить файл',
                onPressed: _loadSessionFile,
                isOutlined: true,
              ),

              const SizedBox(height: 20),

              _AuthCard(
                icon: Icons.vpn_key_outlined,
                title: 'Вход по токену',
                subtitle: 'Введите токен авторизации (AUTH_TOKEN) вручную.',
                buttonLabel: 'Войти с токеном',
                onPressed: _loginWithToken,
                isOutlined: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextField(
                    controller: _tokenController,
                    decoration: const InputDecoration(
                      labelText: 'Токен',
                      border: OutlineInputBorder(),
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
    );
  }
}

class _AuthCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool isOutlined;
  final Widget? child;

  const _AuthCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.isOutlined = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: isOutlined ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOutlined
            ? BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (child != null) ...[const SizedBox(height: 20), child!],
            const SizedBox(height: 20),
            isOutlined
                ? OutlinedButton(onPressed: onPressed, child: Text(buttonLabel))
                : FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

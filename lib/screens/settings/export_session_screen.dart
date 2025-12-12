import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/utils/proxy_service.dart';
import 'package:gwid/utils/spoofing_service.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart' as crypto;

class ExportSessionScreen extends StatefulWidget {
  const ExportSessionScreen({super.key});

  @override
  State<ExportSessionScreen> createState() => _ExportSessionScreenState();
}

class _ExportSessionScreenState extends State<ExportSessionScreen> {
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isExporting = false;
  bool _saveProxySettings = false;

  Future<void> _exportAndSaveSession() async {
    if (!mounted) return;
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final spoofData = await SpoofingService.getSpoofedSessionData();
      final token = ApiService.instance.token;

      if (token == null || token.isEmpty) {
        throw Exception('Токен пользователя не найден.');
      }

      final sessionData = <String, dynamic>{
        'token': token,
        'spoof_data': spoofData ?? 'Подмена устройства неактивна',
      };

      if (_saveProxySettings) {
        final proxySettings = await ProxyService.instance.loadProxySettings();
        sessionData['proxy_settings'] = proxySettings.toJson();
      }

      const jsonEncoder = JsonEncoder.withIndent('  ');
      final plainJsonContent = jsonEncoder.convert(sessionData);
      String finalFileContent;
      final password = _passwordController.text;

      if (password.isNotEmpty) {
        final keyBytes = utf8.encode(password);
        final keyHash = crypto.sha256.convert(keyBytes);
        final key = encrypt.Key(Uint8List.fromList(keyHash.bytes));
        final iv = encrypt.IV.fromLength(16);
        final encrypter = encrypt.Encrypter(
          encrypt.AES(key, mode: encrypt.AESMode.cbc),
        );
        final encrypted = encrypter.encrypt(plainJsonContent, iv: iv);
        final encryptedOutput = {
          'encrypted': true,
          'iv_base64': iv.base64,
          'data_base64': encrypted.base64,
        };
        finalFileContent = jsonEncoder.convert(encryptedOutput);
      } else {
        finalFileContent = plainJsonContent;
      }

      Uint8List bytes = Uint8List.fromList(utf8.encode(finalFileContent));

      final String fileName =
          'komet_session_${DateTime.now().millisecondsSinceEpoch}.ksession';

      String? outputFile;

      if (Platform.isAndroid || Platform.isIOS) {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить файл сессии...',
          fileName: fileName,
          allowedExtensions: ['ksession'],
          type: FileType.custom,
          bytes: bytes,
        );
      } else {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить файл сессии...',
          fileName: fileName,
          allowedExtensions: ['ksession'],
          type: FileType.custom,
        );

        if (outputFile != null) {
          if (!outputFile.endsWith('.ksession')) {
            outputFile += '.ksession';
          }

          final File file = File(outputFile);
          await file.writeAsBytes(bytes);
        }
      }

      if (outputFile == null) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Сохранение отменено')),
          );
        }
        return;
      }

      if (mounted) {
        String displayPath = outputFile;
        if (Platform.isAndroid || Platform.isIOS) {
          displayPath = fileName;
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text('Файл сессии успешно сохранен: $displayPath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Не удалось экспортировать сессию: $e'),
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Экспорт сессии')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.upload_file_outlined,
                  size: 40,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Резервная копия сессии',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте зашифрованный файл для переноса вашего аккаунта на другое устройство без повторной авторизации.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            Text(
              '1. Защитите файл паролем',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Настоятельно рекомендуется установить пароль для шифрования (AES-256). Без него файл будет сохранен в открытом виде.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Пароль (необязательно)',
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '2. Дополнительные данные',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            Card(
              margin: EdgeInsets.zero,
              child: CheckboxListTile(
                title: const Text('Сохранить настройки прокси'),
                subtitle: const Text(
                  'Включить текущие параметры прокси в файл экспорта.',
                ),
                value: _saveProxySettings,
                onChanged: (bool? value) =>
                    setState(() => _saveProxySettings = value ?? false),
                controlAffinity:
                    ListTileControlAffinity.leading, 
              ),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.error,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Никогда и никому не передавайте этот файл. Он дает полный доступ к вашему аккаунту.',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _isExporting ? null : _exportAndSaveSession,
              icon: _isExporting
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.download_for_offline_outlined),
              label: Text(
                _isExporting ? 'Сохранение...' : 'Экспортировать и сохранить',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

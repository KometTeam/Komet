import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komet/core/config/spoof_data.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';

class SpoffRedactedScreen extends StatefulWidget {
  const SpoffRedactedScreen({super.key});

  @override
  State<SpoffRedactedScreen> createState() => _SpoffRedactedScreenState();
}

class _SpoffRedactedScreenState extends State<SpoffRedactedScreen> {
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _osVersionController = TextEditingController();
  final TextEditingController _resolutionController = TextEditingController();
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _architectureController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final random = Random();

    setState(() {
      _deviceNameController.text =
          prefs.getString('spoof_device_name') ??
          SpoofData.deviceNames[random.nextInt(SpoofData.deviceNames.length)];
      _osVersionController.text =
          prefs.getString('spoof_os_version') ??
          SpoofData.osVersions[random.nextInt(SpoofData.osVersions.length)];
      _resolutionController.text =
          prefs.getString('spoof_resolution') ??
          SpoofData.resolutions[random.nextInt(SpoofData.resolutions.length)];
      _deviceIdController.text =
          prefs.getString('spoof_device_id') ??
          SpoofData.deviceIds[random.nextInt(SpoofData.deviceIds.length)];
      _architectureController.text =
          prefs.getString('spoof_architecture') ??
          SpoofData.architectures[random.nextInt(
            SpoofData.architectures.length,
          )];
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spoof_device_name', _deviceNameController.text);
    await prefs.setString('spoof_os_version', _osVersionController.text);
    await prefs.setString('spoof_resolution', _resolutionController.text);
    await prefs.setString('spoof_device_id', _deviceIdController.text);
    await prefs.setString('spoof_architecture', _architectureController.text);

    if (mounted) {
      showCustomNotification(context, 'Настройки сохранены');
    }
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _osVersionController.dispose();
    _resolutionController.dispose();
    _deviceIdController.dispose();
    _architectureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          'Подделка спуфа',
          style: GoogleFonts.inter(
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: cs.primary),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTextField(
              controller: TextEditingController(text: SpoofData.deviceType),
              label: 'Тип устройства',
              cs: cs,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _deviceNameController,
              label: 'Имя устройства',
              cs: cs,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _osVersionController,
              label: 'Версия ОС',
              cs: cs,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _resolutionController,
              label: 'Разрешение экрана',
              cs: cs,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: TextEditingController(text: SpoofData.timezone),
              label: 'Часовой пояс',
              cs: cs,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: TextEditingController(text: SpoofData.locale),
              label: 'Локаль',
              cs: cs,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _deviceIdController,
              label: 'ID устройства',
              cs: cs,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: TextEditingController(text: SpoofData.appVersion),
              label: 'Версия приложения',
              cs: cs,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: TextEditingController(text: SpoofData.buildNumber),
              label: 'Build Number',
              cs: cs,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _architectureController,
              label: 'Архитектура',
              cs: cs,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required ColorScheme cs,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: GoogleFonts.inter(
            color: readOnly ? cs.onSurfaceVariant : cs.onSurface,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly
                ? cs.surfaceContainerHighest
                : cs.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

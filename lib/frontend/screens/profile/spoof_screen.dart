import 'dart:math';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/spoof_data.dart';
import '../../widgets/custom_notification.dart';

class SpoofScreen extends StatefulWidget {
  const SpoofScreen({super.key});

  @override
  State<SpoofScreen> createState() => _SpoofScreenState();
}

class _SpoofScreenState extends State<SpoofScreen> {
  final _deviceTypeController = TextEditingController();
  final _deviceNameController = TextEditingController();
  final _osVersionController = TextEditingController();
  final _screenController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _localeController = TextEditingController();
  final _deviceLocaleController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _appVersionController = TextEditingController();
  final _buildNumberController = TextEditingController();
  final _architectureController = TextEditingController();
  final _pushDeviceTypeController = TextEditingController();
  final _mtInstanceIdController = TextEditingController();
  final _clientSessionIdController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final random = Random();

    setState(() {
      _deviceTypeController.text = prefs.getString('spoof_device_type') ?? SpoofData.deviceType;
      _deviceNameController.text = prefs.getString('spoof_device_name') ?? 
          SpoofData.deviceNames[random.nextInt(SpoofData.deviceNames.length)];
      _osVersionController.text = prefs.getString('spoof_os_version') ?? 
          'Android ${SpoofData.osVersions[random.nextInt(SpoofData.osVersions.length)]}';
      _screenController.text = prefs.getString('spoof_screen') ?? 
          SpoofData.resolutions[random.nextInt(SpoofData.resolutions.length)];
      _timezoneController.text = prefs.getString('spoof_timezone') ?? SpoofData.timezone;
      _localeController.text = prefs.getString('spoof_locale') ?? SpoofData.locale;
      _deviceLocaleController.text = prefs.getString('spoof_device_locale') ?? 'ru';
      _deviceIdController.text = prefs.getString('spoof_device_id') ?? 
          SpoofData.deviceIds[random.nextInt(SpoofData.deviceIds.length)];
      _appVersionController.text = prefs.getString('spoof_app_version') ?? SpoofData.appVersion;
      _buildNumberController.text = prefs.getString('spoof_build_number') ?? SpoofData.buildNumber;
      _architectureController.text = prefs.getString('spoof_architecture') ?? 
          SpoofData.architectures[random.nextInt(SpoofData.architectures.length)];
      _pushDeviceTypeController.text = prefs.getString('spoof_push_device_type') ?? 'GCM';
      _mtInstanceIdController.text = prefs.getString('spoof_mt_instanceid') ?? 
          '550e8400-e29b-41d4-a716-446655440000';
      _clientSessionIdController.text = prefs.getString('spoof_client_session_id') ?? '42';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spoof_device_type', _deviceTypeController.text);
    await prefs.setString('spoof_device_name', _deviceNameController.text);
    await prefs.setString('spoof_os_version', _osVersionController.text);
    await prefs.setString('spoof_screen', _screenController.text);
    await prefs.setString('spoof_timezone', _timezoneController.text);
    await prefs.setString('spoof_locale', _localeController.text);
    await prefs.setString('spoof_device_locale', _deviceLocaleController.text);
    await prefs.setString('spoof_device_id', _deviceIdController.text);
    await prefs.setString('spoof_app_version', _appVersionController.text);
    await prefs.setString('spoof_build_number', _buildNumberController.text);
    await prefs.setString('spoof_architecture', _architectureController.text);
    await prefs.setString('spoof_push_device_type', _pushDeviceTypeController.text);
    await prefs.setString('spoof_mt_instanceid', _mtInstanceIdController.text);
    await prefs.setString('spoof_client_session_id', _clientSessionIdController.text);

    if (mounted) {
      showCustomNotification(context, 'Настройки сохранены');
    }
  }

  Future<void> _randomizeAll() async {
    final random = Random();
    setState(() {
      _deviceNameController.text = SpoofData.deviceNames[random.nextInt(SpoofData.deviceNames.length)];
      _osVersionController.text = 'Android ${SpoofData.osVersions[random.nextInt(SpoofData.osVersions.length)]}';
      _screenController.text = SpoofData.resolutions[random.nextInt(SpoofData.resolutions.length)];
      _deviceIdController.text = SpoofData.deviceIds[random.nextInt(SpoofData.deviceIds.length)];
      _architectureController.text = SpoofData.architectures[random.nextInt(SpoofData.architectures.length)];
    });
    await _saveSettings();
    if (mounted) {
      showCustomNotification(context, 'Данные рандомизированы');
    }
  }

  @override
  void dispose() {
    _deviceTypeController.dispose();
    _deviceNameController.dispose();
    _osVersionController.dispose();
    _screenController.dispose();
    _timezoneController.dispose();
    _localeController.dispose();
    _deviceLocaleController.dispose();
    _deviceIdController.dispose();
    _appVersionController.dispose();
    _buildNumberController.dispose();
    _architectureController.dispose();
    _pushDeviceTypeController.dispose();
    _mtInstanceIdController.dispose();
    _clientSessionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
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
                child: _buildSection(cs, [
                  _buildField(cs, 'Тип устройства', _deviceTypeController),
                  _buildField(cs, 'Имя устройства', _deviceNameController),
                  _buildField(cs, 'Версия ОС', _osVersionController),
                  _buildField(cs, 'Разрешение экрана', _screenController),
                  _buildField(cs, 'Архитектура', _architectureController),
                  _buildField(cs, 'ID устройства', _deviceIdController),
                  _buildField(cs, 'Часовой пояс', _timezoneController),
                  _buildField(cs, 'Локаль', _localeController),
                  _buildField(cs, 'Локаль устройства', _deviceLocaleController),
                  _buildField(cs, 'Версия приложения', _appVersionController),
                  _buildField(cs, 'Build Number', _buildNumberController),
                  _buildField(cs, 'Push Device Type', _pushDeviceTypeController),
                  _buildField(cs, 'MT Instance ID', _mtInstanceIdController),
                  _buildField(cs, 'Client Session ID', _clientSessionIdController, isLast: true),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: _buildActionButtons(cs),
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
            icon: Icon(Symbols.arrow_back, color: cs.onSurface, size: 24, weight: 400),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            'Подделка данных',
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



  Widget _buildSection(ColorScheme cs, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildField(
    ColorScheme cs,
    String label,
    TextEditingController controller, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _randomizeAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurface,
                side: BorderSide(color: cs.outline, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Symbols.shuffle, size: 18, weight: 400),
                  const SizedBox(width: 6),
                  const Text(
                    'Рандомизировать',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _saveSettings,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Сохранить',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

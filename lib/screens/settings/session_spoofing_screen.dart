import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:gwid/services/version_checker.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/utils/device_presets.dart';

enum SpoofingMethod { partial, full }

class SessionSpoofingScreen extends StatefulWidget {
  const SessionSpoofingScreen({super.key});

  @override
  State<SessionSpoofingScreen> createState() => _SessionSpoofingScreenState();
}

class _SessionSpoofingScreenState extends State<SessionSpoofingScreen> {
  final _random = Random();
  final _deviceNameController = TextEditingController();
  final _osVersionController = TextEditingController();
  final _screenController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _localeController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _appVersionController = TextEditingController();
  final _buildNumberController = TextEditingController();

  String _selectedDeviceType = 'ANDROID';
  String _selectedArch = 'arm64-v8a';
  SpoofingMethod _selectedMethod = SpoofingMethod.partial;
  bool _isCheckingVersion = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  String _generateDeviceId() {
    // Generate 16-character hex string (like f8268babd84e35a5)
    final bytes = List<int>.generate(8, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final isSpoofingEnabled = prefs.getBool('spoofing_enabled') ?? false;

    if (isSpoofingEnabled) {
      _deviceNameController.text = prefs.getString('spoof_devicename') ?? '';
      _osVersionController.text = prefs.getString('spoof_osversion') ?? '';
      _screenController.text = prefs.getString('spoof_screen') ?? '';
      _timezoneController.text = prefs.getString('spoof_timezone') ?? '';
      _localeController.text = prefs.getString('spoof_locale') ?? '';
      _deviceIdController.text = prefs.getString('spoof_deviceid') ?? '';
      _appVersionController.text =
          prefs.getString('spoof_appversion') ?? '25.21.3';
      _selectedArch = prefs.getString('spoof_arch') ?? 'arm64-v8a';
      _buildNumberController.text =
          prefs.getInt('spoof_buildnumber')?.toString() ?? '6498';

      String savedType = prefs.getString('spoof_devicetype') ?? 'ANDROID';
      if (savedType == 'WEB') {
        savedType = 'ANDROID';
      }
      _selectedDeviceType = savedType;
    } else {
      await _applyGeneratedData();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadDeviceData() async {
    setState(() => _isLoading = true);

    final deviceInfo = DeviceInfoPlugin();
    final pixelRatio = View.of(context).devicePixelRatio;
    final size = View.of(context).physicalSize;

    _appVersionController.text = '25.21.3';
    _localeController.text = Platform.localeName.split('_').first;
    
    // Generate screen in Android format: "xxhdpi 420dpi 1080x2400"
    final dpi = (160 * pixelRatio).round();
    String densityBucket;
    if (dpi >= 560) {
      densityBucket = 'xxxhdpi';
    } else if (dpi >= 380) {
      densityBucket = 'xxhdpi';
    } else if (dpi >= 280) {
      densityBucket = 'xhdpi';
    } else if (dpi >= 200) {
      densityBucket = 'hdpi';
    } else if (dpi >= 140) {
      densityBucket = 'mdpi';
    } else {
      densityBucket = 'ldpi';
    }
    _screenController.text =
        '$densityBucket ${dpi}dpi ${size.width.round()}x${size.height.round()}';
    _deviceIdController.text = _generateDeviceId();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      _timezoneController.text = timezoneInfo.identifier;
    } catch (e) {
      _timezoneController.text = 'Europe/Moscow';
    }

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _deviceNameController.text =
          '${androidInfo.manufacturer} ${androidInfo.model}';
      _osVersionController.text = 'Android ${androidInfo.version.release}';
      _selectedDeviceType = 'ANDROID';
      _selectedArch = androidInfo.supportedAbis.isNotEmpty 
          ? androidInfo.supportedAbis.first 
          : 'arm64-v8a';
      _buildNumberController.text = '6498';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceNameController.text = iosInfo.name;
      _osVersionController.text =
          '${iosInfo.systemName} ${iosInfo.systemVersion}';
      _selectedDeviceType = 'IOS';
      _selectedArch = 'arm64';
      _buildNumberController.text = '6498';
    } else {
      await _applyGeneratedData();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _applyGeneratedData() async {
    final filteredPresets = devicePresets
        .where((p) => p.deviceType != 'WEB' && p.deviceType == _selectedDeviceType)
        .toList();

    if (filteredPresets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Нет доступных пресетов для типа устройства $_selectedDeviceType.'),
          ),
        );
      }
      return;
    }

    final preset = filteredPresets[_random.nextInt(filteredPresets.length)];
    await _applyPreset(preset);
  }

  Future<void> _applyPreset(DevicePreset preset) async {
    setState(() {
      _deviceNameController.text = preset.deviceName;
      _osVersionController.text = preset.osVersion;
      _screenController.text = preset.screen;
      _appVersionController.text = '25.21.3';
      _deviceIdController.text = _generateDeviceId();

      _selectedDeviceType = preset.deviceType;
      
      // Set arch based on device type
      if (preset.deviceType == 'ANDROID') {
        _selectedArch = 'arm64-v8a';
      } else if (preset.deviceType == 'IOS') {
        _selectedArch = 'arm64';
      } else {
        _selectedArch = 'x86_64';
      }
      _buildNumberController.text = '6498';

      if (_selectedMethod == SpoofingMethod.full) {
        _timezoneController.text = preset.timezone;
        _localeController.text = preset.locale;
      }
    });

    if (_selectedMethod == SpoofingMethod.partial) {
      String timezone;
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        timezone = timezoneInfo.identifier;
      } catch (_) {
        timezone = 'Europe/Moscow';
      }
      final locale = Platform.localeName.split('_').first;

      if (mounted) {
        setState(() {
          _timezoneController.text = timezone;
          _localeController.text = locale;
        });
      }
    }
  }

  Future<void> _saveSpoofingSettings() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();

    final oldValues = {
      'device_name': prefs.getString('spoof_devicename') ?? '',
      'os_version': prefs.getString('spoof_osversion') ?? '',
      'screen': prefs.getString('spoof_screen') ?? '',
      'timezone': prefs.getString('spoof_timezone') ?? '',
      'locale': prefs.getString('spoof_locale') ?? '',
      'device_id': prefs.getString('spoof_deviceid') ?? '',
      'device_type': prefs.getString('spoof_devicetype') ?? 'ANDROID',
      'arch': prefs.getString('spoof_arch') ?? '',
      'build_number': prefs.getInt('spoof_buildnumber')?.toString() ?? '',
    };

    final newValues = {
      'device_name': _deviceNameController.text,
      'os_version': _osVersionController.text,
      'screen': _screenController.text,
      'timezone': _timezoneController.text,
      'locale': _localeController.text,
      'device_id': _deviceIdController.text,
      'device_type': _selectedDeviceType,
      'arch': _selectedArch,
      'build_number': _buildNumberController.text,
    };

    final oldAppVersion = prefs.getString('spoof_appversion') ?? '25.21.3';
    final newAppVersion = _appVersionController.text;

    bool otherDataChanged = false;
    for (final key in oldValues.keys) {
      if (oldValues[key] != newValues[key]) {
        otherDataChanged = true;
        break;
      }
    }

    final appVersionChanged = oldAppVersion != newAppVersion;

    if (appVersionChanged && !otherDataChanged) {
      await _saveAllData(prefs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Перезайди!'),
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pop();
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Применить настройки?'),
          content: const Text('Нужно перезайти в приложение, ок?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Не'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ок!'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      await _saveAllData(prefs);

      try {
        await ApiService.instance.performFullReconnection();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Настройки применены. Перезайдите в приложение.'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при применении настроек: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveAllData(SharedPreferences prefs) async {
    await prefs.setBool('spoofing_enabled', true);
    await prefs.setString('spoof_devicename', _deviceNameController.text);
    await prefs.setString('spoof_osversion', _osVersionController.text);
    await prefs.setString('spoof_screen', _screenController.text);
    await prefs.setString('spoof_timezone', _timezoneController.text);
    await prefs.setString('spoof_locale', _localeController.text);
    await prefs.setString('spoof_deviceid', _deviceIdController.text);
    await prefs.setString('spoof_devicetype', _selectedDeviceType);
    await prefs.setString('spoof_appversion', _appVersionController.text);
    await prefs.setString('spoof_arch', _selectedArch);
    await prefs.setInt('spoof_buildnumber', int.tryParse(_buildNumberController.text) ?? 6498);
  }

  Future<void> _handleVersionCheck() async {
    if (_isCheckingVersion) return;
    setState(() => _isCheckingVersion = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Проверяю последнюю версию...')),
    );

    try {
      final info = await VersionChecker.getLatestVersionInfo();
      if (mounted) {
        setState(() {
          _appVersionController.text = info['versionName'];
          _buildNumberController.text = info['versionCode'].toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Обновлено: ${info['versionName']} (Build ${info['versionCode']})',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingVersion = false);
      }
    }
  }

  void _generateNewDeviceId() {
    setState(() {
      _deviceIdController.text = _generateDeviceId();
    });
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _osVersionController.dispose();
    _screenController.dispose();
    _timezoneController.dispose();
    _localeController.dispose();
    _deviceIdController.dispose();
    _appVersionController.dispose();
    _buildNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подмена данных сессии'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  _buildSpoofingMethodCard(),
                  const SizedBox(height: 16),
                  _buildDeviceTypeCard(),
                  const SizedBox(height: 24),
                  _buildMainDataCard(),
                  const SizedBox(height: 16),
                  _buildRegionalDataCard(),
                  const SizedBox(height: 16),
                  _buildIdentifiersCard(),
                ],
              ),
            ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            children: const [
              TextSpan(
                text: 'Нажмите ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              WidgetSpan(
                child: Icon(Icons.touch_app, size: 16),
                alignment: PlaceholderAlignment.middle,
              ),
              TextSpan(text: ' "Сгенерировать":\n'),
              TextSpan(
                text: '• Короткое нажатие: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'случайный пресет.\n'),
              TextSpan(
                text: '• Длинное нажатие: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'реальные данные.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSpoofingMethodCard() {
    final theme = Theme.of(context);
    Widget descriptionWidget;

    if (_selectedMethod == SpoofingMethod.partial) {
      descriptionWidget = _buildDescriptionTile(
        icon: Icons.check_circle_outline,
        color: Colors.green.shade700,
        text:
            'Рекомендуемый метод. Используются случайные данные, но ваш реальный часовой пояс и локаль для большей правдоподобности.',
      );
    } else {
      descriptionWidget = _buildDescriptionTile(
        icon: Icons.warning_amber_rounded,
        color: theme.colorScheme.error,
        text:
            'Все данные, включая часовой пояс и локаль, генерируются случайно. Использование этого метода на ваш страх и риск!',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Метод подмены", style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<SpoofingMethod>(
              style: SegmentedButton.styleFrom(shape: const StadiumBorder()),
              segments: const [
                ButtonSegment(
                  value: SpoofingMethod.partial,
                  label: Text('Частичный'),
                  icon: Icon(Icons.security_outlined),
                ),
                ButtonSegment(
                  value: SpoofingMethod.full,
                  label: Text('Полный'),
                  icon: Icon(Icons.public_outlined),
                ),
              ],
              selected: {_selectedMethod},
              onSelectionChanged: (s) =>
                  setState(() => _selectedMethod = s.first),
            ),
            const SizedBox(height: 12),
            descriptionWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTypeCard() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Тип устройства",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildDescriptionTile(
              icon: Icons.info_outline,
              color: theme.colorScheme.primary,
              text:
                  'Выберите тип устройства для генерации пресетов. При нажатии "Сгенерировать" будут использоваться только пресеты выбранного типа.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedDeviceType,
              decoration: _inputDecoration(
                'Тип устройства',
                Icons.devices_other_outlined,
              ),
              items: const [
                DropdownMenuItem(value: 'ANDROID', child: Text('ANDROID')),
                // DropdownMenuItem(value: 'IOS', child: Text('IOS')),
                // DropdownMenuItem(value: 'DESKTOP', child: Text('DESKTOP')),
              ],
              onChanged: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionTile({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      contentPadding: EdgeInsets.zero,
      title: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMainDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, "Основные данные"),
            TextField(
              controller: _deviceNameController,
              decoration: _inputDecoration(
                'Имя устройства',
                Icons.smartphone_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _osVersionController,
              decoration: _inputDecoration('Версия ОС', Icons.layers_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionalDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, "Региональные данные"),
            TextField(
              controller: _screenController,
              decoration: _inputDecoration(
                'Разрешение экрана',
                Icons.fullscreen_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _timezoneController,
              enabled: _selectedMethod == SpoofingMethod.full,
              decoration: _inputDecoration(
                'Часовой пояс',
                Icons.public_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _localeController,
              enabled: _selectedMethod == SpoofingMethod.full,
              decoration: _inputDecoration('Локаль', Icons.language_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentifiersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, "Идентификаторы"),
            _buildDescriptionTile(
              icon: Icons.info_outline,
              color: Theme.of(context).colorScheme.tertiary,
              text:
                  'mt_instanceid и clientSessionId генерируются автоматически при каждом запуске приложения. Изменить можно только Device ID.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deviceIdController,
              decoration: _inputDecoration('ID Устройства', Icons.tag_outlined)
                  .copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.autorenew_outlined),
                  tooltip: 'Сгенерировать новый ID',
                  onPressed: _generateNewDeviceId,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _appVersionController,
              decoration:
                  _inputDecoration(
                    'Версия приложения',
                    Icons.info_outline_rounded,
                  ).copyWith(
                    suffixIcon: _isCheckingVersion
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.cloud_sync_outlined),
                            tooltip: 'Проверить последнюю версию',
                            onPressed: _handleVersionCheck,
                          ),
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _buildNumberController,
              keyboardType: TextInputType.number,
              decoration:
                  _inputDecoration(
                    'Build Number',
                    Icons.numbers_outlined,
                  ).copyWith(
                    suffixIcon: _isCheckingVersion
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.cloud_sync_outlined),
                            tooltip: 'Обновить из RuStore',
                            onPressed: _handleVersionCheck,
                          ),
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedArch,
              decoration: _inputDecoration(
                'Архитектура',
                Icons.memory_outlined,
              ),
              items: const [
                DropdownMenuItem(value: 'arm64-v8a', child: Text('arm64-v8a (64-bit ARM)')),
                DropdownMenuItem(value: 'armeabi-v7a', child: Text('armeabi-v7a (32-bit ARM)')),
                DropdownMenuItem(value: 'x86', child: Text('x86 (32-bit Intel)')),
                DropdownMenuItem(value: 'x86_64', child: Text('x86_64 (64-bit Intel)')),
                DropdownMenuItem(value: 'arm64', child: Text('arm64 (iOS/Desktop)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedArch = value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildFloatingActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: FilledButton.tonal(
              onPressed: _applyGeneratedData,
              onLongPress: _loadDeviceData,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                shape: const StadiumBorder(),
              ),
              child: const Text('Сгенерировать'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: FilledButton(
              onPressed: _saveSpoofingSettings,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                shape: const StadiumBorder(),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_alt_outlined),
                  SizedBox(width: 8),
                  Text('Применить'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

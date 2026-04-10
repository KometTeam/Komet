import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/device_presets.dart';
import '../../../core/storage/spoofing_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

enum SpoofingMethod { partial, full }

class SpoofScreen extends StatefulWidget {
  const SpoofScreen({super.key});

  @override
  State<SpoofScreen> createState() => _SpoofScreenState();
}

class _SpoofScreenState extends State<SpoofScreen> {
  static const String _hardcodedVersion = SpoofingService.hardcodedAppVersion;
  static const int _hardcodedBuildNumber =
      SpoofingService.hardcodedBuildNumber;

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  String _generateDeviceId() {
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
          prefs.getString('spoof_appversion') ?? _hardcodedVersion;
      _selectedArch = prefs.getString('spoof_arch') ?? 'arm64-v8a';
      _buildNumberController.text =
          prefs.getInt('spoof_buildnumber')?.toString() ??
          '$_hardcodedBuildNumber';

      String savedType = prefs.getString('spoof_devicetype') ?? 'ANDROID';
      if (savedType == 'WEB') savedType = 'ANDROID';
      _selectedDeviceType = savedType;
      if (mounted) setState(() => _isLoading = false);
    } else {
      await _loadDeviceData();
    }
  }

  Future<void> _loadDeviceData() async {
    setState(() => _isLoading = true);

    final deviceInfo = DeviceInfoPlugin();
    final pixelRatio = View.of(context).devicePixelRatio;
    final size = View.of(context).physicalSize;

    _appVersionController.text = _hardcodedVersion;
    _localeController.text = Platform.localeName.split('_').first;

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

    final prefs = await SharedPreferences.getInstance();
    var realDeviceId = prefs.getString('real_device_id');
    if (realDeviceId == null || realDeviceId.isEmpty) {
      realDeviceId = _generateDeviceId();
      await prefs.setString('real_device_id', realDeviceId);
    }
    _deviceIdController.text = realDeviceId;

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      _timezoneController.text = timezoneInfo.identifier;
    } catch (_) {
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
      _buildNumberController.text = '$_hardcodedBuildNumber';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceNameController.text = iosInfo.name;
      _osVersionController.text =
          '${iosInfo.systemName} ${iosInfo.systemVersion}';
      _selectedDeviceType = 'IOS';
      _selectedArch = 'arm64';
      _buildNumberController.text = '$_hardcodedBuildNumber';
    } else {
      await _applyGeneratedData();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _applyGeneratedData() async {
    final filteredPresets = devicePresets
        .where(
          (p) => p.deviceType != 'WEB' && p.deviceType == _selectedDeviceType,
        )
        .toList();

    if (filteredPresets.isEmpty) return;

    final preset = filteredPresets[_random.nextInt(filteredPresets.length)];
    await _applyPreset(preset);
  }

  Future<void> _applyPreset(DevicePreset preset) async {
    setState(() {
      _deviceNameController.text = preset.deviceName;
      _osVersionController.text = preset.osVersion;
      _screenController.text = preset.screen;
      _appVersionController.text = _hardcodedVersion;
      _deviceIdController.text = _generateDeviceId();

      _selectedDeviceType = preset.deviceType;

      if (preset.deviceType == 'ANDROID') {
        _selectedArch = 'arm64-v8a';
      } else if (preset.deviceType == 'IOS') {
        _selectedArch = 'arm64';
      } else {
        _selectedArch = 'x86_64';
      }
      _buildNumberController.text = '$_hardcodedBuildNumber';

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

    final oldAppVersion =
        prefs.getString('spoof_appversion') ?? _hardcodedVersion;
    final newAppVersion = _appVersionController.text;

    bool otherDataChanged = false;
    for (final key in oldValues.keys) {
      if (oldValues[key] != newValues[key]) {
        otherDataChanged = true;
        break;
      }
    }

    final appVersionChanged = oldAppVersion != newAppVersion;
    final isChangingAwayFromHardcoded = newAppVersion != _hardcodedVersion;

    if (appVersionChanged && isChangingAwayFromHardcoded) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.spoofDialogUnsureTitle),
          content: Text(l10n.spoofDialogUnsureContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.spoofDialogCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.spoofDialogYes),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (appVersionChanged && !otherDataChanged) {
      await _saveAllData(prefs);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.spoofDialogApplyTitle),
        content: Text(l10n.spoofDialogApplyContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.spoofDialogApplyDeny),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.spoofDialogApplyConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _saveAllData(prefs);

    try {
      await api.disconnect();
      await api.connect();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.spoofErrorApplyFailed(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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
    await prefs.setInt(
      'spoof_buildnumber',
      int.tryParse(_buildNumberController.text) ?? _hardcodedBuildNumber,
    );
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.spoofScreenTitle),
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
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.secondaryContainer.withValues(alpha: 0.5),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app,
              size: 18,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.spoofInfoHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpoofingMethodCard() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    Widget descriptionWidget;

    if (_selectedMethod == SpoofingMethod.partial) {
      descriptionWidget = _buildDescriptionTile(
        icon: Icons.check_circle_outline,
        color: Colors.green.shade700,
        text: l10n.spoofMethodPartialDescription,
      );
    } else {
      descriptionWidget = _buildDescriptionTile(
        icon: Icons.warning_amber_rounded,
        color: theme.colorScheme.error,
        text: l10n.spoofMethodFullDescription,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(l10n.spoofMethodTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<SpoofingMethod>(
              style: SegmentedButton.styleFrom(shape: const StadiumBorder()),
              segments: [
                ButtonSegment(
                  value: SpoofingMethod.partial,
                  label: Text(l10n.spoofMethodPartial),
                  icon: const Icon(Icons.security_outlined),
                ),
                ButtonSegment(
                  value: SpoofingMethod.full,
                  label: Text(l10n.spoofMethodFull),
                  icon: const Icon(Icons.public_outlined),
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
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.spoofDeviceTypeTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildDescriptionTile(
              icon: Icons.info_outline,
              color: theme.colorScheme.primary,
              text: l10n.spoofDeviceTypeDescription,
            ),
            const SizedBox(height: 12),
            _buildChipSelector<String>(
              options: const [
                _ChipOption('ANDROID', 'ANDROID', Icons.android_outlined),
                _ChipOption('IOS', 'iOS', Icons.phone_iphone_outlined),
                _ChipOption(
                  'DESKTOP',
                  'Desktop',
                  Icons.desktop_windows_outlined,
                ),
              ],
              selected: _selectedDeviceType,
              onSelected: (value) {
                setState(() {
                  _selectedDeviceType = value;
                  if (value == 'ANDROID') {
                    _selectedArch = 'arm64-v8a';
                  } else if (value == 'IOS') {
                    _selectedArch = 'arm64';
                  } else {
                    _selectedArch = 'x86_64';
                  }
                });
              },
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
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, l10n.spoofMainSectionTitle),
            TextField(
              controller: _deviceNameController,
              decoration: _inputDecoration(
                l10n.spoofFieldDeviceName,
                Icons.smartphone_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _osVersionController,
              decoration: _inputDecoration(
                l10n.spoofFieldOsVersion,
                Icons.layers_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionalDataCard() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, l10n.spoofRegionalSectionTitle),
            TextField(
              controller: _screenController,
              decoration: _inputDecoration(
                l10n.spoofFieldScreen,
                Icons.fullscreen_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _timezoneController,
              enabled: _selectedMethod == SpoofingMethod.full,
              decoration: _inputDecoration(
                l10n.spoofFieldTimezone,
                Icons.public_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _localeController,
              enabled: _selectedMethod == SpoofingMethod.full,
              decoration: _inputDecoration(
                l10n.spoofFieldLocale,
                Icons.language_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentifiersCard() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, l10n.spoofIdentifiersSectionTitle),
            _buildDescriptionTile(
              icon: Icons.info_outline,
              color: Theme.of(context).colorScheme.tertiary,
              text: l10n.spoofIdentifiersDescription,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deviceIdController,
              decoration:
                  _inputDecoration(l10n.spoofFieldDeviceId, Icons.tag_outlined)
                      .copyWith(
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.autorenew_outlined),
                          tooltip: l10n.spoofRegenerateIdTooltip,
                          onPressed: _generateNewDeviceId,
                        ),
                      ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _appVersionController,
              decoration: _inputDecoration(
                l10n.spoofFieldAppVersion,
                Icons.info_outline_rounded,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _buildNumberController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                l10n.spoofFieldBuildNumber,
                Icons.numbers_outlined,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                l10n.spoofFieldArchitecture,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _buildChipSelector<String>(
              options: const [
                _ChipOption('arm64-v8a', 'arm64-v8a', Icons.memory_outlined),
                _ChipOption(
                  'armeabi-v7a',
                  'armeabi-v7a',
                  Icons.memory_outlined,
                ),
                _ChipOption('x86', 'x86', Icons.memory_outlined),
                _ChipOption('x86_64', 'x86_64', Icons.memory_outlined),
                _ChipOption('arm64', 'arm64', Icons.memory_outlined),
              ],
              selected: _selectedArch,
              onSelected: (value) =>
                  setState(() => _selectedArch = value),
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

  Widget _buildChipSelector<T>({
    required List<_ChipOption<T>> options,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt.value == selected;
        return ChoiceChip(
          label: Text(opt.label),
          avatar: isSelected
              ? Icon(Icons.check, size: 18, color: cs.onSecondaryContainer)
              : (opt.icon != null
                    ? Icon(opt.icon, size: 18, color: cs.onSurfaceVariant)
                    : null),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => onSelected(opt.value),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? cs.onSecondaryContainer : cs.onSurface,
          ),
          backgroundColor: cs.surfaceContainerHighest,
          selectedColor: cs.secondaryContainer,
          side: BorderSide(
            color: isSelected ? Colors.transparent : cs.outlineVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  Widget _buildFloatingActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
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
              child: Text(l10n.spoofButtonGenerate),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: FilledButton(
              onPressed: _saveSpoofingSettings,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save_alt_outlined),
                  const SizedBox(width: 8),
                  Text(l10n.spoofButtonApply),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const _ChipOption(this.value, this.label, [this.icon]);
}

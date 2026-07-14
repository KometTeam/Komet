import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../core/config/device_presets.dart';
import '../../../core/storage/device_identity.dart';
import '../../../core/storage/spoofing_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/spoof_profile.dart';
import '../../../main.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/info_action_sheet.dart';
import '../../widgets/section_header.dart';
import '../../widgets/small_spinner.dart';
import '../auth/login_screen.dart';

enum SpoofingMethod { partial, full }

class SpoofScreen extends StatefulWidget {
  const SpoofScreen({super.key});

  @override
  State<SpoofScreen> createState() => _SpoofScreenState();
}

class _SpoofScreenState extends State<SpoofScreen> {
  static const String _hardcodedVersion = SpoofingService.hardcodedAppVersion;
  static const int _hardcodedBuildNumber = SpoofingService.hardcodedBuildNumber;

  final _random = Random();
  final _deviceNameController = TextEditingController();
  final _osVersionController = TextEditingController();
  final _screenController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _localeController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _appVersionController = TextEditingController();
  final _buildNumberController = TextEditingController();
  final _instanceIdController = TextEditingController();
  final _clientSessionIdController = TextEditingController();
  final _deviceLocaleController = TextEditingController();
  final _pushDeviceTypeController = TextEditingController(text: 'GCM');

  String _selectedDeviceType = 'ANDROID';
  String _selectedArch = 'arm64-v8a';
  String _userAgent = '';
  bool _spoofingEnabled = false;
  SpoofProfile? _initialProfile;
  SpoofingMethod _selectedMethod = SpoofingMethod.partial;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _localeController.addListener(_syncDeviceLocale);
    _loadInitialData();
  }

  void _syncDeviceLocale() {
    if (_selectedMethod == SpoofingMethod.full) return;
    final derived = _localeController.text.split(RegExp(r'[-_]')).first;
    if (_deviceLocaleController.text != derived) {
      _deviceLocaleController.text = derived;
    }
  }

  Future<bool> _confirmFullSpoofing() {
    return showInfoActionSheet(
      context,
      headerIcon: Icons.warning_amber_rounded,
      title: 'Могут быть последствия.',
      subtitle: 'Меняй, только если знаешь что делаешь.',
      confirmLabel: 'ОК',
      confirmDelay: const Duration(seconds: 3),
    );
  }

  Future<void> _loadSessionIdentifiers() async {
    _instanceIdController.text = await DeviceIdentity.instanceId();
    _clientSessionIdController.text = '${DeviceIdentity.clientSessionId}';
  }

  String _generateDeviceId() {
    final bytes = List<int>.generate(8, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _loadSessionIdentifiers();

    final scope = await SpoofingService.activeScope();
    final profile = await SpoofingService.loadProfile(scope);
    _initialProfile = profile;

    if (profile != null && profile.enabled) {
      _spoofingEnabled = true;
      _applyProfileToControllers(profile);
    } else {
      _spoofingEnabled = false;
      await _loadDeviceData();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyProfileToControllers(SpoofProfile profile) {
    _deviceNameController.text = profile.deviceName;
    _osVersionController.text = profile.osVersion;
    _screenController.text = profile.screen;
    _timezoneController.text = profile.timezone;
    _localeController.text = profile.locale;
    _deviceIdController.text = profile.deviceId;
    _appVersionController.text = profile.appVersion.isEmpty
        ? _hardcodedVersion
        : profile.appVersion;
    _selectedArch = profile.arch.isEmpty ? 'arm64-v8a' : profile.arch;
    _buildNumberController.text = profile.buildNumber == 0
        ? '$_hardcodedBuildNumber'
        : '${profile.buildNumber}';
    _pushDeviceTypeController.text = profile.pushDeviceType.isEmpty
        ? 'GCM'
        : profile.pushDeviceType;
    _userAgent = profile.userAgent;

    if (profile.deviceLocale.isNotEmpty) {
      _deviceLocaleController.text = profile.deviceLocale;
    }
    if (profile.instanceId.isNotEmpty) {
      _instanceIdController.text = profile.instanceId;
    }
    if (profile.clientSessionId != null) {
      _clientSessionIdController.text = '${profile.clientSessionId}';
    }

    var type = profile.deviceType.isEmpty ? 'ANDROID' : profile.deviceType;
    if (type == 'WEB' || type == 'IOS') type = 'ANDROID';
    _selectedDeviceType = type;
    if (type == 'DESKTOP') {
      _selectedMethod = SpoofingMethod.full;
    }
  }

  SpoofProfile _buildProfileFromControllers() {
    return SpoofProfile(
      enabled: _spoofingEnabled,
      deviceName: _deviceNameController.text,
      osVersion: _osVersionController.text,
      screen: _screenController.text,
      timezone: _timezoneController.text,
      locale: _localeController.text,
      deviceLocale: _deviceLocaleController.text,
      deviceId: _deviceIdController.text,
      deviceType: _selectedDeviceType,
      arch: _selectedArch,
      appVersion: _appVersionController.text,
      buildNumber:
          int.tryParse(_buildNumberController.text) ?? _hardcodedBuildNumber,
      pushDeviceType: _pushDeviceTypeController.text,
      instanceId: _instanceIdController.text,
      clientSessionId: int.tryParse(_clientSessionIdController.text),
      userAgent: _userAgent,
    );
  }

  Future<void> _loadDeviceData() async {
    _userAgent = '';
    _spoofingEnabled = false;

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

    _deviceIdController.text = await DeviceIdentity.deviceId();
    _buildNumberController.text = '$_hardcodedBuildNumber';

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      _timezoneController.text = timezoneInfo.identifier;
    } catch (_) {
      _timezoneController.text = 'Europe/Moscow';
    }

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _selectedDeviceType = 'ANDROID';
      _deviceNameController.text =
          '${androidInfo.manufacturer} ${androidInfo.model}';
      _osVersionController.text = 'Android ${androidInfo.version.release}';
      _selectedArch = androidInfo.supportedAbis.isNotEmpty
          ? androidInfo.supportedAbis.first
          : 'arm64-v8a';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _selectedDeviceType = 'ANDROID';
      _selectedArch = 'arm64';
      _deviceNameController.text = iosInfo.utsname.machine;
      _osVersionController.text = iosInfo.systemVersion;
    } else if (Platform.isLinux) {
      final linuxInfo = await deviceInfo.linuxInfo;
      _selectedDeviceType = 'ANDROID';
      _deviceNameController.text = linuxInfo.prettyName;
      _osVersionController.text = linuxInfo.name;
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      _selectedDeviceType = 'ANDROID';
      _deviceNameController.text = windowsInfo.productName;
      _osVersionController.text = windowsInfo.productName;
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfo.macOsInfo;
      _selectedDeviceType = 'ANDROID';
      _deviceNameController.text = macInfo.model;
      _osVersionController.text = 'macOS ${macInfo.osRelease}';
    }

    if (mounted) setState(() {});
  }

  Future<void> _applyGeneratedData() async {
    final type = _selectedMethod == SpoofingMethod.full
        ? _selectedDeviceType
        : 'ANDROID';
    final filteredPresets = devicePresets
        .where((p) => p.deviceType == type)
        .toList();

    if (filteredPresets.isEmpty) return;

    final preset = filteredPresets[_random.nextInt(filteredPresets.length)];
    await _applyPreset(preset);
  }

  void _onDeviceTypeChanged(String type) {
    if (type == _selectedDeviceType) return;
    setState(() => _selectedDeviceType = type);
    if (_spoofingEnabled) _applyGeneratedData();
  }

  Future<void> _applyPreset(DevicePreset preset) async {
    setState(() {
      _deviceNameController.text = preset.deviceName;
      _osVersionController.text = preset.osVersion;
      _screenController.text = preset.screen;
      _appVersionController.text = _hardcodedVersion;
      _deviceIdController.text = _generateDeviceId();
      _userAgent = preset.userAgent;
      _spoofingEnabled = true;

      _selectedDeviceType = preset.deviceType;
      _selectedArch = preset.deviceType == 'IOS' ? 'arm64' : 'arm64-v8a';
      _buildNumberController.text = '$_hardcodedBuildNumber';

      if (_selectedMethod == SpoofingMethod.full) {
        _timezoneController.text = preset.timezone;
        _localeController.text = preset.locale.split(RegExp(r'[-_]')).first;
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

    final newProfile = _buildProfileFromControllers();
    final wasActive = _initialProfile?.enabled ?? false;
    final isActive = newProfile.enabled;
    final bool identityChanged;
    if (!wasActive && !isActive) {
      identityChanged = false;
    } else if (wasActive != isActive) {
      identityChanged = true;
    } else {
      identityChanged =
          jsonEncode(_initialProfile!.toJson()) !=
          jsonEncode(newProfile.toJson());
    }

    if (!identityChanged) {
      await _persistProfile();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.spoofDialogApplyTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.spoofDialogApplyContent),
            const SizedBox(height: 12),
            Text(
              l10n.spoofDialogApplyWarning,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: Text(l10n.spoofDialogApplyDeny),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('relogin'),
            child: Text(l10n.spoofDialogReloginConfirm),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('apply'),
            child: Text(l10n.spoofDialogApplyConfirm),
          ),
        ],
      ),
    );

    if (!mounted || confirmed == null) return;

    if (confirmed == 'relogin') {
      await _persistProfile();
      await api.disconnect();
      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId != null) {
        await TokenStorage.deleteToken(accountId);
      }
      await api.connect();
      if (mounted) {
        final navState = KometApp.navigatorKey.currentState;
        if (navState != null) {
          await navState.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
      return;
    }

    if (confirmed != 'apply') return;

    await _persistProfile();

    try {
      await api.disconnect();
      await api.connect();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.spoofErrorApplyFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _persistProfile() async {
    final scope = await SpoofingService.activeScope();
    final profile = _buildProfileFromControllers();
    await SpoofingService.saveProfile(scope, profile);
    _initialProfile = profile;
  }

  void _generateNewDeviceId() {
    setState(() {
      _deviceIdController.text = _generateDeviceId();
    });
  }

  @override
  void dispose() {
    _localeController.removeListener(_syncDeviceLocale);
    _deviceNameController.dispose();
    _osVersionController.dispose();
    _screenController.dispose();
    _timezoneController.dispose();
    _localeController.dispose();
    _deviceIdController.dispose();
    _appVersionController.dispose();
    _buildNumberController.dispose();
    _instanceIdController.dispose();
    _clientSessionIdController.dispose();
    _deviceLocaleController.dispose();
    _pushDeviceTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: ConnectionTitleText(l10n.spoofScreenTitle),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: SmallSpinner(size: 36))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildEnableCard(),
                  const SizedBox(height: 16),
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

  Widget _buildEnableCard() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          l10n.spoofEnableTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          _spoofingEnabled
              ? l10n.spoofEnableSubtitleOn
              : l10n.spoofEnableSubtitleOff,
        ),
        value: _spoofingEnabled,
        onChanged: (value) async {
          if (value) {
            await _applyGeneratedData();
          } else {
            await _loadDeviceData();
          }
        },
      ),
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
              onSelectionChanged: (s) async {
                final next = s.first;
                if (next == _selectedMethod) return;
                if (next == SpoofingMethod.full) {
                  final confirmed = await _confirmFullSpoofing();
                  if (!confirmed || !mounted) return;
                }
                setState(() => _selectedMethod = next);
                if (next == SpoofingMethod.partial &&
                    _selectedDeviceType != 'ANDROID') {
                  _onDeviceTypeChanged('ANDROID');
                }
                _syncDeviceLocale();
              },
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
            if (_selectedMethod == SpoofingMethod.full)
              _buildChipSelector<String>(
                options: const [
                  _ChipOption('ANDROID', 'Android', Icons.android_outlined),
                  _ChipOption(
                    'DESKTOP',
                    'Desktop',
                    Icons.desktop_windows_outlined,
                  ),
                ],
                selected: _selectedDeviceType,
                onSelected: _onDeviceTypeChanged,
                trailing: [
                  _buildDisabledChip('iOS', Icons.phone_iphone_outlined, theme),
                ],
              )
            else
              _buildChipSelector<String>(
                options: const [
                  _ChipOption('ANDROID', 'Android', Icons.android_outlined),
                ],
                selected: 'ANDROID',
                onSelected: _onDeviceTypeChanged,
                trailing: [
                  _buildDisabledChip('iOS', Icons.phone_iphone_outlined, theme),
                  _buildDisabledChip(
                    'Desktop',
                    Icons.desktop_windows_outlined,
                    theme,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledChip(String label, IconData icon, ThemeData theme) {
    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      side: BorderSide(color: theme.colorScheme.outlineVariant),
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

  Widget _buildMainDataCard() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              l10n.spoofMainSectionTitle,
              padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
              fontSize: 22,
            ),
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
            SectionHeader(
              l10n.spoofRegionalSectionTitle,
              padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
              fontSize: 22,
            ),
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
            const SizedBox(height: 16),
            TextField(
              controller: _deviceLocaleController,
              enabled: _selectedMethod == SpoofingMethod.full,
              decoration: _inputDecoration(
                l10n.spoofFieldDeviceLocale,
                Icons.translate_outlined,
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
            SectionHeader(
              l10n.spoofIdentifiersSectionTitle,
              padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
              fontSize: 22,
            ),
            _buildDescriptionTile(
              icon: Icons.info_outline,
              color: Theme.of(context).colorScheme.tertiary,
              text: l10n.spoofIdentifiersDescription,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instanceIdController,
              enabled: _selectedMethod == SpoofingMethod.full,
              decoration: _inputDecoration(
                l10n.spoofFieldInstanceId,
                Icons.fingerprint_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clientSessionIdController,
              enabled: _selectedMethod == SpoofingMethod.full,
              decoration: _inputDecoration(
                l10n.spoofFieldClientSessionId,
                Icons.vpn_key_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deviceIdController,
              decoration:
                  _inputDecoration(
                    l10n.spoofFieldDeviceId,
                    Icons.tag_outlined,
                  ).copyWith(
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
              enabled: _selectedMethod == SpoofingMethod.full,
              decoration: _inputDecoration(
                l10n.spoofFieldAppVersion,
                Icons.info_outline_rounded,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _buildNumberController,
              enabled: _selectedMethod == SpoofingMethod.full,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                l10n.spoofFieldBuildNumber,
                Icons.numbers_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pushDeviceTypeController,
              enabled: _selectedMethod == SpoofingMethod.full,
              decoration: _inputDecoration(
                l10n.spoofFieldPushDeviceType,
                Icons.notifications_outlined,
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
              onSelected: (value) => setState(() => _selectedArch = value),
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
    List<Widget> trailing = const [],
  }) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...options.map((opt) {
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
        }),
        ...trailing,
      ],
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

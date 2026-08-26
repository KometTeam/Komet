import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/cache/self_presence.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/komet_settings.dart';
import '../../../core/config/app_show_extra_info.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/update_checker.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/animated_slash_icon.dart';
import '../../widgets/avatar_history_screen.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/info_action_sheet.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/profile_header_scroll.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/update_dialog.dart';
import '../auth/login_screen.dart';
import '../auth/proxy_settings_sheet.dart';
import '../../../core/config/app_digital_id_mode.dart';
import '../../../core/utils/webview_support.dart';
import '../digital_id/digital_id_screen.dart';
import '../digital_id/digital_id_web_screen.dart';
import '../webapp/web_app_bridge.dart';
import '../webapp/web_app_screen.dart';
import 'cloud_storage_screen.dart';
import 'customization_section.dart';
import 'debug_menu_screen.dart';
import 'devices_screen.dart';
import '../../widgets/spectrum_tint.dart';
import 'edit_profile_screen.dart';
import 'info_screen.dart';
import 'komet_settings_screen.dart';
import 'notifications_screen.dart';
import 'security_screen.dart';
import 'spoof_screen.dart';
import '../../widgets/media_playback_pill.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/config/app_shape.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with SpectrumSurface {
  ProfileData? _profile;
  bool _isPhoneVisible = false;
  ScrollController? _scrollController;
  double _headerDelta = 0;
  bool _headerEverExpanded = false;
  bool _expandArmed = false;
  bool _headerDragging = false;
  bool _zoneHapticFired = false;
  bool _pastCommitPoint = false;
  String? _appVersionLabel;
  bool _debugMenuVisible = false;
  bool _isCheckingForUpdates = false;
  int _versionSecretTapCount = 0;
  Timer? _versionSecretTapResetTimer;
  StreamSubscription? _profileUpdateSub;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAppVersion();
    final appState = KometApp.stateOf(context);
    if (appState != null) {
      _profileUpdateSub = appState.profileUpdateStream.listen((_) {
        if (mounted) _loadProfile();
      });
    }
  }

  @override
  void dispose() {
    _versionSecretTapResetTimer?.cancel();
    _profileUpdateSub?.cancel();
    _scrollController?.dispose();
    super.dispose();
  }

  void _syncHeaderDelta(double delta) {
    if (_scrollController == null) {
      _scrollController = ScrollController(initialScrollOffset: delta);
      _headerDelta = delta;
      return;
    }
    if (_headerDelta == delta) return;
    final prev = _headerDelta;
    _headerDelta = delta;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _scrollController;
      if (!mounted || c == null || !c.hasClients) return;
      final target = (c.offset + (delta - prev)).clamp(
        0.0,
        c.position.maxScrollExtent,
      );
      c.jumpTo(target);
    });
  }

  bool _handleScrollNotification(ScrollNotification n, double delta) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification) {
      _headerDragging = n.dragDetails != null;
      if (n.dragDetails != null) {
        final px = n.metrics.pixels;
        _expandArmed = delta > 0 && px <= delta + 8;
        _zoneHapticFired = px < delta;
        _pastCommitPoint = px < delta / 2;
      }
    } else if (n is ScrollUpdateNotification) {
      if (n.dragDetails != null && delta > 0) {
        final px = n.metrics.pixels;
        if (px < delta) {
          if (!_zoneHapticFired) {
            _zoneHapticFired = true;
            HapticFeedback.lightImpact();
          }
        } else {
          _zoneHapticFired = false;
        }
        final pastCommit = px < delta / 2;
        if (pastCommit != _pastCommitPoint) {
          _pastCommitPoint = pastCommit;
          HapticFeedback.mediumImpact();
        }
      }
    } else if (n is ScrollEndNotification) {
      if (_headerDragging) {
        _headerDragging = false;
        _snapHeader(delta);
      }
    }
    return false;
  }

  void _snapHeader(double delta) {
    final c = _scrollController;
    if (c == null || !c.hasClients || delta <= 0) return;
    final collapsed = math.min(delta, c.position.maxScrollExtent);
    final offset = c.offset;
    if (offset <= 0 || offset >= collapsed) return;
    final target = offset < collapsed / 2 ? 0.0 : collapsed;
    if ((target - offset).abs() < 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !c.hasClients) return;
      c.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scheduleVersionSecretTapReset() {
    _versionSecretTapResetTimer?.cancel();
    _versionSecretTapResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _versionSecretTapCount = 0);
    });
  }

  void _onVersionLabelTap() {
    _scheduleVersionSecretTapReset();
    setState(() {
      _versionSecretTapCount++;
      if (_versionSecretTapCount >= 7) {
        _versionSecretTapCount = 0;
        _versionSecretTapResetTimer?.cancel();
        _debugMenuVisible = !_debugMenuVisible;
      }
    });
  }

  Future<void> _loadProfile() async {
    final p = await AppDatabase.loadActiveProfile();
    if (mounted) setState(() => _profile = p);
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersionLabel = 'Версия ${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingForUpdates) return;
    setState(() => _isCheckingForUpdates = true);

    final result = await UpdateChecker.checkNow();
    if (!mounted) return;
    setState(() => _isCheckingForUpdates = false);

    switch (result.status) {
      case UpdateCheckStatus.updateAvailable:
        await showUpdateDialog(context, result.update!);
        return;
      case UpdateCheckStatus.upToDate:
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.updateUpToDate,
        );
        return;
      case UpdateCheckStatus.failed:
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.updateCheckFailed,
        );
        return;
    }
  }

  Future<void> _openCloudStorage(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showInfoActionSheet(
      context,
      headerIcon: Symbols.cloud,
      title: 'Облачное хранилище',
      subtitle: 'Через МАХ',
      items: [
        const InfoActionSheetItem(
          icon: Symbols.cloud_done,
          title: 'Работает при белых списках',
          body: 'Вы сможете передать файл даже при ограниченном интернете.',
        ),
        const InfoActionSheetItem(
          icon: Symbols.inventory_2,
          title: 'Файлы до 4ГБ, безлимитное количество.',
          body: 'Можете хранить массивный обьем информации.',
        ),
        InfoActionSheetItem(
          icon: Symbols.gpp_maybe,
          title: 'Не обеспечивается конфединциальность файлов',
          body:
              'Облачное хранилище работает через ваш аккаунт на сервере МАХ, '
              'нужные люди всё равно могут его посмотреть.',
          titleColor: cs.error,
        ),
      ],
      confirmLabel: 'ОК',
      confirmDelay: const Duration(seconds: 3),
      seenKey: 'cloud_storage_intro_seen',
    );
    if (!ok || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CloudStorageScreen()),
    );
  }

  Future<void> _confirmLogout() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Выйти из аккаунта?',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Данные аккаунта будут удалены с этого устройства.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: AppShape.buttonBorder,
                  ),
                  child: const Text('Выйти'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _doLogout();
  }

  Future<void> _doLogout() async {
    final navState = KometApp.navigatorKey.currentState;
    try {
      await accountModule.logout();
    } catch (e) {
      if (mounted) showCustomNotification(context, 'Не удалось выйти: $e');
      return;
    }
    await resetDigitalIdSession();
    try {
      await api.connect();
    } catch (_) {}
    if (navState != null) {
      await navState.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (_profile == null) {
      return const Center(child: SmallSpinner(size: 36));
    }

    final String fullName =
        '${_profile!.firstName}${_profile!.lastName != null ? ' ${_profile!.lastName}' : ''}';
    final String phone = _profile!.phone == 0
        ? l10n.profilePhoneRegenFailed
        : '+${_profile!.phone}';

    final size = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final hasPhoto = (_profile!.baseUrl ?? '').isNotEmpty;

    return ValueListenableBuilder<bool>(
      valueListenable: KometSettings.selfOnlineCheck,
      builder: (context, statusEnabled, _) {
        final collapsedH = topPad + (statusEnabled ? 268.0 : 242.0);
        final expandedH = hasPhoto
            ? math.max(collapsedH, math.min(size.width, size.height * 0.65))
            : collapsedH;
        final delta = expandedH - collapsedH;
        _syncHeaderDelta(delta);
        return Scaffold(
          backgroundColor: spectrumSurfaceColor(cs),
          body: NotificationListener<ScrollNotification>(
            onNotification: (n) => _handleScrollNotification(n, delta),
            child: CustomScrollView(
              key: ValueKey(delta),
              controller: _scrollController ??= ScrollController(
                initialScrollOffset: delta,
              ),
              physics: HeaderPullScrollPhysics(
                delta: delta,
                isArmed: () => _expandArmed,
                parent: const BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPersistentHeader(
                  delegate: MorphHeaderDelegate(
                    collapsedExtent: collapsedH,
                    expandedExtent: expandedH,
                    headerBuilder: (ctx, t) =>
                        _buildHeader(ctx, cs, fullName, phone, t),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: MediaPlaybackPill(
                    margin: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: AppShowExtraInfo.current,
                      builder: (context, showExtraInfo, _) {
                        return _buildSection(
                          context,
                          items: [
                            _SettingsItem(
                              icon: Symbols.badge,
                              label: 'Цифровой ID',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AppDigitalIdNative.current.value ||
                                            !webViewSupported
                                        ? const DigitalIdScreen()
                                        : const DigitalIdWebScreen(),
                                  ),
                                );
                              },
                            ),
                            _SettingsItem(
                              icon: Symbols.language,
                              label: 'Войти в Сферум',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WebAppScreen(
                                      title: 'Сферум',
                                      entryPoint: WebAppEntryPoint.settings,
                                      loader: () => webAppModule.fetchSferum(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (showExtraInfo)
                              _SettingsItem(
                                icon: Symbols.info,
                                label: 'Info',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const InfoScreen(),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: CustomizationSection(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildSection(
                      context,
                      items: [
                        _SettingsItem(
                          icon: Symbols.notifications_active,
                          label: 'Уведомления',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationsScreen(),
                              ),
                            );
                          },
                        ),
                        _SettingsItem(
                          icon: Symbols.cloud,
                          label: 'Облачное хранилище [BETA]',
                          onTap: () => _openCloudStorage(context),
                        ),
                        _SettingsItem(
                          icon: Symbols.vpn_lock,
                          label: 'Прокси',
                          onTap: () {
                            final cs = Theme.of(context).colorScheme;
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: cs.surfaceContainerHigh,
                              shape: kSheetShape,
                              builder: (_) {
                                return SafeArea(
                                  child: const ProxySettingsSheet(),
                                );
                              },
                            );
                          },
                        ),
                        _SettingsItem(
                          icon: Symbols.shield_lock,
                          label: AppLocalizations.of(context)!.profileMenuSpoof,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SpoofScreen(),
                              ),
                            );
                          },
                        ),
                        _SettingsItem(
                          icon: Symbols.lock,
                          label: 'Безопасность',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                settings: const RouteSettings(
                                  name: 'SecurityScreen',
                                ),
                                builder: (context) => const SecurityScreen(),
                              ),
                            );
                          },
                        ),
                        _SettingsItem(
                          icon: Symbols.devices,
                          label: 'Устройства',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DevicesScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 340),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: animation.value.clamp(0.0, 1.0),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        ),
                      );
                    },
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        clipBehavior: Clip.none,
                        children: <Widget>[...previousChildren, ?currentChild],
                      );
                    },
                    child: _debugMenuVisible
                        ? KeyedSubtree(
                            key: const ValueKey('developers_settings_row'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: _buildSection(
                                context,
                                items: [
                                  _SettingsItem(
                                    icon: Symbols.construction,
                                    label: 'Для разработчиков',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const DebugMenuScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('developers_settings_hidden'),
                          ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildSection(
                      context,
                      items: [
                        _SettingsItem(
                          icon: Symbols.system_update,
                          label: _isCheckingForUpdates
                              ? l10n.updateChecking
                              : l10n.updateCheck,
                          onTap: _isCheckingForUpdates
                              ? null
                              : _checkForUpdates,
                        ),
                        _SettingsItem(
                          leading: Image.asset(
                            'assets/komet.png',
                            width: 22,
                            height: 22,
                            color: cs.onSurfaceVariant,
                          ),
                          label: 'Komet',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const KometSettingsScreen(),
                              ),
                            );
                          },
                        ),
                        _SettingsItem(
                          icon: Symbols.logout,
                          label: 'Выйти из аккаунта',
                          tintColor: cs.error,
                          onTap: _confirmLogout,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_appVersionLabel != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _onVersionLabelTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: Text(
                              _appVersionLabel!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.75,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme cs,
    String name,
    String phone,
    double t,
  ) {
    final topPad = MediaQuery.paddingOf(context).top;
    final hasPhoto = (_profile?.baseUrl ?? '').isNotEmpty;
    final phoneMissing = (_profile?.phone ?? 0) == 0;
    final pt = hasPhoto ? t : 0.0;
    if (pt > 0) _headerEverExpanded = true;

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          const avatarSize = 88.0;
          final avatarRect = Rect.lerp(
            Rect.fromLTWH(
              (w - avatarSize) / 2,
              topPad + 68,
              avatarSize,
              avatarSize,
            ),
            Rect.fromLTWH(0, 0, w, h),
            pt,
          )!;
          final radius = lerpDouble(avatarSize / 2, 0, pt)!;
          final iconColor = Color.lerp(cs.onSurfaceVariant, Colors.white, pt)!;
          final nameColor = Color.lerp(cs.onSurface, Colors.white, pt)!;
          final subColor = Color.lerp(
            cs.onSurfaceVariant,
            Colors.white.withValues(alpha: 0.85),
            pt,
          )!;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fromRect(
                rect: avatarRect,
                child: GestureDetector(
                  onTap: () => AvatarHistoryScreen.open(
                    context,
                    contactId: _profile?.id ?? 0,
                    name: name,
                    currentAvatarUrl: _profile?.baseUrl,
                  ),
                  child: _buildMorphAvatar(cs, name, radius, pt),
                ),
              ),
              if (hasPhoto)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: topPad + 72,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: pt,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black38, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasPhoto)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 150,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: pt,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 8,
                right: 8,
                top: topPad + 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Symbols.qr_code_2,
                        color: iconColor,
                        size: 26,
                        weight: 400,
                      ),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: 1 - pt,
                        child: const ConnectionStatusLine(
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Symbols.edit,
                        color: iconColor,
                        size: 22,
                        weight: 400,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: lerpDouble(20, 14, pt)!,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _headerAligned(
                      pt,
                      Text(
                        name,
                        style: TextStyle(
                          color: nameColor,
                          fontSize: lerpDouble(20, 26, pt),
                          fontWeight: FontWeight.w700,
                          fontFamily: displayFontOf(context),
                        ),
                      ),
                    ),
                    _headerAligned(
                      pt,
                      _buildOnlineStatus(cs, textColor: subColor),
                    ),
                    const SizedBox(height: 6),
                    _headerAligned(
                      pt,
                      phoneMissing
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Text(
                                phone,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: subColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.3,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _isPhoneVisible = !_isPhoneVisible,
                                  ),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: _PhoneSpoiler(
                                      text: phone,
                                      isVisible: _isPhoneVisible,
                                      style: TextStyle(
                                        color: subColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AnimatedSlashIcon(
                                  icon: Symbols.visibility,
                                  slashedIcon: Symbols.visibility_off,
                                  slashed: !_isPhoneVisible,
                                  size: 14,
                                  color: Color.lerp(
                                    cs.mutedText,
                                    Colors.white70,
                                    pt,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerAligned(double t, Widget child) {
    return Align(
      alignment: Alignment.lerp(Alignment.center, Alignment.centerLeft, t)!,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: lerpDouble(12, 18, t)!),
        child: child,
      ),
    );
  }

  Widget _buildMorphAvatar(
    ColorScheme cs,
    String name,
    double radius,
    double pt,
  ) {
    final base = _profile?.baseUrl;
    final borderOpacity = (1 - pt * 2).clamp(0.0, 1.0);
    if (base == null || base.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.5),
            width: 2.5,
          ),
        ),
        child: KometAvatar(name: name, size: 88, fontSize: 32),
      );
    }
    final letterFallback = ColoredBox(
      color: cs.primaryContainer,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: base,
                fit: BoxFit.cover,
                memCacheWidth: 264,
                memCacheHeight: 264,
                errorWidget: (_, _, _) => letterFallback,
              ),
              if (_headerEverExpanded &&
                  _profile?.baseRawUrl != null &&
                  _profile!.baseRawUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: _profile!.baseRawUrl!,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 250),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
        if (borderOpacity > 0)
          IgnorePointer(
            child: Opacity(
              opacity: borderOpacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.5),
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatSelfSeen(int seconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final now = DateTime.now();
    final time = formatClock(dt);
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) return time;
    final datePart = dt.year == now.year
        ? '${dt.day} ${kRuMonthsShort[dt.month - 1]}'
        : '${dt.day} ${kRuMonthsShort[dt.month - 1]} ${dt.year}';
    return '$datePart, $time';
  }

  Widget _buildOnlineStatus(ColorScheme cs, {Color? textColor}) {
    return ValueListenableBuilder<bool>(
      valueListenable: KometSettings.selfOnlineCheck,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ValueListenableBuilder<bool>(
            valueListenable: SelfPresence.isOnline,
            builder: (context, online, _) => ValueListenableBuilder<int?>(
              valueListenable: SelfPresence.lastSeenSeconds,
              builder: (context, seen, _) {
                final label = online
                    ? 'онлайн'
                    : (seen != null
                          ? 'Был(-а) ${_formatSelfSeen(seen)}'
                          : 'офлайн');
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.check_circle,
                      fill: 1,
                      size: 15,
                      color: online ? kSuccessGreen : cs.mutedText,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor ?? cs.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required List<_SettingsItem> items,
  }) {
    return SettingsCard(
      children: List.generate(items.length, (index) {
        final item = items[index];
        return SettingsNavTile(
          icon: item.icon,
          leading: item.leading,
          label: item.label,
          tintColor: item.tintColor,
          onTap: item.onTap,
          isLast: index == items.length - 1,
        );
      }),
    );
  }
}

class _SettingsItem {
  final IconData? icon;
  final Widget? leading;
  final String label;
  final VoidCallback? onTap;
  final Color? tintColor;

  const _SettingsItem({
    this.icon,
    this.leading,
    required this.label,
    this.onTap,
    this.tintColor,
  });
}

class _PhoneSpoiler extends StatefulWidget {
  final String text;
  final bool isVisible;
  final TextStyle style;

  const _PhoneSpoiler({
    required this.text,
    required this.isVisible,
    required this.style,
  });

  @override
  State<_PhoneSpoiler> createState() => _PhoneSpoilerState();
}

class _PhoneSpoilerState extends State<_PhoneSpoiler>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (!widget.isVisible) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _PhoneSpoiler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible == oldWidget.isVisible) return;
    if (widget.isVisible) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      crossFadeState: widget.isVisible
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: SizedBox(
        child: CustomPaint(
          size: const Size(110, 16),
          painter: _SpoilerPainter(_controller, widget.style.color!),
        ),
      ),
      secondChild: Text(widget.text, style: widget.style),
    );
  }
}

class _SpoilerPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _SpoilerPainter(this.animation, this.color) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ),
      paint,
    );

    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 60; i++) {
      double dx = (i * 17.5 + animation.value * 20) % size.width;
      double dy = (i * 13.7 + animation.value * 15) % size.height;
      double opacity = (0.2 + 0.3 * (i % 5) / 5.0).clamp(0.0, 1.0);
      particlePaint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), 1.2, particlePaint);
    }
  }

  @override
  bool shouldRepaint(_SpoilerPainter oldDelegate) => true;
}

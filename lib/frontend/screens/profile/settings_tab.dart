import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../backend/modules/chats.dart';
import '../../../backend/modules/messages.dart';
import '../../../core/cache/self_presence.dart';
import '../../../core/config/komet_settings.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/info_action_sheet.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/sheet_helpers.dart';
import '../auth/login_screen.dart';
import '../auth/proxy_settings_sheet.dart';
import '../../../core/config/app_digital_id_mode.dart';
import '../../../core/utils/webview_support.dart';
import '../digital_id/digital_id_screen.dart';
import '../digital_id/digital_id_web_screen.dart';
import '../webapp/web_app_screen.dart';
import 'cloud_storage_screen.dart';
import 'customization_screen.dart';
import 'performance_screen.dart';
import 'debug_menu_screen.dart';
import 'devices_screen.dart';
import 'edit_profile_screen.dart';
import 'info_screen.dart';
import 'komet_settings_screen.dart';
import 'notifications_screen.dart';
import 'security_screen.dart';
import 'spoof_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  ProfileData? _profile;
  bool _isPhoneVisible = false;
  String? _appVersionLabel;
  bool _debugMenuVisible = false;
  int _versionSecretTapCount = 0;
  Timer? _versionSecretTapResetTimer;
  StreamSubscription? _profileUpdateSub;
  bool _hapticsEnabled = Haptics.enabled;

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
    super.dispose();
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

  Future<void> _setHaptics(bool value) async {
    await Haptics.setEnabled(value);
    // Let the user *feel* the confirmation the instant they switch it on.
    if (value) Haptics.success();
    if (mounted) setState(() => _hapticsEnabled = value);
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
      await api.disconnect();
    } catch (_) {}
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId != null) {
      await TokenStorage.deleteAccount(accountId);
      await AppDatabase.deleteAccount(accountId);
    }
    ContactCache.clear();
    TranscriptionCache.clear();
    ChatsModule.resetForAccountSwitch();
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

    if (_profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final String fullName =
        '${_profile!.firstName}${_profile!.lastName != null ? ' ${_profile!.lastName}' : ''}';
    final String phone = '+${_profile!.phone}';

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(context, cs, fullName, phone),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildSection(
                  context,
                  cs,
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
                              loader: () => webAppModule.fetchSferum(),
                            ),
                          ),
                        );
                      },
                    ),
                    _SettingsItem(
                      // Иконку кометы блять дайте!!!!!!!1
                      icon: Symbols.auto_awesome,
                      label: 'Komet',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const KometSettingsScreen(),
                          ),
                        );
                      },
                    ),
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
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildSection(
                  context,
                  cs,
                  items: [
                    _SettingsItem(
                      icon: Symbols.palette,
                      label: 'Кастомизация',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CustomizationScreen(),
                          ),
                        );
                      },
                    ),
                    _SettingsItem(
                      icon: Symbols.speed,
                      label: 'Производительность',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PerformanceScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildSection(
                  context,
                  cs,
                  items: [
                    _SettingsItem(
                      icon: Symbols.notifications_active,
                      label: 'Уведомления',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    _SettingsItem(
                      icon: Symbols.vibration,
                      label: 'Тактильная отдача',
                      toggleValue: _hapticsEnabled,
                      onToggle: _setHaptics,
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
                            return SafeArea(child: const ProxySettingsSheet());
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
                      child: FadeTransition(opacity: animation, child: child),
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
                            cs,
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
                  cs,
                  items: [
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
                            color: cs.onSurfaceVariant.withValues(alpha: 0.75),
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
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme cs,
    String name,
    String phone,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Symbols.qr_code_2,
                  color: cs.onSurfaceVariant,
                  size: 26,
                  weight: 400,
                ),
                onPressed: () {},
              ),
              const Expanded(
                child: ConnectionStatusLine(textAlign: TextAlign.center),
              ),
              IconButton(
                icon: Icon(
                  Symbols.edit,
                  color: cs.onSurfaceVariant,
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
          const SizedBox(height: 8),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.5),
                width: 2.5,
              ),
            ),
            child: KometAvatar(
              name: name,
              imageUrl: _profile?.baseUrl,
              size: 88,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
          _buildOnlineStatus(cs),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isPhoneVisible = !_isPhoneVisible),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: _PhoneSpoiler(
                    text: phone,
                    isVisible: _isPhoneVisible,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isPhoneVisible ? Symbols.visibility : Symbols.visibility_off,
                size: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildOnlineStatus(ColorScheme cs) {
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
                    : (seen != null ? 'Был(-а) ${_formatSelfSeen(seen)}' : 'офлайн');
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.check_circle,
                      fill: 1,
                      size: 15,
                      color: online
                          ? const Color(0xFF34C759)
                          : cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
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
    BuildContext context,
    ColorScheme cs, {
    required List<_SettingsItem> items,
  }) {
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          return _buildSettingsRow(context, cs, item, isLast: isLast);
        }),
      ),
    );
  }

  Widget _buildSettingsRow(
    BuildContext context,
    ColorScheme cs,
    _SettingsItem item, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: item.isToggle
                ? () => item.onToggle!(!(item.toggleValue ?? false))
                : (item.onTap ?? () {}),
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: item.tintColor ?? cs.onSurfaceVariant,
                    size: 22,
                    weight: 400,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: item.tintColor ?? cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item.isToggle)
                    Switch.adaptive(
                      value: item.toggleValue ?? false,
                      onChanged: item.onToggle,
                    )
                  else
                    Icon(
                      Symbols.chevron_right,
                      color: cs.outline,
                      size: 20,
                      weight: 400,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? tintColor;

  /// When [onToggle] is set the row renders a trailing switch instead of a
  /// chevron, and [toggleValue] reflects its current state.
  final bool? toggleValue;
  final ValueChanged<bool>? onToggle;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.tintColor,
    this.toggleValue,
    this.onToggle,
  });

  bool get isToggle => onToggle != null;
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

    // Draw the background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ),
      paint,
    );

    // Draw "noisy" particles
    final particlePaint = Paint()..style = PaintingStyle.fill;

    // Simple noise effect with dots using animation value for movement
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

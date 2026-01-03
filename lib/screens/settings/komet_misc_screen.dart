import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class KometMiscScreen extends StatefulWidget {
  final bool isModal;

  const KometMiscScreen({super.key, this.isModal = false});

  @override
  State<KometMiscScreen> createState() => _KometMiscScreenState();
}

class _KometMiscScreenState extends State<KometMiscScreen>
    with SingleTickerProviderStateMixin {
  bool? _isBatteryOptimizationDisabled;
  bool _isAutoUpdateEnabled = false;
  bool _showUpdateNotification = true;
  bool _enableWebVersionCheck = false;
  bool _showSpoofUpdateDialog = true;
  bool _showSferumButton = true;

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

    _checkBatteryOptimizationStatus();
    _loadUpdateSettings();
    _animationController.forward();
  }

  Future<void> _loadUpdateSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isAutoUpdateEnabled = prefs.getBool('auto_update_enabled') ?? false;
        _showUpdateNotification =
            prefs.getBool('show_update_notification') ?? true;
        _enableWebVersionCheck =
            prefs.getBool('enable_web_version_check') ?? false;
        _showSpoofUpdateDialog =
            prefs.getBool('show_spoof_update_dialog') ?? true;
        _showSferumButton = prefs.getBool('show_sferum_button') ?? true;
      });
    }
  }

  Future<void> _checkBatteryOptimizationStatus() async {
    if (_isDesktopOrIOS) {
      if (mounted) {
        setState(() {
          _isBatteryOptimizationDisabled = null;
        });
      }
      return;
    }

    try {
      bool? isDisabled =
          await DisableBatteryOptimization.isBatteryOptimizationDisabled;
      if (mounted) {
        setState(() {
          _isBatteryOptimizationDisabled = isDisabled;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBatteryOptimizationDisabled = null;
        });
      }
    }
  }

  Future<void> _requestDisableBatteryOptimization() async {
    if (_isDesktopOrIOS) {
      return;
    }

    try {
      await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
      Future.delayed(const Duration(milliseconds: 500), () {
        _checkBatteryOptimizationStatus();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при открытии настроек батареи: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _updateSettings(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get _isDesktopOrIOS =>
      Platform.isWindows ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isIOS;

  String _getBatteryStatusText() {
    if (_isDesktopOrIOS) {
      return "Недоступно на платформе";
    } else if (_isBatteryOptimizationDisabled == null) {
      return "Проверка статуса...";
    } else if (_isBatteryOptimizationDisabled == true) {
      return "Разрешено";
    } else {
      return "Не разрешено";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isModal && !_isDesktopOrIOS) {
      return _buildModalLayout(context);
    }

    if (widget.isModal && _isDesktopOrIOS) {
      return _buildModalLayout(context);
    }

    return _buildStandardLayout(context);
  }

  Widget _buildStandardLayout(BuildContext context) {
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ),
                    if (Navigator.canPop(context)) const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Komet Misc',
                            style: GoogleFonts.manrope(
                              textStyle: textTheme.headlineSmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Дополнительные настройки',
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
                    child: _buildContent(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalLayout(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width < 600
                    ? double.infinity
                    : 400,
                height: MediaQuery.of(context).size.height < 800
                    ? double.infinity
                    : null,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Назад',
                          ),
                          Expanded(
                            child: Text(
                              'Komet Misc',
                              style: GoogleFonts.manrope(
                                textStyle: textTheme.titleLarge,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            tooltip: 'Закрыть',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildContent(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // Battery Optimization Card
        _SettingCard(
          icon: Icons.battery_charging_full_rounded,
          title: 'Фоновая работа',
          description: _isDesktopOrIOS
              ? 'Недоступна на данной платформе'
              : 'Оптимизация расхода батареи',
          statusText: _getBatteryStatusText(),
          statusColor: _getStatusColor(),
          onTap: _isDesktopOrIOS ? null : _requestDisableBatteryOptimization,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
          ),
        ),
        const SizedBox(height: 20),
        // Update Settings Card
        _ToggleCard(
          icon: Icons.system_update_rounded,
          title: 'Автообновления',
          description: 'Автоматически проверять и устанавливать обновления',
          value: _isAutoUpdateEnabled,
          onChanged: (value) {
            setState(() {
              _isAutoUpdateEnabled = value;
            });
            _updateSettings('auto_update_enabled', value);
          },
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
          ),
        ),
        const SizedBox(height: 12),
        // Update Notifications Card
        _ToggleCard(
          icon: Icons.notifications_active_rounded,
          title: 'Уведомления об обновлениях',
          description: 'Показывать уведомления о доступных обновлениях',
          value: _showUpdateNotification,
          onChanged: _isAutoUpdateEnabled
              ? null
              : (value) {
                  setState(() {
                    _showUpdateNotification = value;
                  });
                  _updateSettings('show_update_notification', value);
                },
          isDisabled: _isAutoUpdateEnabled,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
          ),
        ),
        const SizedBox(height: 12),
        // Spoof Update Dialog Card
        _ToggleCard(
          icon: Icons.sync_problem_rounded,
          title: 'Диалог обновлений спуфа',
          description:
              'Показывать диалог проверки обновлений спуфа при запуске',
          value: _showSpoofUpdateDialog,
          onChanged: (value) {
            setState(() {
              _showSpoofUpdateDialog = value;
            });
            _updateSettings('show_spoof_update_dialog', value);
          },
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
          ),
        ),
        const SizedBox(height: 12),
        // Web Version Check Card
        _ToggleCard(
          icon: Icons.web_rounded,
          title: 'Проверка веб-версии',
          description: 'Проверять обновления веб-версии приложения',
          value: _enableWebVersionCheck,
          onChanged: (value) {
            setState(() {
              _enableWebVersionCheck = value;
            });
            _updateSettings('enable_web_version_check', value);
          },
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
          ),
        ),
        const SizedBox(height: 12),
        // Sferum Button Card
        _ToggleCard(
          icon: Icons.remove_red_eye,
          title: 'Показывать кнопку Сферум',
          description:
              'Показывать кнопку Сферум в главном меню (требуется перезапуск)',
          value: _showSferumButton,
          onChanged: (value) {
            setState(() {
              _showSferumButton = value;
            });
            _updateSettings('show_sferum_button', value);
          },
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
          ),
        ),
        const SizedBox(height: 28),
        // Info Box
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outline.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colors.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Для применения некоторых изменений может потребоваться перезапуск приложения',
                  style: GoogleFonts.manrope(
                    textStyle: Theme.of(context).textTheme.bodyMedium,
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    if (_isDesktopOrIOS) {
      return Colors.grey;
    } else if (_isBatteryOptimizationDisabled == null) {
      return Colors.grey;
    } else if (_isBatteryOptimizationDisabled == true) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onTap;
  final Gradient gradient;

  const _SettingCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.statusText,
    required this.statusColor,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDisabled = onTap == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: colors.primary, size: 24),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.labelSmall,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.manrope(
                  textStyle: textTheme.titleMedium,
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
              if (!isDisabled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Изменить',
                      style: GoogleFonts.manrope(
                        textStyle: textTheme.labelMedium,
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: colors.primary, size: 18),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isDisabled;
  final Gradient gradient;

  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.isDisabled = false,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled
              ? null
              : (onChanged != null ? () => onChanged!(!value) : null),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: value
                        ? colors.primaryContainer.withOpacity(0.7)
                        : colors.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: value ? colors.primary : colors.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          textStyle: textTheme.titleMedium,
                          fontWeight: FontWeight.bold,
                          color: isDisabled ? colors.onSurfaceVariant : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.manrope(
                          textStyle: textTheme.bodySmall,
                          color: colors.onSurfaceVariant.withOpacity(
                            isDisabled ? 0.5 : 1,
                          ),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: value,
                  onChanged: isDisabled ? null : onChanged,
                  activeColor: colors.primary,
                  inactiveThumbColor: colors.outlineVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

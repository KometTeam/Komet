import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gwid/utils/proxy_service.dart';
import 'package:gwid/screens/settings/proxy_settings_screen.dart';
import 'package:gwid/screens/settings/session_spoofing_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSettingsScreen extends StatefulWidget {
  const AuthSettingsScreen({super.key});

  @override
  State<AuthSettingsScreen> createState() => _AuthSettingsScreenState();
}

class _AuthSettingsScreenState extends State<AuthSettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _hasCustomAnonymity = false;
  bool _hasProxyConfigured = false;
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

    _checkSettings();
    _animationController.forward();
  }

  Future<void> _checkSettings() async {
    await Future.wait([_checkAnonymitySettings(), _checkProxySettings()]);
  }

  Future<void> _checkAnonymitySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final anonymityEnabled = prefs.getBool('anonymity_enabled') ?? false;
    if (mounted) {
      setState(() => _hasCustomAnonymity = anonymityEnabled);
    }
  }

  Future<void> _checkProxySettings() async {
    final settings = await ProxyService.instance.loadProxySettings();
    if (mounted) {
      setState(() {
        _hasProxyConfigured = settings.isEnabled && settings.host.isNotEmpty;
      });
    }
  }

  Future<void> _navigateToAnonymitySettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SessionSpoofingScreen()),
    );
    _checkAnonymitySettings();
  }

  Future<void> _navigateToProxySettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProxySettingsScreen()),
    );
    _checkProxySettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Настройки',
                            style: GoogleFonts.manrope(
                              textStyle: textTheme.headlineSmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Безопасность и конфиденциальность',
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
                    child: ListView(
                      padding: const EdgeInsets.all(24.0),
                      children: [
                        _SettingsCard(
                          icon: _hasCustomAnonymity
                              ? Icons.verified_user
                              : Icons.visibility_outlined,
                          title: 'Настройки анонимности',
                          description: _hasCustomAnonymity
                              ? 'Активны кастомные настройки анонимности'
                              : 'Настройте анонимность для скрытия данных устройства',
                          isConfigured: _hasCustomAnonymity,
                          onTap: _navigateToAnonymitySettings,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _hasCustomAnonymity
                                ? [
                                    Color.lerp(
                                      colors.primaryContainer,
                                      colors.primary,
                                      0.2,
                                    )!,
                                    colors.primaryContainer,
                                  ]
                                : [
                                    colors.surfaceContainerHighest,
                                    colors.surfaceContainer,
                                  ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        _SettingsCard(
                          icon: _hasProxyConfigured
                              ? Icons.vpn_key
                              : Icons.vpn_key_outlined,
                          title: 'Настройки прокси',
                          description: _hasProxyConfigured
                              ? 'Прокси-сервер настроен и активен'
                              : 'Настройте прокси-сервер для безопасного подключения',
                          isConfigured: _hasProxyConfigured,
                          onTap: _navigateToProxySettings,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _hasProxyConfigured
                                ? [
                                    Color.lerp(
                                      colors.tertiaryContainer,
                                      colors.tertiary,
                                      0.2,
                                    )!,
                                    colors.tertiaryContainer,
                                  ]
                                : [
                                    colors.surfaceContainerHighest,
                                    colors.surfaceContainer,
                                  ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: colors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Иногда, забавные вещи могут быть наказуемы',
                                  style: GoogleFonts.manrope(
                                    textStyle: textTheme.bodyMedium,
                                    color: colors.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isConfigured;
  final VoidCallback onTap;
  final Gradient gradient;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isConfigured,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              color: isConfigured
                  ? colors.primary.withValues(alpha: 0.3)
                  : colors.outline.withValues(alpha: 0.2),
              width: isConfigured ? 2 : 1,
            ),
            boxShadow: isConfigured
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isConfigured
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isConfigured
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  if (isConfigured)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: colors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Активно',
                            style: GoogleFonts.manrope(
                              textStyle: textTheme.labelSmall,
                              color: colors.primary,
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
                  textStyle: textTheme.titleLarge,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    isConfigured ? 'Изменить настройки' : 'Настроить',
                    style: GoogleFonts.manrope(
                      textStyle: textTheme.labelLarge,
                      color: isConfigured
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    color: isConfigured
                        ? colors.primary
                        : colors.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

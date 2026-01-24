import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gwid/screens/settings/network_screen.dart';
import 'package:gwid/screens/settings/proxy_settings_screen.dart';
import 'package:gwid/screens/settings/socket_log_screen.dart';

class NetworkSettingsScreen extends StatefulWidget {
  final bool isModal;

  const NetworkSettingsScreen({super.key, this.isModal = false});

  @override
  State<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends State<NetworkSettingsScreen>
    with SingleTickerProviderStateMixin {
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

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isModal) {
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
                            'Сеть',
                            style: GoogleFonts.manrope(
                              textStyle: textTheme.headlineSmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Подключение, прокси и логирование',
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
                              'Сеть',
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
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        _NetworkCard(
          icon: Icons.bar_chart_outlined,
          title: 'Мониторинг сети',
          description:
              'Просмотр статистики использования и скорости соединения',
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const NetworkScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _NetworkCard(
          icon: Icons.vpn_key_outlined,
          title: 'Настройки прокси',
          description: 'HTTP/HTTPS прокси и SOCKS для безопасного подключения',
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const ProxySettingsScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _NetworkCard(
          icon: Icons.list_alt_outlined,
          title: 'Журнал Socket',
          description: 'Отладочная информация и логирование соединений',
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const SocketLogScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Все изменения в настройках сети применяются немедленно',
                  style: GoogleFonts.manrope(
                    textStyle: Theme.of(context).textTheme.bodyMedium,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
}

class _NetworkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _NetworkCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outline.withValues(alpha: 0.2),
              width: 1,
            ),
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
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: colors.primary, size: 24),
                  ),
                  const Spacer(),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Открыть',
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
          ),
        ),
      ),
    );
  }
}

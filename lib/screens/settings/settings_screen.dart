import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gwid/consts.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/screens/manage_account_screen.dart';
import 'package:gwid/screens/settings/appearance_settings_screen.dart';
import 'package:gwid/screens/settings/notification_settings_screen.dart';
import 'package:gwid/screens/settings/privacy_security_screen.dart';
import 'package:gwid/screens/settings/storage_screen.dart';
import 'package:gwid/screens/settings/network_settings_screen.dart';
import 'package:gwid/screens/settings/bypass_screen.dart';
import 'package:gwid/screens/settings/about_screen.dart';
import 'package:gwid/screens/debug_screen.dart';
import 'package:gwid/screens/settings/komet_misc_screen.dart';
import 'package:gwid/screens/settings/optimization_screen.dart';
// import 'package:gwid/screens/settings/plugins_screen.dart';
import 'package:gwid/screens/settings/plugin_section_screen.dart';
import 'package:gwid/plugins/plugin_service.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  final bool showBackToChats;
  final VoidCallback? onBackToChats;
  final Profile? myProfile;
  final bool isModal;

  const SettingsScreen({
    super.key,
    this.showBackToChats = false,
    this.onBackToChats,
    this.myProfile,
    this.isModal = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  Profile? _myProfile;
  bool _isProfileLoading = true;
  int _versionTapCount = 0;
  DateTime? _lastTapTime;

  String _currentModalScreen = 'main';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ScrollController _scrollController = ScrollController();
  double _overscrollOffset = 0.0;

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

    if (widget.myProfile != null) {
      _myProfile = widget.myProfile;
      _isProfileLoading = false;
    } else {
      _loadMyProfile();
    }

    _animationController.forward();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      if (pixels < 0) {
        setState(() {
          _overscrollOffset = -pixels;
        });
      } else if (_overscrollOffset != 0) {
        setState(() {
          _overscrollOffset = 0;
        });
      }
    } else if (notification is ScrollEndNotification) {
      if (_overscrollOffset != 0) {
        setState(() {
          _overscrollOffset = 0;
        });
      }
    }
    return false;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    if (!mounted) return;
    setState(() => _isProfileLoading = true);

    final cachedProfileData = ApiService.instance.lastChatsPayload?['profile'];
    if (cachedProfileData != null && mounted) {
      setState(() {
        _myProfile = Profile.fromJson(cachedProfileData);
        _isProfileLoading = false;
      });
      return;
    }

    try {
      final result = await ApiService.instance.getChatsAndContacts(force: true);
      if (mounted) {
        final profileJson = result['profile'];
        if (profileJson != null) {
          setState(() {
            _myProfile = Profile.fromJson(profileJson);
            _isProfileLoading = false;
          });
        } else {
          setState(() => _isProfileLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProfileLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Ошибка загрузки профиля: $e")));
      }
    }
  }

  void _handleVersionTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 2) {
      _versionTapCount = 0;
    }
    _lastTapTime = now;
    _versionTapCount++;

    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const DebugScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDesktop = themeProvider.useDesktopLayout;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.isModal || isDesktop) {
      return _buildModalSettings(context);
    }

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
                            'Настройки',
                            style: GoogleFonts.manrope(
                              textStyle: textTheme.headlineSmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Управление аккаунтом и приложением',
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
                    child: _buildSettingsContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalSettings(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    final isSmallScreen = screenWidth < 600 || screenHeight < 800;

    return Scaffold(
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
              child: isSmallScreen
                  ? Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(color: colors.surface),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: colors.surface),
                            child: Row(
                              children: [
                                if (_currentModalScreen != 'main')
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentModalScreen = 'main';
                                      });
                                    },
                                    icon: const Icon(Icons.arrow_back),
                                    tooltip: 'Назад',
                                  ),
                                Expanded(
                                  child: Text(
                                    _getModalTitle(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
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

                          Expanded(child: _buildModalContent()),
                        ],
                      ),
                    )
                  : Container(
                      width: 400,
                      height: 900,
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
                                if (_currentModalScreen != 'main')
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentModalScreen = 'main';
                                      });
                                    },
                                    icon: const Icon(Icons.arrow_back),
                                    tooltip: 'Назад',
                                  ),
                                Expanded(
                                  child: Text(
                                    _getModalTitle(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
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

                          Expanded(child: _buildModalContent()),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getModalTitle() {
    switch (_currentModalScreen) {
      case 'notifications':
        return 'Уведомления';
      case 'appearance':
        return 'Внешний вид';
      case 'privacy':
        return 'Приватность и безопасность';
      case 'storage':
        return 'Хранилище';
      case 'network':
        return 'Сеть';
      case 'bypass':
        return 'Bypass';
      case 'about':
        return 'О приложении';
      case 'komet':
        return 'Komet Misc';
      case 'optimization':
        return 'Оптимизация';
      default:
        return 'Настройки';
    }
  }

  Widget _buildModalContent() {
    switch (_currentModalScreen) {
      case 'notifications':
        return const NotificationSettingsScreen(isModal: true);
      case 'appearance':
        return const AppearanceSettingsScreen(isModal: true);
      case 'privacy':
        return const PrivacySecurityScreen(isModal: true);
      case 'storage':
        return const StorageScreen(isModal: true);
      case 'network':
        return const NetworkSettingsScreen(isModal: true);
      case 'bypass':
        return const BypassScreen(isModal: true);
      case 'about':
        return const AboutScreen(isModal: true);
      case 'komet':
        return const KometMiscScreen(isModal: true);
      case 'optimization':
        return const OptimizationScreen(isModal: true);
      default:
        return _buildSettingsContent();
    }
  }

  Widget _buildSettingsContent() {
    final List<_SettingsItem> items = [
      _SettingsItem(type: _SettingsItemType.profile),
      _SettingsItem(type: _SettingsItemType.spacer, height: 8),
      _SettingsItem(
        type: _SettingsItemType.category,
        icon: Icons.rocket_launch_outlined,
        title: "Komet Misc",
        subtitle: "Дополнительные настройки",
        screen: KometMiscScreen(isModal: widget.isModal),
      ),
      _SettingsItem(
        type: _SettingsItemType.category,
        icon: Icons.palette_outlined,
        title: "Внешний вид",
        subtitle: "Темы, анимации, производительность",
        screen: AppearanceSettingsScreen(isModal: widget.isModal),
      ),
      _SettingsItem(
        type: _SettingsItemType.category,
        icon: Icons.notifications_outlined,
        title: "Уведомления",
        subtitle: "Звуки, чаты, звонки",
        screen: NotificationSettingsScreen(isModal: widget.isModal),
      ),
      _SettingsItem(
        type: _SettingsItemType.category,
        icon: Icons.security_outlined,
        title: "Приватность и безопасность",
        subtitle: "Статус, сессии, пароль, блокировки",
        screen: PrivacySecurityScreen(isModal: widget.isModal),
      ),
      _SettingsItem(
        type: _SettingsItemType.category,
        icon: Icons.storage_outlined,
        title: "Данные и хранилище",
        subtitle: "Использование хранилища, очистка кэша",
        screen: StorageScreen(isModal: widget.isModal),
      ),
      _SettingsItem(
        type: _SettingsItemType.category,
        icon: Icons.speed,
        title: "Оптимизация",
        subtitle: "Настройки оптимизации",
        screen: OptimizationScreen(isModal: widget.isModal),
      ),
      _SettingsItem(
        type: _SettingsItemType.category,
        icon: Icons.wifi_outlined,
        title: "Сеть",
        subtitle: "Прокси, мониторинг, логи",
        screen: NetworkSettingsScreen(isModal: widget.isModal),
      ),
      _SettingsItem(
        type: _SettingsItemType.category,
        icon: Icons.psychology_outlined,
        title: "Специальные возможности и фишки",
        subtitle: "Обход ограничений, эксперименты",
        screen: const BypassScreen(),
      ),
      _SettingsItem(
        type: _SettingsItemType.category,
        icon: Icons.info_outline,
        title: "О приложении",
        subtitle: "Команда, соглашение",
        screen: const AboutScreen(),
      ),
      // _SettingsItem(
      //   type: _SettingsItemType.category,
      //   icon: Icons.extension,
      //   title: "Plugins(WIP)",
      //   subtitle: "Плагины(WIP)",
      //   screen: const PluginsScreen(),
      // ),
    ];

    final pluginSections = PluginService().getAllPluginSections();
    for (final section in pluginSections) {
      items.add(
        _SettingsItem(
          type: _SettingsItemType.category,
          icon: Icons.extension,
          title: section.title,
          subtitle: "Плагины(WIP)",
          screen: PluginSectionScreen(section: section),
        ),
      );
    }

    items.addAll([
      _SettingsItem(type: _SettingsItemType.spacer, height: 16),
      _SettingsItem(type: _SettingsItemType.version),
    ]);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(24.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          switch (item.type) {
            case _SettingsItemType.profile:
              return _buildProfileSection();
            case _SettingsItemType.spacer:
              return SizedBox(height: item.height);
            case _SettingsItemType.category:
              return _buildSettingsCategory(
                context,
                icon: item.icon!,
                title: item.title!,
                subtitle: item.subtitle!,
                screen: item.screen!,
              );
            case _SettingsItemType.version:
              return GestureDetector(
                onTap: _handleVersionTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    appVersion,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
          }
        },
      ),
    );
  }

  Widget _buildProfileSection() {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width - 48; 

    final maxOverscroll = 200.0;
    final expansionProgress = (_overscrollOffset / maxOverscroll).clamp(0.0, 1.0);
    
    const baseAvatarSize = 112.0;
    final expandedSize = screenWidth;
    final currentSize = baseAvatarSize + (expandedSize - baseAvatarSize) * expansionProgress;
    
    final baseBorderRadius = baseAvatarSize / 2;
    final expandedBorderRadius = 24.0;
    final currentBorderRadius = baseBorderRadius - (baseBorderRadius - expandedBorderRadius) * expansionProgress;

    if (_isProfileLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              width: currentSize,
              height: currentSize,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(currentBorderRadius),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Загрузка профиля...',
              style: GoogleFonts.manrope(
                textStyle: textTheme.titleLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Пожалуйста, подождите',
              style: GoogleFonts.manrope(
                textStyle: textTheme.bodyMedium,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_myProfile == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loadMyProfile,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: currentSize,
                  height: currentSize,
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(currentBorderRadius),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: colors.onErrorContainer,
                    size: 48 + (24 * expansionProgress),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Не удалось загрузить профиль',
                  style: GoogleFonts.manrope(
                    textStyle: textTheme.titleLarge,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Нажмите для повтора',
                  style: GoogleFonts.manrope(
                    textStyle: textTheme.bodyMedium,
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              width: currentSize,
              height: currentSize,
              decoration: BoxDecoration(
                color: _myProfile!.photoBaseUrl == null 
                    ? colors.primaryContainer 
                    : null,
                borderRadius: BorderRadius.circular(currentBorderRadius),
                boxShadow: expansionProgress > 0
                    ? [
                        BoxShadow(
                          color: colors.shadow.withOpacity(0.2 * expansionProgress),
                          blurRadius: 20 * expansionProgress,
                          offset: Offset(0, 8 * expansionProgress),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: _myProfile!.photoBaseUrl != null
                  ? Image.network(
                      _myProfile!.photoBaseUrl!,
                      fit: BoxFit.cover,
                      width: currentSize,
                      height: currentSize,
                    )
                  : Center(
                      child: Text(
                        _myProfile!.displayName.isNotEmpty
                            ? _myProfile!.displayName[0].toUpperCase()
                            : '',
                        style: GoogleFonts.manrope(
                          fontSize: 44 + (40 * expansionProgress),
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              _myProfile!.displayName,
              style: GoogleFonts.manrope(
                textStyle: textTheme.headlineSmall,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              _myProfile!.formattedPhone,
              style: GoogleFonts.manrope(
                textStyle: textTheme.bodyLarge,
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${_myProfile!.id}',
              style: GoogleFonts.manrope(
                textStyle: textTheme.bodyMedium,
                color: colors.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                final updatedProfile = await Navigator.of(context).push<Profile?>(
                  MaterialPageRoute(
                    builder: (context) => ManageAccountScreen(myProfile: _myProfile!),
                  ),
                );
                if (updatedProfile != null && mounted) {
                  setState(() {
                    _myProfile = updatedProfile;
                  });
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(colors.primaryContainer, colors.primary, 0.1)!,
                      colors.primaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Редактировать профиль',
                      style: GoogleFonts.manrope(
                        textStyle: textTheme.labelLarge,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
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

  Widget _buildSettingsCategory(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.isModal) {
              String screenKey = '';
              if (screen is NotificationSettingsScreen) {
                screenKey = 'notifications';
              } else if (screen is AppearanceSettingsScreen)
                screenKey = 'appearance';
              else if (screen is PrivacySecurityScreen)
                screenKey = 'privacy';
              else if (screen is StorageScreen)
                screenKey = 'storage';
              else if (screen is NetworkSettingsScreen)
                screenKey = 'network';
              else if (screen is BypassScreen)
                screenKey = 'bypass';
              else if (screen is AboutScreen)
                screenKey = 'about';
              else if (screen is KometMiscScreen)
                screenKey = 'komet';
              else if (screen is OptimizationScreen)
                screenKey = 'optimization';

              setState(() {
                _currentModalScreen = screenKey;
              });
            } else {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => screen));
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surfaceContainerHighest,
                  colors.surfaceContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: colors.primary,
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
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          textStyle: textTheme.bodySmall,
                          color: colors.onSurfaceVariant,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SettingsItemType { profile, spacer, category, version }

class _SettingsItem {
  final _SettingsItemType type;
  final double? height;
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final Widget? screen;

  _SettingsItem({
    required this.type,
    this.height,
    this.icon,
    this.title,
    this.subtitle,
    this.screen,
  });
}

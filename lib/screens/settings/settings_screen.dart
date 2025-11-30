import 'package:flutter/material.dart';
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

class _SettingsScreenState extends State<SettingsScreen> {
  Profile? _myProfile;
  bool _isProfileLoading = true;
  int _versionTapCount = 0;
  DateTime? _lastTapTime;
  bool _isReconnecting = false;


  String _currentModalScreen = 'main';

  @override
  void initState() {
    super.initState();
    if (widget.myProfile != null) {

      _myProfile = widget.myProfile;
      _isProfileLoading = false;
    } else {

      _loadMyProfile();
    }
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
      return; // Нашли в кеше, выходим
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

  Future<void> _handleReconnection() async {
    if (_isReconnecting) return;

    setState(() {
      _isReconnecting = true;
    });

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Переподключение...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      await ApiService.instance.performFullReconnection();
      await _loadMyProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Переподключение выполнено успешно'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка переподключения: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReconnecting = false;
        });
      }
    }
  }

  Widget _buildReconnectionButton() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          Icons.sync,
          color: _isReconnecting
              ? Colors.grey
              : Theme.of(context).colorScheme.primary,
        ),
        title: const Text(
          "Переподключиться к серверу",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text("Сбросить соединение и переподключиться"),
        trailing: _isReconnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
        onTap: _isReconnecting ? null : _handleReconnection,
      ),
    );
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

    if (widget.isModal || isDesktop) {
      return _buildModalSettings(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Настройки"),
        leading: widget.showBackToChats
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackToChats,
              )
            : null,
      ),
      body: SafeArea(
        child: _buildSettingsContent(),
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
      backgroundColor: Colors.transparent,
      body: Stack(
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
      default:
        return _buildSettingsContent();
    }
  }

  Widget _buildSettingsContent() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [

        _buildProfileSection(),
        const SizedBox(height: 16),

        _buildReconnectionButton(),
        const SizedBox(height: 16),

        _buildSettingsCategory(
          context,
          icon: Icons.rocket_launch_outlined,
          title: "Komet Misc",
          subtitle: "Дополнительные настройки",
          screen: KometMiscScreen(isModal: widget.isModal),
        ),

        _buildSettingsCategory(
          context,
          icon: Icons.palette_outlined,
          title: "Внешний вид",
          subtitle: "Темы, анимации, производительность",
          screen: AppearanceSettingsScreen(isModal: widget.isModal),
        ),
        _buildSettingsCategory(
          context,
          icon: Icons.notifications_outlined,
          title: "Уведомления",
          subtitle: "Звуки, чаты, звонки",
          screen: NotificationSettingsScreen(isModal: widget.isModal),
        ),
        _buildSettingsCategory(
          context,
          icon: Icons.security_outlined,
          title: "Приватность и безопасность",
          subtitle: "Статус, сессии, пароль, блокировки",
          screen: PrivacySecurityScreen(isModal: widget.isModal),
        ),
        _buildSettingsCategory(
          context,
          icon: Icons.storage_outlined,
          title: "Данные и хранилище",
          subtitle: "Использование хранилища, очистка кэша",
          screen: StorageScreen(isModal: widget.isModal),
        ),
        _buildSettingsCategory(
          context,
          icon: Icons.wifi_outlined,
          title: "Сеть",
          subtitle: "Прокси, мониторинг, логи",
          screen: NetworkSettingsScreen(isModal: widget.isModal),
        ),
        _buildSettingsCategory(
          context,
          icon: Icons.psychology_outlined,
          title: "Специальные возможности",
          subtitle: "Обход ограничений",
          screen: const BypassScreen(),
        ),
        _buildSettingsCategory(
          context,
          icon: Icons.info_outline,
          title: "О приложении",
          subtitle: "Команда, соглашение",
          screen: const AboutScreen(),
        ),


        GestureDetector(
          onTap: _handleVersionTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Text(
              version,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    if (_isProfileLoading) {
      return const Card(
        child: ListTile(
          leading: CircleAvatar(radius: 28),
          title: Text("Загрузка профиля..."),
          subtitle: Text("Пожалуйста, подождите"),
        ),
      );
    }

    if (_myProfile == null) {
      return Card(
        child: ListTile(
          leading: const CircleAvatar(
            radius: 28,
            child: Icon(Icons.error_outline),
          ),
          title: const Text("Не удалось загрузить профиль"),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMyProfile,
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: _myProfile!.photoBaseUrl != null
              ? NetworkImage(_myProfile!.photoBaseUrl!)
              : null,
          child: _myProfile!.photoBaseUrl == null
              ? Text(
                  _myProfile!.displayName.isNotEmpty
                      ? _myProfile!.displayName[0].toUpperCase()
                      : '',
                  style: const TextStyle(fontSize: 24),
                )
              : null,
        ),
        title: Text(
          _myProfile!.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_myProfile!.formattedPhone),
            const SizedBox(height: 2),
            Text(
              'ID: ${_myProfile!.id}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ManageAccountScreen(myProfile: _myProfile!),
            ),
          );
        },
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          if (widget.isModal) {

            String screenKey = '';
            if (screen is NotificationSettingsScreen)
              screenKey = 'notifications';
            else if (screen is AppearanceSettingsScreen)
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

            setState(() {
              _currentModalScreen = screenKey;
            });
          } else {

            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => screen));
          }
        },
      ),
    );
  }
}

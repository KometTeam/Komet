import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:m3e_collection/m3e_collection.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend/api.dart';
import 'core/config/app_fonts.dart';
import 'backend/modules/account.dart';
import 'backend/modules/contacts.dart';
import 'backend/modules/messages.dart';
import 'core/push/push_service.dart';
import 'core/storage/app_database.dart';
import 'core/transport/vpn_bypass.dart';
import 'core/storage/token_storage.dart';
import 'core/utils/haptics.dart';
import 'core/protocol/packet.dart';
import 'frontend/debug/fps_overlay_layer.dart';
import 'frontend/screens/auth/login_screen.dart';
import 'frontend/screens/chats/chat_list_screen.dart';
import 'frontend/widgets/custom_notification.dart';

final api = Api();
final accountModule = AccountModule(api);
final messagesModule = MessagesModule(api);

Future<Locale> _loadInitialLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString('app_locale');
  if (code != null && (code == 'en' || code == 'ru')) {
    return Locale(code);
  }
  final platform = WidgetsBinding.instance.platformDispatcher.locale;
  if (platform.languageCode == 'en' || platform.languageCode == 'ru') {
    return Locale(platform.languageCode);
  }
  return const Locale('ru');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init();
  final activeAccountId = await TokenStorage.getActiveAccountId();
  if (activeAccountId != null) {
    await ContactsModule.primeCacheFromDb(activeAccountId);
  }
  await api.connect();

  final packageInfo = await PackageInfo.fromPlatform();
  if (packageInfo.packageName == 'ru.oneme.app') {
    await PushService.instance.init(api: api, account: accountModule);
  }

  final initialLocale = await _loadInitialLocale();

  await Haptics.load();

  final prefs = await SharedPreferences.getInstance();
  final initialFpsOverlay = prefs.getBool('dev_fps_overlay') ?? false;
  final initialVpnBypass = prefs.getBool(VpnBypassService.prefKey) ?? false;
  final initialFontId =
      prefs.getString(AppFonts.prefKey) ?? AppFonts.fallback.id;
  final initialFontScale = AppFonts.clampScale(
    prefs.getDouble(AppFonts.scalePrefKey) ?? AppFonts.defaultScale,
  );
  runApp(
    KometApp(
      initialLocale: initialLocale,
      initialFpsOverlay: initialFpsOverlay,
      initialVpnBypass: initialVpnBypass,
      initialFontId: initialFontId,
      initialFontScale: initialFontScale,
    ),
  );
}

class KometApp extends StatefulWidget {
  const KometApp({
    super.key,
    required this.initialLocale,
    this.initialFpsOverlay = false,
    this.initialVpnBypass = false,
    required this.initialFontId,
    required this.initialFontScale,
  });

  final Locale initialLocale;
  final bool initialFpsOverlay;
  final bool initialVpnBypass;
  final String initialFontId;
  final double initialFontScale;
  static final navigatorKey = GlobalKey<NavigatorState>();

  static KometAppState? stateOf(BuildContext context) {
    return context.findAncestorStateOfType<KometAppState>();
  }

  @override
  State<KometApp> createState() => KometAppState();
}

class KometAppState extends State<KometApp> {
  static const _fallbackSeed = Color(0xFFC1C4FF);

  late Locale _locale;
  late String _fontId;
  bool _isLoggingOut = false;
  StreamSubscription<SessionExpiredException>? _sessionExpiredSub;
  StreamSubscription<LoginStatus>? _loginStatusSub;
  StreamSubscription<VpnBypassResult>? _vpnBypassSub;
  String? _lastVpnNotice;
  DateTime _lastVpnNoticeAt = DateTime.fromMillisecondsSinceEpoch(0);
  late final ValueNotifier<bool> fpsOverlayEnabled = ValueNotifier(
    widget.initialFpsOverlay,
  );
  late final ValueNotifier<bool> vpnBypassEnabled = ValueNotifier(
    widget.initialVpnBypass,
  );
  late final ValueNotifier<double> fontScale = ValueNotifier(
    widget.initialFontScale,
  );
  final _profileUpdateController = StreamController<void>.broadcast();
  Stream<void> get profileUpdateStream => _profileUpdateController.stream;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    _fontId = widget.initialFontId;

    api.setReconnectCallback(() async {
      try {
        final accountId = await TokenStorage.getActiveAccountId();
        if (accountId != null) {
          final token = await TokenStorage.readToken(accountId);
          if (token != null) {
            await accountModule.login(accountId: accountId, token: token);
          }
        }
      } catch (_) {}
    });

    _loginStatusSub = accountModule.loginStatusStream.listen((status) {
      if (status == LoginStatus.success) {
        PushService.instance.onLoginSuccess();
      }
    });

    _sessionExpiredSub = api.sessionExpiredStream.listen((SessionExpiredException e) async {
      if (_isLoggingOut) return;
      _isLoggingOut = true;

      await PushService.instance.unregister();

      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId != null) {
        await accountModule.removeAccount(accountId);
      }

      final navState = KometApp.navigatorKey.currentState;
      if (navState != null) {
        final overlay = navState.overlay;
        if (overlay != null) {
          showCustomNotificationOnOverlay(overlay, e.message);
        }

        await navState.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      _isLoggingOut = false;
    });

    _vpnBypassSub = VpnBypassService.instance.events.listen((r) {
      final msg = r.bound
          ? 'Соединение через VPN не работает — '
                'используется ${r.boundInterface ?? r.transport ?? 'прямое подключение'}'
          : 'Соединение через VPN не работает, обойти не удалось'
                '${r.reason != null ? ' (${r.reason})' : ''}';

      final now = DateTime.now();
      if (msg == _lastVpnNotice &&
          now.difference(_lastVpnNoticeAt).inSeconds < 10) {
        return;
      }
      _lastVpnNotice = msg;
      _lastVpnNoticeAt = now;

      final overlay = KometApp.navigatorKey.currentState?.overlay;
      if (overlay != null) {
        showCustomNotificationOnOverlay(overlay, msg);
      }
    });
  }

  @override
  void dispose() {
    _sessionExpiredSub?.cancel();
    _loginStatusSub?.cancel();
    _vpnBypassSub?.cancel();
    _profileUpdateController.close();
    fpsOverlayEnabled.dispose();
    vpnBypassEnabled.dispose();
    fontScale.dispose();
    super.dispose();
  }

  Future<void> setFpsOverlayEnabled(bool value) async {
    if (fpsOverlayEnabled.value == value) return;
    fpsOverlayEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_fps_overlay', value);
  }

  Future<void> setVpnBypassEnabled(bool value) async {
    if (vpnBypassEnabled.value == value) return;
    vpnBypassEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(VpnBypassService.prefKey, value);
  }

  Future<void> applyLocale(Locale locale) async {
    if (!AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == locale.languageCode,
    )) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale.languageCode);
    if (mounted) {
      setState(() => _locale = locale);
    }
  }

  String get fontId => _fontId;

  Future<void> applyAppFont(String fontId) async {
    if (_fontId == fontId) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppFonts.prefKey, fontId);
    if (mounted) {
      setState(() => _fontId = fontId);
    }
  }

  Future<void> applyFontScale(double scale, {bool persist = true}) async {
    final next = AppFonts.clampScale(scale);
    fontScale.value = next;
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(AppFonts.scalePrefKey, next);
    }
  }

  void notifyProfileUpdate() {
    _profileUpdateController.add(null);
  }

  String? _themeCacheFontId;
  ColorScheme? _themeCacheLight;
  ColorScheme? _themeCacheDark;
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;

  void _rebuildThemesIfNeeded(ColorScheme light, ColorScheme dark) {
    if (_themeCacheFontId == _fontId &&
        _themeCacheLight == light &&
        _themeCacheDark == dark) {
      return;
    }
    _themeCacheFontId = _fontId;
    _themeCacheLight = light;
    _themeCacheDark = dark;
    _lightTheme = withM3ETheme(
      ThemeData(
        useMaterial3: true,
        colorScheme: light,
        textTheme: AppFonts.textTheme(
          _fontId,
          ThemeData(brightness: Brightness.light).textTheme,
        ),
      ),
    );
    _darkTheme = withM3ETheme(
      ThemeData(
        useMaterial3: true,
        colorScheme: dark,
        textTheme: AppFonts.textTheme(
          _fontId,
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
    );
  }

  ColorScheme _adjustDarkScheme(ColorScheme base) {
    return base.copyWith(
      surface: Color.alphaBlend(
        base.primary.withValues(alpha: 0.05),
        const Color(0xFF0D0D14),
      ),
      surfaceContainerHigh: Color.alphaBlend(
        base.primary.withValues(alpha: 0.08),
        const Color(0xFF1A1A26),
      ),
      surfaceContainerHighest: Color.alphaBlend(
        base.primary.withValues(alpha: 0.12),
        const Color(0xFF262636),
      ),
    );
  }

  ColorScheme _adjustLightScheme(ColorScheme base) {
    return base.copyWith(
      surface: Color.alphaBlend(
        base.primary.withValues(alpha: 0.06),
        const Color(0xFFF5F5FA),
      ),
      surfaceContainerHigh: Color.alphaBlend(
        base.primary.withValues(alpha: 0.08),
        const Color(0xFFEAEAF2),
      ),
      surfaceContainerHighest: Color.alphaBlend(
        base.primary.withValues(alpha: 0.11),
        const Color(0xFFDEDEE8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightBase =
            lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: _fallbackSeed,
              brightness: Brightness.light,
            );
        final darkBase =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: _fallbackSeed,
              brightness: Brightness.dark,
            );

        final lightScheme = _adjustLightScheme(lightBase);
        final darkScheme = _adjustDarkScheme(darkBase);

        _rebuildThemesIfNeeded(lightScheme, darkScheme);

        return MaterialApp(
          title: 'Komet',
          debugShowCheckedModeBanner: false,
          locale: _locale,
          themeMode: ThemeMode.system,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          navigatorKey: KometApp.navigatorKey,
          builder: (context, child) {
            return ValueListenableBuilder<double>(
              valueListenable: fontScale,
              child: child ?? const SizedBox.shrink(),
              builder: (context, scale, appChild) {
                Widget scaledChild = appChild!;
                if ((scale - 1.0).abs() > 0.001) {
                  scaledChild = MediaQuery.withClampedTextScaling(
                    minScaleFactor: scale,
                    maxScaleFactor: scale,
                    child: scaledChild,
                  );
                }
                return ValueListenableBuilder<bool>(
                  valueListenable: fpsOverlayEnabled,
                  child: scaledChild,
                  builder: (context, fpsOn, sChild) {
                    return Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        sChild!,
                        if (fpsOn) const FpsOverlayLayer(),
                      ],
                    );
                  },
                );
              },
            );
          },
          home: const _StartupScreen(),
        );
      },
    );
  }
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null || await TokenStorage.readToken(accountId) == null) {
      _goToLogin();
      return;
    }

    try {
      await accountModule.login(accountId: accountId);
    } catch (_) {}

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
    }
  }

  void _goToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2),
      ),
    );
  }
}

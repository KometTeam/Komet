import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend/api.dart';
import 'backend/modules/account.dart';
import 'backend/modules/messages.dart';
import 'core/storage/app_database.dart';
import 'core/storage/token_storage.dart';
import 'core/protocol/packet.dart';
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
  await api.connect();
  final initialLocale = await _loadInitialLocale();
  runApp(KometApp(initialLocale: initialLocale));
}

class KometApp extends StatefulWidget {
  const KometApp({super.key, required this.initialLocale});

  final Locale initialLocale;
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
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    api.sessionExpiredStream.listen((SessionExpiredException e) async {
      if (_isLoggingOut) return;
      _isLoggingOut = true;

      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId != null) {
        await accountModule.removeAccount(accountId);
      }

      final navState = KometApp.navigatorKey.currentState;
      if (navState != null) {
        final overlayContext = navState.overlay?.context;
        if (overlayContext != null) {
          showCustomNotification(overlayContext, e.message);
        }

        await navState.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      _isLoggingOut = false;
    });
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

  ColorScheme _adjustScheme(ColorScheme base) {
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

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final baseScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: _fallbackSeed,
              brightness: Brightness.dark,
            );

        final darkScheme = _adjustScheme(baseScheme);

        return MaterialApp(
          title: 'Komet',
          debugShowCheckedModeBanner: false,
          locale: _locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
          ),
          navigatorKey: KometApp.navigatorKey,
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
    if (accountId == null) {
      _goToLogin();
      return;
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
    }

    try {
      await accountModule.login(accountId: accountId);
    } catch (_) {}
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

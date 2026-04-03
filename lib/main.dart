import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'backend/api.dart';
import 'backend/modules/account.dart';
import 'backend/modules/messages.dart';
import 'core/storage/app_database.dart';
import 'core/storage/token_storage.dart';
import 'frontend/screens/auth/login_screen.dart';
import 'frontend/screens/chats/chat_list_screen.dart';

final api = Api();
final accountModule = AccountModule(api);
final messagesModule = MessagesModule(api);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init();
  await api.connect();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _fallbackSeed = Color(0xFFC1C4FF);

  static ColorScheme _adjustScheme(ColorScheme base) {
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
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
          ),
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
    } catch (e) {
      debugPrint(
        'Background auto-login failed (safe to ignore if offline): $e',
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

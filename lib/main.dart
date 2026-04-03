import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'backend/api.dart';
import 'backend/modules/account.dart';
import 'core/storage/app_database.dart';
import 'frontend/screens/auth/login_screen.dart';

final api = Api();
final accountModule = AccountModule(api);

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
        final baseScheme = darkDynamic ?? ColorScheme.fromSeed(
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
            textTheme: GoogleFonts.interTextTheme(
              ThemeData.dark().textTheme,
            ),
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}

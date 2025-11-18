import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'phone_entry_screen.dart';
import 'theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'connection_lifecycle_manager.dart';
import 'services/cache_service.dart';
import 'services/avatar_cache_service.dart';
import 'services/chat_cache_service.dart';
import 'services/version_checker.dart';
import 'services/account_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  print("Инициализируем сервисы кеширования...");
  await CacheService().initialize();
  await AvatarCacheService().initialize();
  await ChatCacheService().initialize();
  print("Сервисы кеширования инициализированы");

  print("Инициализируем AccountManager...");
  await AccountManager().initialize();
  await AccountManager().migrateOldAccount();
  print("AccountManager инициализирован");

  final hasToken = await ApiService.instance.hasToken();
  print("При запуске приложения токен ${hasToken ? 'найден' : 'не найден'}");

  if (hasToken) {
    print("Инициируем подключение к WebSocket при запуске...");
    ApiService.instance.connect();
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: ConnectionLifecycleManager(child: MyApp(hasToken: hasToken)),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool hasToken;

  const MyApp({super.key, required this.hasToken});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final Color accentColor =
            (themeProvider.appTheme == AppTheme.system && lightDynamic != null)
            ? lightDynamic.primary
            : themeProvider.accentColor;
        final ThemeData baseLightTheme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.light,
            dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          ),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            titleTextStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ColorScheme.fromSeed(
                seedColor: accentColor,
                brightness: Brightness.light,
              ).onSurface, // ← Используем цвет onSurface из цветовой схемы
            ),
          ),
        );

        final ThemeData baseDarkTheme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.dark,
            dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          ),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            titleTextStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ColorScheme.fromSeed(
                seedColor: accentColor,
                brightness: Brightness.dark,
              ).onSurface, // ← Используем цвет onSurface из цветовой схемы
            ),
          ),
        );
        final ThemeData oledTheme = baseDarkTheme.copyWith(
          scaffoldBackgroundColor: Colors.black,
          colorScheme: baseDarkTheme.colorScheme.copyWith(
            surface: Colors.black,
            surfaceContainerLowest: Colors.black,
            surfaceContainerLow: Colors.black,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.black,
            indicatorColor: accentColor.withOpacity(0.4),
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                );
              }
              return const TextStyle(color: Colors.grey, fontSize: 12);
            }),
            iconTheme: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return IconThemeData(color: accentColor);
              }
              return const IconThemeData(color: Colors.grey);
            }),
          ),
        );

        final ThemeData activeDarkTheme =
            themeProvider.appTheme == AppTheme.black
            ? oledTheme
            : baseDarkTheme;

        return MaterialApp(
          title: 'Komet',
          navigatorKey: navigatorKey,
          builder: (context, child) {
            final showHud = themeProvider.debugShowPerformanceOverlay;
            if (!showHud) return child ?? const SizedBox.shrink();
            return Stack(
              children: [
                if (child != null) child,
                const Positioned(top: 8, right: 56, child: _MiniFpsHud()),
              ],
            );
          },
          theme: baseLightTheme,
          darkTheme: activeDarkTheme,
          themeMode: themeProvider.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          locale: const Locale('ru'),

          home: hasToken ? const HomeScreen() : const PhoneEntryScreen(),
        );
      },
    );
  }
}

class _MiniFpsHud extends StatefulWidget {
  const _MiniFpsHud();

  @override
  State<_MiniFpsHud> createState() => _MiniFpsHudState();
}

class _MiniFpsHudState extends State<_MiniFpsHud> {
  final List<FrameTiming> _timings = <FrameTiming>[];
  static const int _sampleSize = 60;
  double _fps = 0.0;
  double _avgMs = 0.0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    _timings.addAll(timings);
    if (_timings.length > _sampleSize) {
      _timings.removeRange(0, _timings.length - _sampleSize);
    }
    if (_timings.isEmpty) return;
    final double avg =
        _timings
            .map((t) => (t.totalSpan.inMicroseconds) / 1000.0)
            .fold(0.0, (a, b) => a + b) /
        _timings.length;
    setState(() {
      _avgMs = avg;
      _fps = avg > 0 ? (1000.0 / avg) : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 12,
          color: theme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('FPS: ${_fps.toStringAsFixed(0)}'),
            const SizedBox(height: 2),
            Text('${_avgMs.toStringAsFixed(1)} ms/frame'),
          ],
        ),
      ),
    );
  }
}

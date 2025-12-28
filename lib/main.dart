import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'screens/home_screen.dart';
import 'screens/phone_entry_screen.dart';
import 'utils/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:gwid/api/api_service.dart';
import 'connection_lifecycle_manager.dart';
import 'services/cache_service.dart';
import 'services/avatar_cache_service.dart';
import 'services/chat_cache_service.dart';
import 'services/contact_local_names_service.dart';
import 'services/account_manager.dart';
import 'services/music_player_service.dart';
import 'services/whitelist_service.dart';
import 'services/notification_service.dart';
import 'plugins/plugin_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  print("Инициализируем сервисы кеширования...");
  await CacheService().initialize();
  await AvatarCacheService().initialize();
  await ChatCacheService().initialize();
  await ContactLocalNamesService().initialize();
  print("Сервисы кеширования инициализированы");

  print("Инициализируем AccountManager...");
  await AccountManager().initialize();
  await AccountManager().migrateOldAccount();
  print("AccountManager инициализирован");

  print("Инициализируем MusicPlayerService...");
  await MusicPlayerService().initialize();
  print("MusicPlayerService инициализирован");

  print("Инициализируем PluginService...");
  await PluginService().initialize();
  print("PluginService инициализирован");

  print("Инициализируем WhitelistService...");
  await WhitelistService().loadWhitelist();
  print("WhitelistService инициализирован");

  print("Инициализируем NotificationService...");
  await NotificationService().initialize();
  NotificationService().setNavigatorKey(navigatorKey);
  print("NotificationService инициализирован");

  // Запуск фонового сервиса только для Android
  if (Platform.isAndroid) {
    print("Инициализируем фоновый сервис для Android...");
    await initializeBackgroundService();
    print("Фоновый сервис инициализирован");
  }

  final hasToken = await ApiService.instance.hasToken();
  print("При запуске приложения токен ${hasToken ? 'найден' : 'не найден'}");

  if (hasToken) {
    await WhitelistService().validateCurrentUserIfNeeded();

    if (await ApiService.instance.hasToken()) {
      print("Инициируем подключение к WebSocket при запуске...");
      ApiService.instance.connect();
    } else {
      print("Токен удалён после проверки вайтлиста, автологин отключён");
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => MusicPlayerService()),
      ],
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

    if (themeProvider.optimization) {
      timeDilation = 0.001;
    } else {
      timeDilation = 1.0;
    }

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final bool useMaterialYou =
            themeProvider.appTheme == AppTheme.system &&
            lightDynamic != null &&
            darkDynamic != null;

        final Color accentColor = useMaterialYou
            ? lightDynamic.primary
            : themeProvider.accentColor;

        final PageTransitionsTheme pageTransitionsTheme =
            themeProvider.optimization
            ? const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                },
              )
            : PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                },
              );

        final ColorScheme lightScheme = useMaterialYou
            ? lightDynamic
            : ColorScheme.fromSeed(
                seedColor: accentColor,
                brightness: Brightness.light,
                dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
              );

        final ThemeData baseLightTheme = ThemeData(
          colorScheme: lightScheme,
          useMaterial3: true,
          pageTransitionsTheme: pageTransitionsTheme,
          shadowColor: themeProvider.optimization ? Colors.transparent : null,
          splashFactory: themeProvider.optimization ? NoSplash.splashFactory : null,
          appBarTheme: AppBarTheme(
            titleTextStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: lightScheme.onSurface,
            ),
          ),
        );

        final ColorScheme darkScheme = useMaterialYou
            ? darkDynamic
            : ColorScheme.fromSeed(
                seedColor: accentColor,
                brightness: Brightness.dark,
                dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
              );

        final ThemeData baseDarkTheme = ThemeData(
          colorScheme: darkScheme,
          useMaterial3: true,
          pageTransitionsTheme: pageTransitionsTheme,
          shadowColor: themeProvider.optimization ? Colors.transparent : null,
          splashFactory: themeProvider.optimization ? NoSplash.splashFactory : null,
          appBarTheme: AppBarTheme(
            titleTextStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: darkScheme.onSurface,
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
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                );
              }
              return const TextStyle(color: Colors.grey, fontSize: 12);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
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
            final showHud =
                themeProvider.debugShowPerformanceOverlay ||
                themeProvider.showFpsOverlay;
            return SizedBox.expand(
              child: Stack(
                children: [
                  if (child != null) child,
                  if (showHud)
                    const Positioned(top: 8, right: 56, child: _MiniFpsHud()),
                ],
              ),
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
    if (!mounted) return;
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

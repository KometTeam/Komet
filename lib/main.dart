import 'package:flutter/foundation.dart';
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
import 'services/message_queue_service.dart';
import 'plugins/plugin_service.dart';
import 'package:material/material_color_utilities.dart' as mcu;

extension on mcu.DynamicScheme {
  ColorScheme _toColorScheme() => ColorScheme(
    brightness: isDark ? .dark : .light,
    // ignore: deprecated_member_use
    background: Color(background),
    // ignore: deprecated_member_use
    onBackground: Color(onBackground),
    surface: Color(surface),
    surfaceDim: Color(surfaceDim),
    surfaceBright: Color(surfaceBright),
    surfaceContainerLowest: Color(surfaceContainerLowest),
    surfaceContainerLow: Color(surfaceContainerLow),
    surfaceContainer: Color(surfaceContainer),
    surfaceContainerHigh: Color(surfaceContainerHigh),
    surfaceContainerHighest: Color(surfaceContainerHighest),
    onSurface: Color(onSurface),
    // ignore: deprecated_member_use
    surfaceVariant: Color(surfaceVariant),
    onSurfaceVariant: Color(onSurfaceVariant),
    outline: Color(outline),
    outlineVariant: Color(outlineVariant),
    inverseSurface: Color(inverseSurface),
    onInverseSurface: Color(inverseOnSurface),
    shadow: Color(shadow),
    scrim: Color(scrim),
    surfaceTint: Color(surfaceTint),
    primary: Color(primary),
    onPrimary: Color(onPrimary),
    primaryContainer: Color(primaryContainer),
    onPrimaryContainer: Color(onPrimaryContainer),
    primaryFixed: Color(primaryFixed),
    primaryFixedDim: Color(primaryFixedDim),
    onPrimaryFixed: Color(onPrimaryFixed),
    onPrimaryFixedVariant: Color(onPrimaryFixedVariant),
    inversePrimary: Color(inversePrimary),
    secondary: Color(secondary),
    onSecondary: Color(onSecondary),
    secondaryContainer: Color(secondaryContainer),
    onSecondaryContainer: Color(onSecondaryContainer),
    secondaryFixed: Color(secondaryFixed),
    secondaryFixedDim: Color(secondaryFixedDim),
    onSecondaryFixed: Color(onSecondaryFixed),
    onSecondaryFixedVariant: Color(onSecondaryFixedVariant),
    tertiary: Color(tertiary),
    onTertiary: Color(onTertiary),
    tertiaryContainer: Color(tertiaryContainer),
    onTertiaryContainer: Color(onTertiaryContainer),
    tertiaryFixed: Color(tertiaryFixed),
    tertiaryFixedDim: Color(tertiaryFixedDim),
    onTertiaryFixed: Color(onTertiaryFixed),
    onTertiaryFixedVariant: Color(onTertiaryFixedVariant),
    error: Color(error),
    onError: Color(onError),
    errorContainer: Color(errorContainer),
    onErrorContainer: Color(onErrorContainer),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  print("Инициализируем сервисы кеширования...");
  await CacheService().initialize();
  await AvatarCacheService().initialize();
  await ChatCacheService().initialize();
  await ContactLocalNamesService().initialize();
  await MessageQueueService().initialize();
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

  ThemeData _createTheme({
    required ThemeProvider themeProvider,
    required ColorScheme colorScheme,
  }) {
    final PageTransitionsTheme pageTransitionsTheme = themeProvider.optimization
        ? PageTransitionsTheme(
            builders: {
              for (final value in TargetPlatform.values)
                value: const FadeUpwardsPageTransitionsBuilder(),
            },
          )
        : const PageTransitionsTheme(
            builders: {
              // TODO(deminearchiver): добавить поддержку Predictive Back на Android
              //  когда https://github.com/flutter/flutter/pull/174337 будет в stable
              .android: FadeForwardsPageTransitionsBuilder(),
              .fuchsia: OpenUpwardsPageTransitionsBuilder(),
              .iOS: CupertinoPageTransitionsBuilder(),
              .linux: FadeForwardsPageTransitionsBuilder(),
              .macOS: CupertinoPageTransitionsBuilder(),
              .windows: OpenUpwardsPageTransitionsBuilder(),
            },
          );
    return ThemeData(
      colorScheme: colorScheme,
      pageTransitionsTheme: pageTransitionsTheme,
      shadowColor: themeProvider.optimization ? Colors.transparent : null,
      splashFactory: themeProvider.optimization
          ? NoSplash.splashFactory
          : InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.outline,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.outline,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(2.0),
      ),
    );
  }

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

        final accentColor = useMaterialYou
            ? lightDynamic.primary
            : themeProvider.accentColor;

        final lightScheme = useMaterialYou
            ? lightDynamic
            : mcu.DynamicScheme.fromPalettesOrKeyColors(
                isDark: false,
                sourceColorHct: mcu.Hct.fromInt(accentColor.toARGB32()),
                variant: .tonalSpot,
                specVersion: .spec2025,
                platform: .phone,
              )._toColorScheme();

        final baseLightTheme = _createTheme(
          themeProvider: themeProvider,
          colorScheme: lightScheme,
        );

        final darkScheme = useMaterialYou
            ? darkDynamic
            : mcu.DynamicScheme.fromPalettesOrKeyColors(
                isDark: true,
                sourceColorHct: mcu.Hct.fromInt(accentColor.toARGB32()),
                variant: .tonalSpot,
                specVersion: .spec2025,
                platform: .phone,
              )._toColorScheme();

        final baseDarkTheme = _createTheme(
          themeProvider: themeProvider,
          colorScheme: darkScheme,
        );

        final oledScheme = useMaterialYou
            ? darkDynamic
            : mcu.DynamicScheme.fromPalettesOrKeyColors(
                isDark: true,
                sourceColorHct: mcu.Hct.fromInt(accentColor.toARGB32()),
                variant: .tonalSpot,
                specVersion: .spec2025,
                platform: .watch,
              )._toColorScheme();

        final oledTheme =
            _createTheme(
              themeProvider: themeProvider,
              colorScheme: oledScheme,
            ).copyWith(
              // scaffoldBackgroundColor: Colors.black,
              // colorScheme: baseDarkTheme.colorScheme.copyWith(
              //   surface: Colors.black,
              //   surfaceContainerLowest: Colors.black,
              //   surfaceContainerLow: Colors.black,
              // ),
              // navigationBarTheme: NavigationBarThemeData(
              //   backgroundColor: Colors.black,
              //   indicatorColor: accentColor.withValues(alpha: 0.4),
              //   labelTextStyle: WidgetStateProperty.resolveWith((states) {
              //     if (states.contains(WidgetState.selected)) {
              //       return TextStyle(
              //         color: accentColor,
              //         fontSize: 12,
              //         fontWeight: FontWeight.bold,
              //       );
              //     }
              //     return const TextStyle(color: Colors.grey, fontSize: 12);
              //   }),
              //   iconTheme: WidgetStateProperty.resolveWith((states) {
              //     if (states.contains(WidgetState.selected)) {
              //       return IconThemeData(color: accentColor);
              //     }
              //     return const IconThemeData(color: Colors.grey);
              //   }),
              // ),
            );

        final ThemeData activeDarkTheme = themeProvider.appTheme == .black
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
        color: theme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
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

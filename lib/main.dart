import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'dart:math';
import 'screens/home_screen.dart';
import 'screens/phone_entry_screen.dart';
import 'utils/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'utils/device_presets.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _generateInitialAndroidSpoof() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final isSpoofingEnabled = prefs.getBool('spoofing_enabled') ?? false;

    if (isSpoofingEnabled) {
      print('Спуф уже настроен, генерация не требуется');
      return;
    }

    print('Генерируем автоматический спуф для Android...');

    final androidPresets = devicePresets
        .where((p) => p.deviceType == 'ANDROID')
        .toList();

    if (androidPresets.isEmpty) {
      print('Не найдены пресеты для Android');
      return;
    }

    final random = Random();
    final preset = androidPresets[random.nextInt(androidPresets.length)];

    const uuid = Uuid();
    final deviceId = uuid.v4();

    String timezone;
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      timezone = timezoneInfo.identifier;
    } catch (_) {
      timezone = 'Europe/Moscow';
    }

    final locale = Platform.localeName.split('_').first;

    await prefs.setBool('spoofing_enabled', true);
    await prefs.setBool('anonymity_enabled', true);
    await prefs.setString('spoof_useragent', preset.userAgent);
    await prefs.setString('spoof_devicename', preset.deviceName);
    await prefs.setString('spoof_osversion', preset.osVersion);
    await prefs.setString('spoof_screen', preset.screen);
    await prefs.setString('spoof_timezone', timezone);
    await prefs.setString('spoof_locale', locale);
    await prefs.setString('spoof_deviceid', deviceId);
    await prefs.setString('spoof_devicetype', 'ANDROID');
    await prefs.setString('spoof_appversion', '25.21.3');

    print('Спуф для Android успешно сгенерирован:');
    print('  - Устройство: ${preset.deviceName}');
    print('  - ОС: ${preset.osVersion}');
    print('  - Device ID: $deviceId');
    print('  - Часовой пояс: $timezone');
    print('  - Локаль: $locale');
  } catch (e) {
    print('Ошибка при генерации спуфа: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  print("Генерируем спуф для Android при первом запуске...");
  await _generateInitialAndroidSpoof();
  print("Проверка и генерация спуфа завершена");

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

  print("Очищаем сессионные значения...");
  await ApiService.clearSessionValues();
  print("Сессионные значения очищены");

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
    return ThemeData(
      colorScheme: colorScheme,
      shadowColor: themeProvider.optimization ? Colors.transparent : null,
      splashFactory: themeProvider.optimization
          ? NoSplash.splashFactory
          : InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        toolbarHeight: 64.0,
        // Убираем устаревший surfaceTint и оставляем только surfaceContainer
        // при состоянии scrolled under
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // Стиль текста заголовка
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        thumbIcon: const WidgetStatePropertyAll(null),
        splashRadius: 40.0 / 2.0,
        trackColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(0.0),
        trackOutlineColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          final stateLayerColor = states.contains(WidgetState.selected)
              ? colorScheme.primaryContainer
              : colorScheme.onSurfaceVariant;
          final double stateLayerOpacity;
          if (states.contains(WidgetState.disabled)) {
            stateLayerOpacity = 0.0;
          } else if (states.contains(WidgetState.pressed)) {
            stateLayerOpacity = 0.10;
          } else if (states.contains(WidgetState.focused)) {
            stateLayerOpacity = 0.1;
          } else if (states.contains(WidgetState.hovered)) {
            stateLayerOpacity = 0.08;
          } else {
            stateLayerOpacity = 0.0;
          }
          return stateLayerOpacity > 0.0
              ? stateLayerColor.withValues(alpha: stateLayerOpacity)
              : stateLayerColor.withAlpha(0);
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        height: 64.0,
        elevation: 0.0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      pageTransitionsTheme: themeProvider.optimization
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
              },
            )
          : const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final padding = MediaQuery.paddingOf(context);

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

        final ColorScheme lightScheme = useMaterialYou
            ? lightDynamic
            : ColorScheme.fromSeed(
                seedColor: accentColor,
                brightness: Brightness.light,
                dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
              );

        final ThemeData baseLightTheme = _createTheme(
          themeProvider: themeProvider,
          colorScheme: lightScheme,
        );

        final ColorScheme darkScheme = useMaterialYou
            ? darkDynamic
            : ColorScheme.fromSeed(
                seedColor: accentColor,
                brightness: Brightness.dark,
                dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
              );

        final ThemeData darkTheme = _createTheme(
          themeProvider: themeProvider,
          colorScheme: darkScheme,
        );

        final ThemeData oledTheme = darkTheme.copyWith(
          scaffoldBackgroundColor: Colors.black,
          colorScheme: darkTheme.colorScheme.copyWith(
            surface: Colors.black,
            surfaceContainerLowest: Colors.black,
            surfaceContainerLow: Colors.black,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.black,
            indicatorColor: accentColor.withValues(alpha: 0.4),
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
            themeProvider.appTheme == AppTheme.black ? oledTheme : darkTheme;

        return MaterialApp(
          title: 'Komet',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          locale: const Locale('ru'),
          themeMode: themeProvider.themeMode,
          theme: baseLightTheme,
          darkTheme: activeDarkTheme,
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
                    Positioned(
                      top: 64.0 + 48.0 + 16.0,
                      right: 16.0,
                      child: Padding(
                        padding: padding,
                        child: IgnorePointer(child: _MiniFpsHud()),
                      ),
                    ),
                ],
              ),
            );
          },
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
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    return Material(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12.0)),
      ),
      color: themeProvider.optimization
          ? colorScheme.inverseSurface
          : colorScheme.surfaceContainer,
      elevation: themeProvider.optimization
          ? 0.0
          // md.sys.elevation.level3
          : 6.0,
      shadowColor: colorScheme.shadow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: DefaultTextStyle(
          textAlign: TextAlign.end,
          style: textTheme.labelSmall!.copyWith(
            fontFamily: "monospace",
            fontWeight: FontWeight.w600,
            fontVariations: [FontVariation.weight(600.0)],
            fontFeatures: const [FontFeature.tabularFigures()],
            color: themeProvider.optimization
                ? colorScheme.onInverseSurface
                : colorScheme.onSurfaceVariant,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_fps.toStringAsFixed(0)} fps'),
              const SizedBox(height: 4.0),
              Text('${_avgMs.toStringAsFixed(1)} ms'),
            ],
          ),
        ),
      ),
    );
  }
}

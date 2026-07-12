import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:m3e_collection/m3e_collection.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend/api.dart';
import 'core/cache/info_cache.dart';
import 'core/utils/logger.dart';
import 'core/cache/self_presence.dart';
import 'core/storage/app_instance.dart';
import 'core/storage/draft_store.dart';
import 'core/storage/archived_chats_store.dart';
import 'core/config/app_accent.dart';
import 'core/config/app_amoled.dart';
import 'core/config/app_show_extra_info.dart';
import 'core/config/app_bubble_behavior.dart';
import 'core/config/komet_settings.dart';
import 'core/config/debug_test.dart';
import 'core/config/app_bubble_shape.dart';
import 'core/config/app_cache_extent.dart';
import 'core/config/app_fonts.dart';
import 'core/config/custom_font_service.dart';
import 'core/config/app_message_actions_style.dart';
import 'core/config/app_swipe_back_desktop.dart';
import 'core/config/app_pranks.dart';
import 'core/config/app_stories.dart';
import 'core/config/app_commands.dart';
import 'core/config/app_link_preview.dart';
import 'core/config/app_media_cache.dart';
import 'core/config/app_pill_gradient.dart';
import 'core/config/app_visual_style.dart';
import 'core/config/app_chat_chrome.dart';
import 'core/config/app_wallpaper_tint.dart';
import 'core/storage/chat_wallpaper_store.dart';
import 'core/utils/wallpaper_seed.dart';
import 'core/config/app_theme_mode.dart';
import 'core/config/app_theme_schedule.dart';
import 'core/config/app_digital_id_mode.dart';
import 'backend/modules/account.dart';
import 'backend/modules/chats.dart';
import 'backend/modules/contacts.dart';
import 'backend/modules/file_uploader.dart';
import 'backend/modules/messages.dart';
import 'backend/modules/outbox.dart';
import 'backend/modules/polls.dart';
import 'backend/modules/stickers.dart';
import 'backend/modules/animoji.dart';
import 'backend/modules/stories.dart';
import 'backend/modules/self_check.dart';
import 'backend/modules/shared_content.dart';
import 'backend/modules/webapp.dart';
import 'backend/modules/digital_id.dart';
import 'core/calls/call_bridge.dart';
import 'core/calls/call_controller.dart';
import 'core/links/deep_link_service.dart';
import 'frontend/screens/calls/call_screen.dart';
import 'core/push/push_service.dart';
import 'core/storage/app_database.dart';
import 'core/transport/tls_config.dart';
import 'core/transport/traffic_monitor.dart';
import 'core/transport/vpn_bypass.dart';
import 'core/storage/token_storage.dart';
import 'core/utils/haptics.dart';
import 'core/utils/debug_session_log.dart';
import 'core/protocol/packet.dart';
import 'frontend/debug/fps_overlay_layer.dart';
import 'frontend/screens/auth/login_screen.dart';
import 'frontend/widgets/adaptive_shell.dart';
import 'frontend/widgets/custom_notification.dart';
import 'frontend/widgets/theme_reveal.dart';

final api = Api();
final accountModule = AccountModule(api);
final messagesModule = MessagesModule(api);
final sharedContentModule = SharedContentModule(api);
final pollsModule = PollsModule(api);
final stickersModule = StickersModule(api);
final animojiModule = AnimojiModule(api);
final webAppModule = WebAppModule(api);
final digitalIdModule = DigitalIdModule(webAppModule);
final fileUploader = FileUploader(api: api, messages: messagesModule);
final storiesModule = StoriesModule(api);
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

bool isOnemeFlavor = false;

const PageTransitionsTheme _appPageTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    TargetPlatform.linux: ZoomPageTransitionsBuilder(),
  },
);

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

void _installLogCapture() {
  final previousDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      final t = DateTime.now();
      final stamp =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}.${t.millisecond.toString().padLeft(3, '0')}';
      DebugSessionLog.instance.recordLogLine('  |$stamp P $message');
    }
    previousDebugPrint(message, wrapWidth: wrapWidth);
  };

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    DebugSessionLog.instance.recordLogLine(
      '  |         FlutterError: ${details.exceptionAsString()}',
    );
    if (details.stack != null) {
      DebugSessionLog.instance.recordLogLine(details.stack.toString());
    }
    if (previousFlutterOnError != null) {
      previousFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformOnError = ui.PlatformDispatcher.instance.onError;
  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    DebugSessionLog.instance.recordLogLine('  |         Uncaught: $error');
    DebugSessionLog.instance.recordLogLine(stack.toString());
    if (previousPlatformOnError != null) {
      return previousPlatformOnError(error, stack);
    }
    return false;
  };
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  DebugTest.parse(args);
  _installLogCapture();
  VideoPlayerMediaKit.ensureInitialized(
    windows: true,
    linux: true,
    macOS: true,
  );
  if (AppInstance.isNamed) {
    SharedPreferences.setPrefix('flutter.${AppInstance.id}.');
  }
  await AppDatabase.init();
  final activeAccountId = await TokenStorage.getActiveAccountId();
  if (activeAccountId != null) {
    await ContactsModule.primeCacheFromDb(activeAccountId);
  }
  attachInfoCacheApi(api);
  chats.attachGlobalPushHandlers(api);
  storiesModule.attach();
  unawaited(storiesModule.loadCache());
  unawaited(DeepLinkService.instance.init());

  final packageInfoFuture = PackageInfo.fromPlatform();
  final localeFuture = _loadInitialLocale();
  final hapticsFuture = Haptics.load();
  final prefsFuture = SharedPreferences.getInstance();
  final accentFuture = AppAccent.load();
  final bubbleShapeFuture = AppBubbleShape.load();
  final bubbleBehaviorFuture = AppBubbleBehavior.load();
  final cacheExtentFuture = AppCacheExtent.load();
  final themeModeFuture = AppThemeModeConfig.load();
  final amoledFuture = AppAmoled.load();
  final pillGradientFuture = AppPillGradient.load();
  final visualStyleFuture = AppVisualStyle.load();
  final chatChromeFuture = AppChatChrome.load();
  final wallpaperTintFuture = AppWallpaperTint.load();
  final themeScheduleFuture = AppThemeSchedule.load();
  final messageActionsFuture = AppMessageActionsStyle.load();
  final swipeBackFuture = AppSwipeBackDesktop.load();
  final pranksFuture = AppPranks.load();
  final storiesFuture = AppStories.load();
  final commandsFuture = AppCommands.load();
  final linkPreviewFuture = AppLinkPreview.load();
  final cacheLimitFuture = AppMediaCacheLimit.load();
  final digitalIdNativeFuture = AppDigitalIdNative.load();
  final showExtraInfoFuture = AppShowExtraInfo.load();
  final trafficCaptureFuture = TrafficMonitor.instance.load();
  final debugLogFuture = DebugSessionLog.instance.init();

  final packageInfo = await packageInfoFuture;
  isOnemeFlavor = packageInfo.packageName == 'ru.oneme.app';

  final initialLocale = await localeFuture;

  await hapticsFuture;

  final prefs = await prefsFuture;
  await FileHistoryCache.load(prefs);
  await DraftStore.instance.load();
  await ArchivedChatsStore.instance.load();
  await KometSettings.load();
  if (KometSettings.ghostMode.value) SelfPresence.markOffline();
  await ContactCache.load();
  final initialFpsOverlay = prefs.getBool('dev_fps_overlay') ?? false;
  final initialVpnBypass = prefs.getBool(VpnBypassService.prefKey) ?? false;
  final initialTlsInsecure = prefs.getBool(TlsConfig.prefKey) ?? false;
  final initialFontId =
      prefs.getString(AppFonts.prefKey) ?? AppFonts.fallback.id;
  final initialFontScale = AppFonts.clampScale(
    prefs.getDouble(AppFonts.scalePrefKey) ?? AppFonts.defaultScale,
  );
  if (AppFonts.resolve(initialFontId).isCustom) {
    await CustomFontService.preloadCached();
  } else {
    unawaited(CustomFontService.preloadCached());
  }
  final initialAccentSeed = await accentFuture;
  await Future.wait<dynamic>([
    bubbleShapeFuture,
    bubbleBehaviorFuture,
    cacheExtentFuture,
    themeModeFuture,
    amoledFuture,
    pillGradientFuture,
    visualStyleFuture,
    chatChromeFuture,
    wallpaperTintFuture,
    themeScheduleFuture,
    messageActionsFuture,
    swipeBackFuture,
    pranksFuture,
    storiesFuture,
    commandsFuture,
    linkPreviewFuture,
    cacheLimitFuture,
    digitalIdNativeFuture,
    showExtraInfoFuture,
  ]);
  await trafficCaptureFuture;
  await debugLogFuture;
  runApp(
    KometApp(
      initialLocale: initialLocale,
      initialFpsOverlay: initialFpsOverlay,
      initialVpnBypass: initialVpnBypass,
      initialTlsInsecure: initialTlsInsecure,
      initialFontId: initialFontId,
      initialFontScale: initialFontScale,
      initialAccentSeed: initialAccentSeed,
    ),
  );
}

class KometApp extends StatefulWidget {
  const KometApp({
    super.key,
    required this.initialLocale,
    this.initialFpsOverlay = false,
    this.initialVpnBypass = false,
    this.initialTlsInsecure = false,
    required this.initialFontId,
    required this.initialFontScale,
    this.initialAccentSeed,
  });

  final Locale initialLocale;
  final bool initialFpsOverlay;
  final bool initialVpnBypass;
  final bool initialTlsInsecure;
  final String initialFontId;
  final double initialFontScale;
  final Color? initialAccentSeed;
  static final navigatorKey = GlobalKey<NavigatorState>();

  static KometAppState? stateOf(BuildContext context) {
    return context.findAncestorStateOfType<KometAppState>();
  }

  @override
  State<KometApp> createState() => KometAppState();
}

class KometAppState extends State<KometApp>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _fallbackSeed = Color(0xFFC1C4FF);

  final GlobalKey _captureBoundaryKey = GlobalKey();
  OverlayEntry? _revealEntry;
  AnimationController? _revealController;
  ui.Image? _revealImage;

  late Locale _locale;
  late String _fontId;
  bool _isLoggingOut = false;
  bool _shellReady = false;
  bool _incomingRouteActive = false;
  IncomingCall? _pendingIncoming;
  late final ValueNotifier<Color?> accentSeed = ValueNotifier(
    widget.initialAccentSeed,
  );
  final ValueNotifier<Color?> wallpaperSeed = ValueNotifier(null);
  StreamSubscription<SessionExpiredException>? _sessionExpiredSub;
  StreamSubscription<LoginStatus>? _loginStatusSub;
  StreamSubscription<VpnBypassResult>? _vpnBypassSub;
  StreamSubscription<IncomingCall>? _callIncomingSub;
  StreamSubscription<String>? _serverErrorSub;
  Timer? _scheduleTimer;
  String? _lastVpnNotice;
  DateTime _lastVpnNoticeAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastServerError;
  DateTime _lastServerErrorAt = DateTime.fromMillisecondsSinceEpoch(0);
  late final ValueNotifier<bool> fpsOverlayEnabled = ValueNotifier(
    widget.initialFpsOverlay,
  );
  late final ValueNotifier<bool> vpnBypassEnabled = ValueNotifier(
    widget.initialVpnBypass,
  );
  late final ValueNotifier<bool> tlsInsecureEnabled = ValueNotifier(
    widget.initialTlsInsecure,
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

    WidgetsBinding.instance.addObserver(this);
    AppThemeModeConfig.current.addListener(_onThemeModeChanged);
    AppAmoled.current.addListener(_onAmoledChanged);
    AppThemeSchedule.current.addListener(_onScheduleChanged);
    AppWallpaperTint.current.addListener(_onWallpaperTintChanged);
    ChatWallpaperStore.instance.revision.addListener(_onWallpaperTintChanged);
    _lastAppliedThemeMode = _effectiveThemeMode;
    _rescheduleSwitch();
    unawaited(_refreshWallpaperSeed());

    api.setReconnectCallback(() async {
      try {
        final accountId = await TokenStorage.getActiveAccountId();
        if (accountId != null) {
          final token = await TokenStorage.readToken(accountId);
          if (token != null) {
            await accountModule.login(accountId: accountId, token: token);
          }
        }
      } catch (e) {
        logger.w('reconnect login failed: $e');
      }
    });

    _loginStatusSub = accountModule.loginStatusStream.listen((status) async {
      if (status == LoginStatus.success) {
        DeepLinkService.instance.markReady();
        unawaited(_refreshWallpaperSeed());
        CallController.instance.init(api);
        OutboxService.instance.init(api, messagesModule);
        SelfCheckService.instance.init(api);
        SelfCheckService.instance.checkNow();
        if (isOnemeFlavor) {
          await PushService.instance.init(api: api, account: accountModule);
          await PushService.instance.onLoginSuccess();
          await _ensureFullScreenIntentPermission();
        }
      }
    });

    _callIncomingSub = CallController.instance.incomingCalls.listen(
      _onIncomingCall,
    );
    CallController.instance.appResumed = true;
    CallBridge.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CallBridge.instance.checkInitialCall();
    });

    _sessionExpiredSub = api.sessionExpiredStream.listen((
      SessionExpiredException e,
    ) async {
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

    _serverErrorSub = api.errorStream.listen((msg) {
      final now = DateTime.now();
      if (msg == _lastServerError &&
          now.difference(_lastServerErrorAt).inSeconds < 3) {
        return;
      }
      _lastServerError = msg;
      _lastServerErrorAt = now;

      final overlay = KometApp.navigatorKey.currentState?.overlay;
      if (overlay != null) {
        showCustomNotificationOnOverlay(overlay, msg);
      }
    });
  }

  Future<void> _ensureFullScreenIntentPermission() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('fsi_prompted') ?? false) return;
    if (await CallBridge.instance.canUseFullScreenIntent()) return;
    await prefs.setBool('fsi_prompted', true);
    await CallBridge.instance.openFullScreenIntentSettings();
  }

  void _onIncomingCall(IncomingCall call) {
    _pendingIncoming = call;
    _presentIncomingCall();
  }

  void markShellReady() {
    if (_shellReady) return;
    _shellReady = true;
    _presentIncomingCall();
  }

  void _presentIncomingCall() {
    final call = _pendingIncoming;
    if (call == null || _incomingRouteActive || !_shellReady) return;
    final navState = KometApp.navigatorKey.currentState;
    if (navState == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _presentIncomingCall(),
      );
      return;
    }
    _incomingRouteActive = true;
    navState
        .push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              name: ContactCache.get(call.callerId) ?? call.callerName ?? '',
              avatarUrl: ContactCache.getAvatar(call.callerId),
              incoming: call,
              autoAccept: call.autoAccept,
            ),
          ),
        )
        .whenComplete(() {
          _incomingRouteActive = false;
          if (identical(_pendingIncoming, call)) _pendingIncoming = null;
        });
  }

  @override
  void dispose() {
    _finishReveal();
    _sessionExpiredSub?.cancel();
    _loginStatusSub?.cancel();
    _vpnBypassSub?.cancel();
    _callIncomingSub?.cancel();
    _serverErrorSub?.cancel();
    _scheduleTimer?.cancel();
    AppThemeModeConfig.current.removeListener(_onThemeModeChanged);
    AppAmoled.current.removeListener(_onAmoledChanged);
    AppThemeSchedule.current.removeListener(_onScheduleChanged);
    AppWallpaperTint.current.removeListener(_onWallpaperTintChanged);
    ChatWallpaperStore.instance.revision.removeListener(_onWallpaperTintChanged);
    WidgetsBinding.instance.removeObserver(this);
    _profileUpdateController.close();
    fpsOverlayEnabled.dispose();
    vpnBypassEnabled.dispose();
    tlsInsecureEnabled.dispose();
    fontScale.dispose();
    accentSeed.dispose();
    wallpaperSeed.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    CallController.instance.appResumed = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      DebugSessionLog.instance.flushNow();
      SelfCheckService.instance.pause();
    }
    if (state != AppLifecycleState.resumed) return;
    api.wakeUp();
    SelfCheckService.instance.resume();
    CallBridge.instance.checkInitialCall();
    if (AppThemeModeConfig.current.value != AppThemeMode.schedule) return;
    _rescheduleSwitch();
    final next = _effectiveThemeMode;
    if (next == _lastAppliedThemeMode) return;
    _lastAppliedThemeMode = next;
    if (mounted) setState(() {});
  }

  void _onThemeModeChanged() {
    _rescheduleSwitch();
    _lastAppliedThemeMode = _effectiveThemeMode;
    if (mounted) setState(() {});
  }

  void _onAmoledChanged() {
    if (mounted) setState(() {});
  }

  void _onScheduleChanged() {
    if (AppThemeModeConfig.current.value != AppThemeMode.schedule) return;
    _rescheduleSwitch();
    final next = _effectiveThemeMode;
    if (next == _lastAppliedThemeMode) return;
    _lastAppliedThemeMode = next;
    if (mounted) setState(() {});
  }

  ThemeMode _lastAppliedThemeMode = ThemeMode.system;

  void _rescheduleSwitch() {
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
    if (AppThemeModeConfig.current.value != AppThemeMode.schedule) return;
    final until = AppThemeSchedule.current.value.durationUntilNextSwitch(
      DateTime.now(),
    );
    _scheduleTimer = Timer(until, () {
      if (!mounted) return;
      _lastAppliedThemeMode = _effectiveThemeMode;
      setState(() {});
      _rescheduleSwitch();
    });
  }

  ThemeMode get _effectiveThemeMode {
    switch (AppThemeModeConfig.current.value) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.schedule:
        final isDark = AppThemeSchedule.current.value.isDarkAt(DateTime.now());
        return isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  Future<void> applyThemeMode(AppThemeMode mode) async {
    await AppThemeModeConfig.save(mode);
  }

  void applyThemeModeWithReveal(AppThemeMode mode, Offset center) {
    if (AppThemeModeConfig.current.value == mode) return;
    _runThemeReveal(center, () => AppThemeModeConfig.save(mode));
  }

  Future<void> applyAmoled(bool value) async {
    await AppAmoled.save(value);
  }

  void applyAmoledWithReveal(bool value, Offset center) {
    if (AppAmoled.current.value == value) return;
    _runThemeReveal(center, () => AppAmoled.save(value));
  }

  void _runThemeReveal(Offset center, Future<void> Function() apply) {
    final overlay = KometApp.navigatorKey.currentState?.overlay;
    final ctx = _captureBoundaryKey.currentContext;
    if (overlay == null || ctx == null) {
      apply();
      return;
    }
    if (MediaQuery.disableAnimationsOf(ctx)) {
      apply();
      return;
    }
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      apply();
      return;
    }

    final ui.Image snapshot;
    try {
      final dpr = math.min(MediaQuery.of(ctx).devicePixelRatio, 2.0);
      snapshot = renderObject.toImageSync(pixelRatio: dpr);
    } catch (_) {
      apply();
      return;
    }

    _finishReveal();

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    final entry = ThemeRevealOverlay.build(
      snapshot: snapshot,
      center: center,
      animation: controller,
    );

    _revealController = controller;
    _revealEntry = entry;
    _revealImage = snapshot;

    overlay.insert(entry);
    apply();

    WidgetsBinding.instance.endOfFrame.then((_) {
      if (_revealController != controller) return;
      controller.forward().then((_) {
        if (_revealController != controller) return;
        _finishReveal();
      }, onError: (_) {});
    });
  }

  void _finishReveal() {
    _revealEntry?.remove();
    _revealEntry = null;
    _revealController?.dispose();
    _revealController = null;
    final img = _revealImage;
    _revealImage = null;
    if (img != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => img.dispose());
    }
  }

  Future<void> applyThemeSchedule(ThemeSchedule schedule) async {
    await AppThemeSchedule.save(schedule);
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

  Future<void> setTlsInsecureEnabled(bool value) async {
    if (tlsInsecureEnabled.value == value) return;
    tlsInsecureEnabled.value = value;
    await TlsConfig.setInsecureAllowed(value);
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

  Future<void> applyAccentColor(Color? seed) async {
    await AppAccent.save(seed);
    accentSeed.value = seed;
  }

  void _onWallpaperTintChanged() => unawaited(_refreshWallpaperSeed());

  Future<void> _refreshWallpaperSeed() async {
    if (!AppWallpaperTint.current.value) {
      wallpaperSeed.value = null;
      return;
    }
    final profile = await AppDatabase.loadActiveProfile();
    final accountId = profile?.id ?? 0;
    if (accountId == 0) {
      wallpaperSeed.value = null;
      return;
    }
    await ChatWallpaperStore.instance.load();
    final wallpaper =
        ChatWallpaperStore.instance.get(accountId, kGlobalWallpaperChatId);
    final seed = await computeWallpaperSeed(wallpaper);
    if (!mounted) return;
    wallpaperSeed.value = seed;
  }

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

  Color? _seedCacheKey;
  ColorScheme? _seedCacheLight;
  ColorScheme? _seedCacheDark;

  ({ColorScheme light, ColorScheme dark}) _schemesForSeed(Color seed) {
    if (_seedCacheKey == seed &&
        _seedCacheLight != null &&
        _seedCacheDark != null) {
      return (light: _seedCacheLight!, dark: _seedCacheDark!);
    }
    _seedCacheKey = seed;
    _seedCacheLight = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    _seedCacheDark = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return (light: _seedCacheLight!, dark: _seedCacheDark!);
  }

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
        pageTransitionsTheme: _appPageTransitions,
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
        pageTransitionsTheme: _appPageTransitions,
        textTheme: AppFonts.textTheme(
          _fontId,
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
    );
  }

  ColorScheme _adjustDarkScheme(ColorScheme base) {
    if (AppAmoled.current.value) {
      return base.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF080808),
        surfaceContainer: const Color(0xFF101010),
        surfaceContainerHigh: const Color(0xFF161616),
        surfaceContainerHighest: const Color(0xFF1C1C1C),
      );
    }
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
        return ListenableBuilder(
          listenable: Listenable.merge([
            accentSeed,
            wallpaperSeed,
            AppWallpaperTint.current,
          ]),
          builder: (context, _) {
            final seed = AppWallpaperTint.current.value &&
                    wallpaperSeed.value != null
                ? wallpaperSeed.value
                : accentSeed.value;
            final ColorScheme lightBase;
            final ColorScheme darkBase;
            if (seed != null) {
              final s = _schemesForSeed(seed);
              lightBase = s.light;
              darkBase = s.dark;
            } else if (lightDynamic != null && darkDynamic != null) {
              lightBase = lightDynamic;
              darkBase = darkDynamic;
            } else {
              final s = _schemesForSeed(_fallbackSeed);
              lightBase = lightDynamic ?? s.light;
              darkBase = darkDynamic ?? s.dark;
            }

            final lightScheme = _adjustLightScheme(lightBase);
            final darkScheme = _adjustDarkScheme(darkBase);

            _rebuildThemesIfNeeded(lightScheme, darkScheme);

            return MaterialApp(
              title: 'Komet',
              debugShowCheckedModeBanner: false,
              locale: _locale,
              themeMode: _effectiveThemeMode,
              themeAnimationDuration: Duration.zero,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: _lightTheme,
              darkTheme: _darkTheme,
              navigatorKey: KometApp.navigatorKey,
              navigatorObservers: [appRouteObserver],
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
                            RepaintBoundary(
                              key: _captureBoundaryKey,
                              child: sChild!,
                            ),
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
    if (DebugTest.enabled) {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdaptiveShell()),
      );
      KometApp.stateOf(context)?.markShellReady();
      return;
    }

    unawaited(api.connect());

    int? accountId = await TokenStorage.getActiveAccountId();

    if (accountId == null || await TokenStorage.readToken(accountId) == null) {
      accountId = await _recoverActiveAccount();
    }

    if (!mounted) return;

    if (accountId == null) {
      _goToLogin();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdaptiveShell()),
    );
    KometApp.stateOf(context)?.markShellReady();
  }

  Future<int?> _recoverActiveAccount() async {
    final profiles = await AppDatabase.loadAllProfiles();
    for (final profile in profiles) {
      if (await TokenStorage.readToken(profile.id) != null) {
        await TokenStorage.setActiveAccount(profile.id);
        await AppDatabase.setActiveAccount(profile.id);
        await ContactsModule.primeCacheFromDb(profile.id);
        return profile.id;
      }
    }
    return null;
  }

  void _goToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      KometApp.stateOf(context)?.markShellReady();
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

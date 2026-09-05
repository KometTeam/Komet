import 'dart:async';
import 'dart:convert';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:kolibri/kolibri.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../core/cache/self_presence.dart';
import '../core/config/config.dart';
import '../core/config/countries.dart';
import '../core/config/device_profile.dart';
import '../core/config/komet_settings.dart';
import '../core/config/proxy_config.dart';
import '../core/protocol/opcode_map.dart';
import '../core/protocol/packet.dart';
import '../core/storage/device_identity.dart';
import '../core/storage/spoofing_service.dart';
import '../core/transport/dispatcher.dart';
import '../core/transport/tls_config.dart';
import '../core/transport/traffic_monitor.dart';
import '../core/transport/vpn_bypass.dart';
import '../core/utils/app_foreground.dart';
import '../core/utils/debug_session_log.dart';
import '../core/utils/device_locale.dart';
import '../core/utils/logger.dart';

// #***! состояния сеськи
enum SessionState { disconnected, connecting, connected, online }

// #***! весь жизненный цикл соединения
/// Клиент API
class Api {
  KolibriSession? _session;

  final PacketDispatcher _dispatcher = PacketDispatcher();
  StreamSubscription<(int, Map<String, dynamic>)>? _pushSub;
  StreamSubscription<WireLogEvent>? _wireLogSub;

  // #***! текущее состояние плюс четыре стрима наружу на которые юишка подписана
  SessionState _sessionState = SessionState.disconnected;
  final _stateController = StreamController<SessionState>.broadcast();
  final _sessionExpiredController =
      StreamController<SessionExpiredException>.broadcast();
  final _handshakeSuccessController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Map<dynamic, dynamic>? _userAgent;
  Map<dynamic, dynamic>? get userAgent => _userAgent;

  // #***! полезные данные после логина кому то нужные
  int? _callsSeed;
  String? _deviceId;
  String? _callsDevice;
  String? _callsOsVersion;

  int? get callsSeed => _callsSeed;
  String? get deviceId => _deviceId;
  String? get callsDevice => _callsDevice;
  String? get callsOsVersion => _callsOsVersion;

  /// Сырой доступ к сессии для медиа загрузок
  KolibriSession? get session => _session;

  String? spoofScope;

  static bool _tzInitialized = false;

  List<CountryName>? _registrationCountries;

  List<CountryName> get registrationCountries =>
      _registrationCountries ?? allCountries;

  Stream<SessionState> get stateStream => _stateController.stream;
  Stream<SessionExpiredException> get sessionExpiredStream =>
      _sessionExpiredController.stream;
  Stream<String> get handshakeSuccessStream =>
      _handshakeSuccessController.stream;
  Stream<String> get errorStream => _errorController.stream;
  SessionState get state => _sessionState;

  // #***! таймеры и счётчики автореконнекта
  Timer? _livenessTimer;
  Timer? _reconnectTimer;
  Timer? _connectWatchdog;
  // #***! поколение попытки конекта
  int _connectGen = 0;
  int _reconnectAttempts = 0;
  bool _autoReconnect = false;
  int _sessionEpoch = 0;
  bool? _lastInteractive;

  // #***! тайминги
  static const Duration _connectWatchdogTimeout = Duration(seconds: 75);
  static const Duration _shouldArmTimeout = Duration(seconds: 5);
  static const Duration _endpointTimeout = Duration(seconds: 5);
  static const Duration _livenessInterval = Duration(seconds: 5);
  static const int _foregroundReconnectCapSec = 15;
  static const int _backgroundReconnectCapSec = 60;

  int get sessionEpoch => _sessionEpoch;

  // Публичное API

  // #***!сокет, хэндшейк, пинг, автологин
  /// Подключается к серверу и хендшейк шлет
  Future<void> connect() async {
    if (_sessionState != SessionState.disconnected) {
      logger.i('connect пропущен: состояние ${_sessionState.name}');
      return;
    }
    _autoReconnect = true;
    // #***! номер поколения
    final gen = ++_connectGen;
    _setSessionState(SessionState.connecting);
    logger.i('connect: старт (поколение $gen)');
    // #***! Сторож если конект залип на всякий
    _armConnectWatchdog(gen);

    KolibriSession? built;
    try {
      bool useBypass;
      try {
        // #***! Если обход впн подвиснет нахуй пойдет
        useBypass = await VpnBypassService.instance.shouldArm().timeout(
          _shouldArmTimeout,
        );
      } catch (e) {
        logger.w('connect: shouldArm завис/упал ($e) — без обхода VPN');
        useBypass = false;
      }
      if (gen != _connectGen) return;

      ({String host, int port, bool trustMincifryCa, bool trustKnownAvTls})
      endpoint;
      try {
        endpoint = await ServerConfig.loadEndpoint().timeout(_endpointTimeout);
      } catch (e) {
        logger.w('connect: loadEndpoint завис/упал ($e) — дефолтный endpoint');
        endpoint = (
          host: ServerConfig.defaultHost,
          port: ServerConfig.defaultPort,
          trustMincifryCa: ServerConfig.defaultTrustMincifryCa,
          trustKnownAvTls: ServerConfig.defaultTrustKnownAvTls,
        );
      }
      if (gen != _connectGen) return;

      setTrustMincifryCa(enabled: endpoint.trustMincifryCa);
      setTrustKnownAvTls(enabled: endpoint.trustKnownAvTls);

      final (session, wireLog) = await _buildSessionOptions(endpoint);
      built = session;
      if (gen != _connectGen) return;

      logger.i(
        'connect: endpoint ${endpoint.host}:${endpoint.port}, bypass=$useBypass',
      );

      if (useBypass) {
        try {
          await VpnBypassService.instance.bind();
        } catch (e) {
          logger.w('connect: VPN bind не удался ($e)');
        }
      }

      _session = session;
      _wireLogSub?.cancel();
      _wireLogSub = wireLog.listen(_onWireLog);
      _pushSub?.cancel();
      _pushSub = session.pushesMap().listen(_onPush);
      TrafficMonitor.instance.recordEvent(
        'connect',
        endpoint: '${endpoint.host}:${endpoint.port}',
      );

      _setSessionState(SessionState.connected);
      _reconnectAttempts = 0;

      // #***! Сервер отвечает кто мы для него💔
      HandshakeInfo info;
      try {
        logger.i('connect: сокет готов, отправляю хэндшейк');
        info = await session.connect();
      } catch (e) {
        if (gen != _connectGen) return;
        await _handleConnectFailure(e, phase: 'Ошибка хэндшейка');
        return;
      } finally {
        if (useBypass) {
          try {
            await VpnBypassService.instance.restoreDefault();
          } catch (_) {}
        }
      }
      if (gen != _connectGen) return;

      _callsSeed = info.callsSeed?.toInt();
      _registrationCountries = _parseRegistrationCountries(info.payloadMap);
      _sessionState = SessionState.online;
      _sessionEpoch++;
      _cancelConnectWatchdog();
      _startLiveness();
      logger.i('Сессия онлайн, хэндшейк ок');
      // #***! автологин токеном
      if (_onReconnectCallback != null) {
        try {
          await _onReconnectCallback!();
        } catch (e) {
          logger.w('Авто-логин при хэндшейке не удался: $e');
        }
      }
      if (_sessionState == SessionState.online) {
        _stateController.add(SessionState.online);
        _handshakeSuccessController.add(info.deviceName ?? 'Unknown');
      }
    } catch (e, st) {
      logger.e('connect: непредвиденная ошибка: $e\n$st');
      if (gen == _connectGen) await _resetStuckConnect(gen);
    } finally {
      // #***! на случай если несколько раз подключиться решили
      if (built != null && !identical(_session, built)) _releaseSession(built);
    }
  }

  // #***! сторож коннекта
  void _armConnectWatchdog(int gen) {
    _connectWatchdog?.cancel();
    _connectWatchdog = Timer(_connectWatchdogTimeout, () {
      if (gen != _connectGen) return;
      if (_sessionState == SessionState.online ||
          _sessionState == SessionState.disconnected) {
        return;
      }
      logger.e(
        'connect: watchdog ${_connectWatchdogTimeout.inSeconds}с — застряли в '
        '${_sessionState.name}, принудительный сброс',
      );
      unawaited(_resetStuckConnect(gen));
    });
  }

  void _cancelConnectWatchdog() {
    _connectWatchdog?.cancel();
    _connectWatchdog = null;
  }

  // #***! принудительный сброс
  Future<void> _resetStuckConnect(int gen) async {
    if (gen != _connectGen) return;
    _connectGen++;
    _cancelConnectWatchdog();
    _cleanup();
    _setSessionState(SessionState.disconnected);
    if (_autoReconnect) _scheduleReconnect();
  }

  Future<void> _handleConnectFailure(
    Object error, {
    required String phase,
  }) async {
    logger.e('$phase: $error');
    _cancelConnectWatchdog();
    if (_sessionState != SessionState.disconnected) {
      _cleanup();
      _setSessionState(SessionState.disconnected);
      _scheduleReconnect();
    }
  }

  // #***! ручное отключение
  /// Отключается без автореконнекта.
  Future<void> disconnect() async {
    _autoReconnect = false;
    _connectGen++;
    _reconnectTimer?.cancel();
    _cleanup();
    _setSessionState(SessionState.disconnected);
  }

  // #***! вернулись с свертывания если оффлайн коннектимся, если онлайн проверяем живость
  void wakeUp() {
    if (!_autoReconnect) return;
    switch (_sessionState) {
      case SessionState.disconnected:
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        unawaited(connect());
      case SessionState.connecting:
      case SessionState.connected:
        _reconnectAttempts = 0;
      case SessionState.online:
        unawaited(_probeLiveness());
    }
  }

  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError('Нет соединения (${Opcode.name(opcode)})');
    }

    final KolibriResponse resp = await session
        .requestMapFull(opcode, Map<String, dynamic>.from(payload))
        .timeout(
          ServerConfig.requestTimeout,
          onTimeout: () =>
              throw TimeoutException('${Opcode.name(opcode)} таймаут'),
        );

    final packet = Packet(
      cmd: resp.cmd,
      opcode: resp.opcode,
      payload: resp.payload,
    );

    // #***! единственное место где протухший токен уезжает в sessionExpiredStream
    if (packet.isError) {
      if (isSessionExpiredPayload(packet.payload)) {
        final ex = SessionExpiredException(
          messageFromErrorPayload(packet.payload),
        );
        _sessionExpiredController.add(ex);
        throw ex;
      }
      final text = _serverErrorText(packet.payload);
      if (text != null && !silent) _errorController.add(text);
      final err = PacketError(
        messageFromErrorPayload(packet.payload),
        errorKey: resp.errorKey,
      );
      throw err;
    }
    return packet;
  }

  Future<Map<dynamic, dynamic>?> sendRequestMap(
    int opcode,
    Map<dynamic, dynamic> payload,
  ) async {
    final response = await sendRequest(opcode, payload);
    if (!response.isOk || response.payload is! Map) return null;
    return response.payload as Map<dynamic, dynamic>;
  }

  Future<bool> sendRequestOk(int opcode, Map<dynamic, dynamic> payload) async {
    final response = await sendRequest(opcode, payload);
    return response.isOk;
  }

  Future<Packet> sendRequestOrThrow(
    int opcode,
    Map<dynamic, dynamic> payload,
  ) async {
    final response = await sendRequest(opcode, payload);
    throwIfPacketError(response);
    return response;
  }

  // #***! модули бэкенда подписываются на свои пуши
  /// Вешается😘 обработчик на пуши с указанным опкодом
  void registerPushHandler(int opcode, void Function(Packet) handler) {
    _dispatcher.registerHandler(opcode, handler);
  }

  /// Снимает обработчик пушей с опкода
  void unregisterPushHandler(int opcode) {
    _dispatcher.unregisterHandler(opcode);
  }

  /// Стрим всех входящих пушей
  Stream<Packet> get pushStream => _dispatcher.pushStream;

  // #***! закрытие всего
  Future<void> dispose() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _cleanup();
    _dispatcher.dispose();
    await _stateController.close();
    await _sessionExpiredController.close();
    await _handshakeSuccessController.close();
    await _errorController.close();
  }

  // Внутрянка

  // #***! сборка полей устройства для хэндшейка и создание сессии ядра. СПУФ <------
  Future<(KolibriSession, Stream<WireLogEvent>)> _buildSessionOptions(
    ({String host, int port, bool trustMincifryCa, bool trustKnownAvTls})
    endpoint,
  ) async {
    final device = await DeviceProfile.load();

    String deviceType = 'ANDROID';
    String osVersion = device.osVersion;
    String deviceName = device.deviceName;
    String architecture = SpoofingService.defaultArchitecture;
    String appVersion = SpoofingService.hardcodedAppVersion;
    int buildNumber = SpoofingService.hardcodedBuildNumber;
    String screen = '420dpi 420dpi 1080x2340';

    // #***! таймзона инициалализацириуется один раз
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      _tzInitialized = true;
    }
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    String timezone = timeZoneName.identifier;
    String locale = defaultLanguageCode;
    String deviceLocale = deviceLanguageCode();
    String deviceId = await DeviceIdentity.deviceId();
    String pushDeviceType = 'GCM';
    String instanceId = await DeviceIdentity.instanceId();
    int clientSessionId = DeviceIdentity.clientSessionId;

    final androidManufacturer = device.manufacturer;
    final androidModel = device.model;
    final androidSdkInt = device.sdkInt;

    String? spoofUserAgent;
    // #***! включена подмена, накрываем реальные значения спуфом
    final spoofed = await SpoofingService.getSpoofedSessionData(
      scope: spoofScope,
    );
    if (spoofed != null) {
      spoofUserAgent = spoofed['user_agent'] as String?;
      final sDeviceType = spoofed['device_type'] as String?;
      if (sDeviceType != null && sDeviceType != 'IOS') deviceType = sDeviceType;
      final sDeviceName = spoofed['device_name'] as String?;
      if (sDeviceName != null && sDeviceName.isNotEmpty) {
        deviceName = sDeviceName;
      }
      final sOsVersion = spoofed['os_version'] as String?;
      if (sOsVersion != null && sOsVersion.isNotEmpty) osVersion = sOsVersion;
      final sScreen = spoofed['screen'] as String?;
      if (sScreen != null && sScreen.isNotEmpty) screen = sScreen;
      final sTimezone = spoofed['timezone'] as String?;
      if (sTimezone != null && sTimezone.isNotEmpty) timezone = sTimezone;
      final sLocale = spoofed['locale'] as String?;
      if (sLocale != null && sLocale.isNotEmpty) {
        locale = sLocale;
        deviceLocale = sLocale.split(RegExp(r'[-_]')).first;
      }
      final sDeviceLocale = spoofed['device_locale'] as String?;
      if (sDeviceLocale != null && sDeviceLocale.isNotEmpty) {
        deviceLocale = sDeviceLocale;
      }
      final sDeviceId = spoofed['device_id'] as String?;
      if (sDeviceId != null && sDeviceId.isNotEmpty) deviceId = sDeviceId;
      appVersion = (spoofed['app_version'] as String?) ?? appVersion;
      architecture = (spoofed['arch'] as String?) ?? architecture;
      final sBuild = spoofed['build_number'];
      if (sBuild is int) {
        buildNumber = sBuild;
      } else if (sBuild is String) {
        buildNumber = int.tryParse(sBuild) ?? buildNumber;
      }
      final sPushType = spoofed['push_device_type'] as String?;
      if (sPushType != null && sPushType.isNotEmpty) pushDeviceType = sPushType;
      final sInstanceId = spoofed['instance_id'] as String?;
      if (sInstanceId != null && sInstanceId.isNotEmpty) {
        instanceId = sInstanceId;
      }
      final sClientSession = spoofed['client_session_id'];
      if (sClientSession is int) clientSessionId = sClientSession;
    }

    // #***! звонкам нужен формат производитель/модель и номер SDK
    _callsDevice = _resolveCallsDevice(
      spoofed: spoofed != null,
      deviceName: deviceName,
      spoofUserAgent: spoofUserAgent,
      manufacturer: androidManufacturer,
      model: androidModel,
    );
    _callsOsVersion = _resolveCallsOsVersion(
      spoofed: spoofed != null,
      osVersion: osVersion,
      sdkInt: androidSdkInt,
    );

    // #***! то же самое мапом для отладочного экрана
    _userAgent = {
      'deviceType': deviceType,
      'appVersion': appVersion,
      'osVersion': osVersion,
      'timezone': timezone,
      'screen': screen,
      'pushDeviceType': pushDeviceType,
      'arch': architecture,
      'locale': locale,
      'buildNumber': buildNumber,
      'deviceName': deviceName,
      'deviceLocale': deviceLocale,
    };
    _deviceId = deviceId;

    final insecureTls = await TlsConfig.isInsecureAllowed();
    final proxy = await _buildProxyUrl();

    // #***! тут реально открывается сокет в расте
    return openSessionWithWireLog(
      host: endpoint.host,
      port: endpoint.port,
      deviceId: deviceId,
      instanceId: instanceId,
      appVersion: appVersion,
      buildNumber: buildNumber,
      deviceType: deviceType,
      osVersion: osVersion,
      timezone: timezone,
      screen: screen,
      pushDeviceType: pushDeviceType,
      arch: architecture,
      locale: locale,
      deviceName: deviceName,
      deviceLocale: deviceLocale,
      clientSessionId: clientSessionId,
      pingIntervalSecs: ServerConfig.pingInterval.inSeconds,
      pingInteractive: !KometSettings.ghostMode.value,
      autoReconnect: false,
      insecureTls: insecureTls,
      proxy: proxy,
    );
  }

  // #***! звонкам нужен вид Samsung/SM-G991B, при спуфе собираем из подменённого
  static String? _resolveCallsDevice({
    required bool spoofed,
    required String deviceName,
    String? spoofUserAgent,
    String? manufacturer,
    String? model,
  }) {
    if (!spoofed &&
        manufacturer != null &&
        manufacturer.isNotEmpty &&
        model != null &&
        model.isNotEmpty) {
      return '$manufacturer/$model';
    }
    final parts = deviceName.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return null;
    final fallbackModel = parts.length > 1
        ? parts.sublist(1).join(' ')
        : parts.first;
    return '${parts.first}/'
        '${_modelFromUserAgent(spoofUserAgent) ?? fallbackModel}';
  }

  // #***! модель телефона выдираем из юзерагента регуляркой
  static String? _modelFromUserAgent(String? userAgent) {
    if (userAgent == null || userAgent.isEmpty) return null;
    final match = RegExp(r'Android\s+[\d.]+;\s*([^;)]+)').firstMatch(userAgent);
    final model = match
        ?.group(1)
        ?.replaceFirst(RegExp(r'\s+Build/.*$'), '')
        .trim();
    return model == null || model.isEmpty ? null : model;
  }

  // #***! звонки хотят номер SDK а не Android 14
  static String _resolveCallsOsVersion({
    required bool spoofed,
    required String osVersion,
    int? sdkInt,
  }) {
    if (!spoofed && sdkInt != null && sdkInt > 0) return '$sdkInt';
    final release = RegExp(
      r'^Android\s+(\d+)',
    ).firstMatch(osVersion.trim())?.group(1);
    return '${_androidSdkForRelease(int.tryParse(release ?? ''))}';
  }

  // #***! таблица релиз -> уровень API
  static int _androidSdkForRelease(int? release) => switch (release) {
    null => 34,
    <= 9 => 28,
    10 => 29,
    11 => 30,
    12 => 31,
    13 => 33,
    14 => 34,
    15 => 35,
    _ => 36,
  };

  // #***! прокси в строку socks5h://user:pass@host:port
  static Future<String?> _buildProxyUrl() async {
    final p = await ProxyConfig.load();
    if (!p.isEnabled) return null;
    final scheme = p.type == ProxyType.socks5 ? 'socks5h' : 'http';
    final auth = p.hasCredentials
        ? '${Uri.encodeComponent(p.username!)}:'
              '${Uri.encodeComponent(p.password!)}@'
        : '';
    return '$scheme://$auth${p.host}:${p.port}';
  }

  // #***! пуш из ядра заворачиваем в Packet и в диспетчер
  void _onPush((int, Map<String, dynamic>) event) {
    final packet = Packet(
      cmd: CmdType.push,
      opcode: event.$1,
      payload: event.$2,
    );
    // Учёт трафика пушей ведётся из wire-лога ядра (_onWireLog).
    _dispatcher.dispatch(packet);
  }

  // #***! весь лог трафика отсюда, ядро отдаёт обе стороны с настоящим seq
  /// Единый источник лога трафика: ядро отдаёт сюда каждый пакет обеих сторон —
  /// включая SESSION_INIT-хендшейк и пинги — с настоящим проводным seq. Раньше
  /// лог вёлся вручную из [sendRequest] по локальному счётчику, из-за чего
  /// хендшейк/пинги в дамп не попадали, а seq был смещён относительно провода.
  void _onWireLog(WireLogEvent e) {
    // #***! в фоне и без монитора не тратим время на разбор
    if (!AppForeground.value && !TrafficMonitor.instance.enabled) return;
    final payload = _decodeWireJson(e.json);
    final cmd = _wireCmdCode(e.cmd);
    if (e.direction == 'out') {
      if (KometSettings.recordDebugLogs.value) {
        DebugSessionLog.instance.recordRequest(e.opcode, e.seq, payload);
      }
      TrafficMonitor.instance.recordOutgoing(e.opcode, payload, e.seq, 0);
      return;
    }
    // Входящие: ответы матчатся по seq, пуши идут только в монитор трафика.
    if (e.cmd != 'push' && KometSettings.recordDebugLogs.value) {
      DebugSessionLog.instance.recordResponse(e.seq, cmd, payload);
    }
    TrafficMonitor.instance.recordIncoming(
      Packet(cmd: cmd, seq: e.seq, opcode: e.opcode, payload: payload),
      0,
    );
  }

  static int _wireCmdCode(String cmd) {
    switch (cmd) {
      case 'ok':
        return CmdType.ok;
      case 'not_found':
        return CmdType.notFound;
      case 'error':
        return CmdType.error;
      default:
        return CmdType.request; // 'request' и 'push'
    }
  }

  static dynamic _decodeWireJson(String json) {
    try {
      return jsonDecode(json);
    } catch (_) {
      return json;
    }
  }

  // #***! смена состояния с оповещением
  void _setSessionState(SessionState state) {
    if (_sessionState == state) return;
    _sessionState = state;
    _stateController.add(state);
    logger.i('Сессия: ${state.name}');
  }

  // #***! разрыв, чистимся и планируем реконнект
  void _onDisconnected() {
    _connectGen++;
    _cleanup();
    _setSessionState(SessionState.disconnected);
    if (_autoReconnect) _scheduleReconnect();
  }

  // #***! проверка живости настоящим пингом
  /// Пробный запрос-пинг: если не ответил — форсируем реконнект.
  Future<void> _probeLiveness() async {
    if (_sessionState != SessionState.online) return;
    final session = _session;
    if (session == null) return;
    final epoch = _sessionEpoch;
    try {
      await session
          .requestMapFull(Opcode.ping, {
            'interactive': !KometSettings.ghostMode.value,
          })
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      if (_sessionEpoch != epoch || _sessionState != SessionState.online) {
        return;
      }
      logger.w('Пробный пинг не прошёл — принудительный реконнект');
      await _forceReconnect();
    }
  }

  // #***! реконнект прямо сейчас, знаем что связь мертва
  Future<void> _forceReconnect() async {
    _connectGen++;
    _cleanup();
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _setSessionState(SessionState.disconnected);
    if (_autoReconnect) unawaited(connect());
  }

  // #***! общая уборка, таймеры подписки сессия
  void _cleanup() {
    _cancelConnectWatchdog();
    _livenessTimer?.cancel();
    _livenessTimer = null;
    _pushSub?.cancel();
    _pushSub = null;
    _wireLogSub?.cancel();
    _wireLogSub = null;
    _lastInteractive = null;
    final session = _session;
    _session = null;
    if (session != null) _releaseSession(session);
    _dispatcher.clearPending();
    _handshakeSuccessController.add('disconnected');
  }

  // #***! раст освобождаем руками, иначе рантаймы копятся всю ночь
  /// Рвёт соединение и сразу освобождает Rust-объект: иначе tokio-рантайм
  /// сессии (поток на ядро) живёт до сборки мусора Dart, а в фоне она может не
  /// случиться часами — за ночь реконнектов набегает десяток живых рантаймов.
  static void _releaseSession(KolibriSession session) {
    if (session.isDisposed) return;
    try {
      session.disconnect();
    } catch (_) {}
    try {
      session.dispose();
    } catch (_) {}
  }

  Future<void> reconnectAndLogin() async {
    await connect();
  }

  // #***! колбэк автологина ставит аккаунт, api про токены не знает
  Future<void> Function()? _onReconnectCallback;

  void setReconnectCallback(Future<void> Function() callback) {
    _onReconnectCallback = callback;
  }

  // #***! у ядра нет стрима состояний, опрашиваем сами раз в 5 сек
  /// Поллит состояние ядра (стрима состояний нет) — детект разрыва, плюс
  /// синхронизация interactive-флага пинга и присутствия.
  void _startLiveness() {
    _livenessTimer?.cancel();
    _lastInteractive = !KometSettings.ghostMode.value;
    _livenessTimer = Timer.periodic(_livenessInterval, (_) => _tickLiveness());
  }

  // #***! заодно синхроним невидимку
  void _tickLiveness() {
    final session = _session;
    if (session == null || _sessionState != SessionState.online) return;
    final st = session.state();
    if (st != 'online' && st != 'connected') {
      logger.w('kolibri сессия "$st" — реконнект');
      _onDisconnected();
      return;
    }
    final interactive = !KometSettings.ghostMode.value;
    if (interactive != _lastInteractive) {
      _lastInteractive = interactive;
      try {
        session.setPingInteractive(interactive: interactive);
      } catch (_) {}
    }
    if (interactive) {
      SelfPresence.markOnline();
    } else {
      SelfPresence.markOfflineFromPing();
    }
  }

  // #***! ручная смена невидимки из настроек
  void sendPing({required bool interactive}) {
    final session = _session;
    if (session != null && _sessionState == SessionState.online) {
      try {
        session.setPingInteractive(interactive: interactive);
      } catch (_) {}
      _lastInteractive = interactive;
      if (interactive) {
        SelfPresence.markOnline();
      } else {
        SelfPresence.markOfflineFromPing();
      }
    }
  }

  // #***! текст ошибки который не стыдно показать
  static String? _serverErrorText(dynamic payload) {
    if (payload is! Map) return null;
    for (final key in ['localizedMessage', 'title']) {
      final v = payload[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  // #***! сервер шлёт свой список стран, он важнее нашего
  static List<CountryName>? _parseRegistrationCountries(dynamic payload) {
    if (payload is! Map) return null;
    final raw = payload['reg-country-code'];
    if (raw is! List || raw.isEmpty) return null;
    final codes = <String>[];
    for (final e in raw) {
      if (e is String && e.isNotEmpty) codes.add(e.toUpperCase());
    }
    if (codes.isEmpty) return null;
    var list = countriesInServerOrder(codes);
    if (list.isEmpty) return null;

    // #***! страну по геолокации наверх списка
    final loc = payload['location'];
    if (loc is String && loc.length == 2) {
      final home = countriesByCode[loc.toUpperCase()];
      if (home != null && !list.any((c) => c.code == home.code)) {
        list = [home, ...list];
      }
    }
    return list;
  }

  // #***! задержка реконнекта 2 4 8, в фоне потолок выше чтоб батарею не жрать
  void _scheduleReconnect() {
    final capSec = AppForeground.value
        ? _foregroundReconnectCapSec
        : _backgroundReconnectCapSec;
    final delaySec = (2 * (1 << _reconnectAttempts.clamp(0, 6))).clamp(
      2,
      capSec,
    );
    _reconnectAttempts++;
    logger.i('Реконнект через $delaySecс (попытка $_reconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySec), connect);
  }
}

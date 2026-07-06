import 'dart:async';
import 'dart:typed_data';

import '../core/cache/self_presence.dart';
import '../core/config/config.dart';
import '../core/config/countries.dart';
import '../core/config/komet_settings.dart';
import '../core/protocol/opcode_map.dart';
import '../core/protocol/packet.dart';
import '../core/storage/device_identity.dart';
import '../core/storage/spoofing_service.dart';
import '../core/transport/connection.dart';
import '../core/transport/dispatcher.dart';
import '../core/transport/receiver.dart';
import '../core/transport/sender.dart';
import '../core/transport/traffic_monitor.dart';
import '../core/transport/vpn_bypass.dart';
import '../core/utils/debug_session_log.dart';
import '../core/utils/logger.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:io';

enum SessionState { disconnected, connecting, connected, online }

/// Клиент API.
///
/// Подключение, хэндшейк, пинг, реконнект.
class Api {
  final Connection _connection = Connection();
  final PacketReceiver _receiver = PacketReceiver();
  final PacketSender _sender = PacketSender();
  final PacketDispatcher _dispatcher = PacketDispatcher();

  SessionState _sessionState = SessionState.disconnected;
  final _stateController = StreamController<SessionState>.broadcast();
  final _sessionExpiredController =
      StreamController<SessionExpiredException>.broadcast();
  final _handshakeSuccessController = StreamController<String>.broadcast();
  Map<dynamic, dynamic>? _userAgent;

  Map<dynamic, dynamic>? get userAgent => _userAgent;

  int? _callsSeed;
  String? _deviceId;

  int? get callsSeed => _callsSeed;
  String? get deviceId => _deviceId;

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
  Stream<String> get errorStream => _dispatcher.errorStream;
  SessionState get state => _sessionState;

  StreamSubscription<Uint8List>? _dataSubscription;
  StreamSubscription<SocketState>? _socketStateSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Timer? _connectWatchdog;
  int _connectGen = 0;
  int _reconnectAttempts = 0;
  bool _autoReconnect = false;
  int _sessionEpoch = 0;

  static const Duration _connectWatchdogTimeout = Duration(seconds: 75);
  static const Duration _shouldArmTimeout = Duration(seconds: 5);
  static const Duration _endpointTimeout = Duration(seconds: 5);

  int get sessionEpoch => _sessionEpoch;

  /// Залипает на время сессии: VPN-путь не сработал — идём мимо туннеля.
  bool _bypassActive = false;

  // Публичное API

  /// Подключается к серверу, шлёт хэндшейк, запускает пинг.
  Future<void> connect() async {
    if (_sessionState != SessionState.disconnected) {
      logger.i('connect пропущен: состояние ${_sessionState.name}');
      return;
    }
    _autoReconnect = true;
    final gen = ++_connectGen;
    _setSessionState(SessionState.connecting);
    logger.i('connect: старт (поколение $gen)');
    _armConnectWatchdog(gen);

    try {
      _dataSubscription = _connection.dataStream.listen(_onDataReceived);
      _socketStateSubscription = _connection.stateStream.listen((socketState) {
        if (socketState == SocketState.disconnected &&
            _sessionState != SessionState.disconnected) {
          _onDisconnected();
        }
      });

      bool bypassArmed;
      try {
        bypassArmed = await VpnBypassService.instance.shouldArm().timeout(
          _shouldArmTimeout,
        );
      } catch (e) {
        logger.w('connect: shouldArm завис/упал ($e) — без обхода VPN');
        bypassArmed = false;
      }
      if (gen != _connectGen) return;

      if (!bypassArmed) _bypassActive = false;
      final useBypass = _bypassActive && bypassArmed;
      final attemptTimeout = bypassArmed && !useBypass
          ? const Duration(seconds: 8)
          : null;

      ({String host, int port}) endpoint;
      try {
        endpoint = await ServerConfig.loadEndpoint().timeout(_endpointTimeout);
      } catch (e) {
        logger.w('connect: loadEndpoint завис/упал ($e) — дефолтный endpoint');
        endpoint = (
          host: ServerConfig.defaultHost,
          port: ServerConfig.defaultPort,
        );
      }
      if (gen != _connectGen) return;

      logger.i(
        'connect: endpoint ${endpoint.host}:${endpoint.port}, bypass=$useBypass',
      );
      try {
        await _connection.connect(
          endpoint.host,
          endpoint.port,
          bypassVpn: useBypass,
          timeout: attemptTimeout,
        );
      } catch (e) {
        if (gen != _connectGen) return;
        await _handleConnectFailure(
          e,
          phase: 'Не удалось подключиться',
          bypassArmed: bypassArmed,
          useBypass: useBypass,
          bypassWhy: 'подключение не удалось',
        );
        return;
      }
      if (gen != _connectGen) return;

      _setSessionState(SessionState.connected);
      _reconnectAttempts = 0;

      try {
        logger.i('connect: сокет готов, отправляю хэндшейк');
        final response = await sendHandshake();
        if (gen != _connectGen) return;
        if (response.isOk) {
          _callsSeed = response.payload['callsSeed'] as int?;
          _registrationCountries = _parseRegistrationCountries(
            response.payload,
          );
          _sessionState = SessionState.online;
          _sessionEpoch++;
          _cancelConnectWatchdog();
          _startPinging();
          logger.i('Сессия онлайн, хэндшейк ок');
          if (_onReconnectCallback != null) {
            try {
              await _onReconnectCallback!();
            } catch (e) {
              logger.w('Авто-логин при хэндшейке не удался: $e');
            }
          }
          if (_sessionState == SessionState.online) {
            _stateController.add(SessionState.online);
            _handshakeSuccessController.add(
              response.payload['device_name'] as String? ?? 'Unknown',
            );
          }
        } else {
          logger.e('Хэндшейк отклонён: ${response.payload}');
          await _handleConnectFailure(
            StateError('хэндшейк отклонён сервером'),
            phase: 'Хэндшейк отклонён',
            bypassArmed: bypassArmed,
            useBypass: useBypass,
            bypassWhy: 'хэндшейк отклонён',
            disconnectSocket: true,
          );
        }
      } catch (e) {
        if (gen != _connectGen) return;
        await _handleConnectFailure(
          e,
          phase: 'Ошибка хэндшейка',
          bypassArmed: bypassArmed,
          useBypass: useBypass,
          bypassWhy: 'хэндшейк не прошёл',
          disconnectSocket: true,
        );
      }
    } catch (e, st) {
      logger.e('connect: непредвиденная ошибка: $e\n$st');
      if (gen == _connectGen) await _resetStuckConnect(gen);
    }
  }

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

  Future<void> _resetStuckConnect(int gen) async {
    if (gen != _connectGen) return;
    _connectGen++;
    _cancelConnectWatchdog();
    _cleanup();
    try {
      await _connection.disconnect();
    } catch (_) {}
    _setSessionState(SessionState.disconnected);
    if (_autoReconnect) _scheduleReconnect();
  }

  Future<void> _handleConnectFailure(
    Object error, {
    required String phase,
    required bool bypassArmed,
    required bool useBypass,
    required String bypassWhy,
    bool disconnectSocket = false,
  }) async {
    logger.e('$phase: $error');
    _cancelConnectWatchdog();
    if (_sessionState != SessionState.disconnected) {
      _cleanup();
      if (disconnectSocket) await _connection.disconnect();
      _setSessionState(SessionState.disconnected);
      _armBypassIfPossible(bypassArmed, useBypass, bypassWhy);
      _scheduleReconnect();
    }
  }

  void _armBypassIfPossible(bool armed, bool alreadyBypassing, String why) {
    if (armed && !alreadyBypassing && !_bypassActive) {
      _bypassActive = true;
      logger.w('VPN bypass: $why — следующая попытка мимо VPN');
    }
  }

  /// Отключается без автореконнекта.
  Future<void> disconnect() async {
    _autoReconnect = false;
    _bypassActive = false;
    _connectGen++;
    _reconnectTimer?.cancel();
    _cleanup();
    await _connection.disconnect();
    _setSessionState(SessionState.disconnected);
  }

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

  Future<Packet> sendHandshake() async {
    final deviceInfo = DeviceInfoPlugin();

    String deviceType = 'ANDROID';
    String osVersion = '';
    String deviceName = 'Unknown';
    String architecture = 'arm64';
    String appVersion = SpoofingService.hardcodedAppVersion;
    int buildNumber = SpoofingService.hardcodedBuildNumber;
    String screen = '420dpi 420dpi 1080x2340';

    if (!_tzInitialized) {
      tz.initializeTimeZones();
      _tzInitialized = true;
    }
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    String timezone = timeZoneName.identifier;
    String locale = 'ru';
    String deviceLocale = Platform.localeName.substring(0, 2);
    String deviceId = await DeviceIdentity.deviceId();
    String pushDeviceType = 'GCM';
    String instanceId = await DeviceIdentity.instanceId();
    int clientSessionId = DeviceIdentity.clientSessionId;

    if (Platform.isLinux) {
      final linuxInfo = await deviceInfo.linuxInfo;
      osVersion = linuxInfo.name;
      architecture = _archFromPlatformVersion();
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      osVersion = iosInfo.systemVersion;
      deviceName = iosInfo.utsname.machine;
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      osVersion = 'Android ${androidInfo.version.release}';
      deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      architecture = androidInfo.supportedAbis.first;
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      osVersion = windowsInfo.productName;
      architecture = _archFromPlatformVersion();
    }

    final spoofed = await SpoofingService.getSpoofedSessionData(
      scope: spoofScope,
    );
    if (spoofed != null) {
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

    final payload = <dynamic, dynamic>{
      'mt_instanceid': instanceId,
      'userAgent': _userAgent,
      'clientSessionId': clientSessionId,
      'deviceId': deviceId,
    };

    return sendRequest(Opcode.sessionInit, payload);
  }

  /// Отправляет запрос и ждёт ответ от сервера.
  Future<Packet> sendRequest(int opcode, Map<dynamic, dynamic> payload) {
    final seq = _sender.send(_connection, opcode, payload);
    DebugSessionLog.instance.recordRequest(opcode, seq, payload);
    return _dispatcher
        .registerPending(seq)
        .timeout(
          ServerConfig.requestTimeout,
          onTimeout: () =>
              throw TimeoutException('${Opcode.name(opcode)} таймаут'),
        )
        .then(
          (packet) {
            DebugSessionLog.instance.recordResponse(
              seq,
              packet.cmd,
              packet.payload,
            );
            return packet;
          },
          onError: (Object e, StackTrace st) {
            DebugSessionLog.instance.recordError(seq, e);
            Error.throwWithStackTrace(e, st);
          },
        );
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

  /// Вешает обработчик на пуши с указанным опкодом.
  void registerPushHandler(int opcode, void Function(Packet) handler) {
    _dispatcher.registerHandler(opcode, handler);
  }

  /// Снимает обработчик пушей с указанного опкода.
  void unregisterPushHandler(int opcode) {
    _dispatcher.unregisterHandler(opcode);
  }

  /// Стрим всех входящих пушей от сервера.
  Stream<Packet> get pushStream => _dispatcher.pushStream;

  Future<void> dispose() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _cleanup();
    _dispatcher.dispose();
    await _connection.dispose();
    await _stateController.close();
    await _sessionExpiredController.close();
    await _handshakeSuccessController.close();
  }

  // Внутрянка

  void _setSessionState(SessionState state) {
    if (_sessionState == state) return;
    _sessionState = state;
    _stateController.add(state);
    logger.i('Сессия: ${state.name}');
  }

  Future<void> _onDataReceived(Uint8List data) async {
    final List<Uint8List> rawPackets;
    try {
      rawPackets = _receiver.feed(data);
    } on ReceiverOverflowException catch (e) {
      logger.e('$e — форсируем реконнект');
      if (_sessionState != SessionState.disconnected) {
        unawaited(_forceReconnect());
      }
      return;
    }
    for (final raw in rawPackets) {
      final Packet packet;
      try {
        packet = await unpackPacket(raw);
      } catch (e) {
        logger.e('PacketReceiver: ошибка распаковки: $e');
        continue;
      }
      TrafficMonitor.instance.recordIncoming(packet, raw.length);
      if (packet.isError && isSessionExpiredPayload(packet.payload)) {
        _sessionExpiredController.add(
          SessionExpiredException(messageFromErrorPayload(packet.payload)),
        );
      }
      _dispatcher.dispatch(packet);
    }
  }

  void _onDisconnected() {
    _connectGen++;
    _cleanup();
    _setSessionState(SessionState.disconnected);
    if (_autoReconnect) _scheduleReconnect();
  }

  Future<void> _probeLiveness() async {
    if (_sessionState != SessionState.online) return;
    final epoch = _sessionEpoch;
    try {
      await sendRequest(Opcode.ping, {
        'interactive': !KometSettings.ghostMode.value,
      }).timeout(const Duration(seconds: 6));
    } catch (_) {
      if (_sessionEpoch != epoch || _sessionState != SessionState.online) {
        return;
      }
      logger.w('Пробный пинг не прошёл — принудительный реконнект');
      await _forceReconnect();
    }
  }

  Future<void> _forceReconnect() async {
    _connectGen++;
    _cleanup();
    await _connection.disconnect();
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _setSessionState(SessionState.disconnected);
    if (_autoReconnect) unawaited(connect());
  }

  void _cleanup() {
    _cancelConnectWatchdog();
    _pingTimer?.cancel();
    _dataSubscription?.cancel();
    _socketStateSubscription?.cancel();
    _dataSubscription = null;
    _socketStateSubscription = null;
    _receiver.reset();
    _dispatcher.clearPending();
    _handshakeSuccessController.add('disconnected');
  }

  Future<void> reconnectAndLogin() async {
    await connect();
  }

  Future<void> Function()? _onReconnectCallback;

  void setReconnectCallback(Future<void> Function() callback) {
    _onReconnectCallback = callback;
  }

  void _startPinging() {
    _pingTimer?.cancel();
    sendPing(interactive: !KometSettings.ghostMode.value);
    _pingTimer = Timer.periodic(ServerConfig.pingInterval, (_) {
      sendPing(interactive: !KometSettings.ghostMode.value);
    });
  }

  void sendPing({required bool interactive}) {
    if (_connection.isConnected) {
      _sender.send(_connection, Opcode.ping, {'interactive': interactive});
      if (interactive) {
        SelfPresence.markOnline();
      } else {
        SelfPresence.markOfflineFromPing();
      }
    }
  }

  static String _archFromPlatformVersion() {
    final v = Platform.version;
    return v.substring(v.indexOf('_') + 1, v.length - 1);
  }

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

    final loc = payload['location'];
    if (loc is String && loc.length == 2) {
      final home = countriesByCode[loc.toUpperCase()];
      if (home != null && !list.any((c) => c.code == home.code)) {
        list = [home, ...list];
      }
    }
    return list;
  }

  void _scheduleReconnect() {
    final delaySec = (2 * (1 << _reconnectAttempts.clamp(0, 3))).clamp(2, 15);
    _reconnectAttempts++;
    logger.i('Реконнект через $delaySecс (попытка $_reconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySec), connect);
  }
}

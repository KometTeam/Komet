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
  int _reconnectAttempts = 0;
  bool _autoReconnect = false;
  int _sessionEpoch = 0;

  int get sessionEpoch => _sessionEpoch;

  /// Залипает на время сессии: VPN-путь не сработал — идём мимо туннеля.
  bool _bypassActive = false;

  // Публичное API

  /// Подключается к серверу, шлёт хэндшейк, запускает пинг.
  Future<void> connect() async {
    if (_sessionState != SessionState.disconnected) return;
    // Ставим автоматический реконнект и статус подключения
    _autoReconnect = true;
    _setSessionState(SessionState.connecting);

    _dataSubscription = _connection.dataStream.listen(_onDataReceived);
    _socketStateSubscription = _connection.stateStream.listen((socketState) {
      if (socketState == SocketState.disconnected &&
          _sessionState != SessionState.disconnected) {
        _onDisconnected();
      }
    });

    final bypassArmed = await VpnBypassService.instance.shouldArm();
    if (!bypassArmed) _bypassActive = false;
    final useBypass = _bypassActive && bypassArmed;
    // Попытку через VPN ограничиваем по времени, чтобы быстро понять,
    // что туннель не пропускает, и переключиться на обход.
    final attemptTimeout =
        bypassArmed && !useBypass ? const Duration(seconds: 8) : null;

    try {
      final endpoint = await ServerConfig.loadEndpoint();
      await _connection.connect(
        endpoint.host,
        endpoint.port,
        bypassVpn: useBypass,
        timeout: attemptTimeout,
      );
    } catch (e) {
      logger.e('Не удалось подключиться: $e');
      if (_sessionState != SessionState.disconnected) {
        _cleanup();
        _setSessionState(SessionState.disconnected);
        _armBypassIfPossible(bypassArmed, useBypass, 'подключение не удалось');
        _scheduleReconnect();
      }
      return;
    }

    _setSessionState(SessionState.connected);
    _reconnectAttempts = 0;

    try {
      final response = await sendHandshake();
      if (response.isOk) {
        _callsSeed = response.payload['callsSeed'] as int?;
        _registrationCountries = _parseRegistrationCountries(response.payload);
        _sessionState = SessionState.online;
        _sessionEpoch++;
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
      }
    } catch (e) {
      logger.e('Ошибка хэндшейка: $e');
      // Сокет подключился (через VPN), но сервер не ответил на хэндшейк —
      // путь нерабочий: рвём соединение и пробуем мимо VPN.
      if (_sessionState != SessionState.disconnected) {
        _cleanup();
        await _connection.disconnect();
        _setSessionState(SessionState.disconnected);
        _armBypassIfPossible(bypassArmed, useBypass, 'хэндшейк не прошёл');
        _scheduleReconnect();
      }
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
    _reconnectTimer?.cancel();
    _cleanup();
    await _connection.disconnect();
    _setSessionState(SessionState.disconnected);
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

    tz.initializeTimeZones();
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
      architecture = Platform.version.substring(
        Platform.version.indexOf('_') + 1,
        Platform.version.length - 1,
      );
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
      architecture = Platform.version.substring(
        Platform.version.indexOf('_') + 1,
        Platform.version.length - 1,
      );
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
    final rawPackets = _receiver.feed(data);
    for (final raw in rawPackets) {
      final Packet packet;
      try {
        packet = await unpackPacket(raw);
      } catch (e) {
        logger.e('PacketReceiver: ошибка распаковки: $e');
        continue;
      }
      TrafficMonitor.instance.recordIncoming(packet, raw.length);
      if (packet.isError &&
          packet.payload is Map &&
          (packet.payload['message'] == 'FAIL_LOGIN_TOKEN' ||
              packet.payload['message'] == 'FAIL_WRONG_PASSWORD')) {
        _sessionExpiredController.add(
          SessionExpiredException(messageFromErrorPayload(packet.payload)),
        );
      }
      _dispatcher.dispatch(packet);
    }
  }

  void _onDisconnected() {
    _cleanup();
    _setSessionState(SessionState.disconnected);
    if (_autoReconnect) _scheduleReconnect();
  }

  void _cleanup() {
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
    if (_reconnectAttempts >= ServerConfig.maxReconnectAttempts) {
      logger.e('Лимит попыток реконнекта');
      return;
    }

    final delaySec = (2 * (1 << _reconnectAttempts)).clamp(2, 30);
    _reconnectAttempts++;
    logger.i('Реконнект через $delaySecс (попытка $_reconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySec), connect);
  }
}

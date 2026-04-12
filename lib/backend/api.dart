import 'dart:async';
import 'dart:typed_data';

import '../core/config/config.dart';
import '../core/config/countries.dart';
import '../core/protocol/opcode_map.dart';
import '../core/protocol/packet.dart';
import '../core/storage/spoofing_service.dart';
import '../core/transport/connection.dart';
import '../core/transport/dispatcher.dart';
import '../core/transport/receiver.dart';
import '../core/transport/sender.dart';
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

  List<CountryName>? _registrationCountries;

  List<CountryName> get registrationCountries =>
      _registrationCountries ?? allCountries;

  Stream<SessionState> get stateStream => _stateController.stream;
  Stream<SessionExpiredException> get sessionExpiredStream =>
      _sessionExpiredController.stream;
  Stream<String> get handshakeSuccessStream =>
      _handshakeSuccessController.stream;
  SessionState get state => _sessionState;

  StreamSubscription<Uint8List>? _dataSubscription;
  StreamSubscription<SocketState>? _socketStateSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _autoReconnect = false;

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

    try {
      final endpoint = await ServerConfig.loadEndpoint();
      await _connection.connect(endpoint.host, endpoint.port);
    } catch (e) {
      logger.e('Не удалось подключиться: $e');
      if (_sessionState != SessionState.disconnected) {
        _cleanup();
        _setSessionState(SessionState.disconnected);
        _scheduleReconnect();
      }
      return;
    }

    _setSessionState(SessionState.connected);
    _reconnectAttempts = 0;

    try {
      final response = await sendHandshake();
      if (response.isOk) {
        _registrationCountries = _parseRegistrationCountries(response.payload);
        _setSessionState(SessionState.online);
        _startPinging();
        logger.i('Сессия онлайн, хэндшейк ок');
        _handshakeSuccessController.add(
          response.payload['device_name'] as String? ?? 'Unknown',
        );
        if (_onReconnectCallback != null) {
          _onReconnectCallback!();
        }
      } else {
        logger.e('Хэндшейк отклонён: ${response.payload}');
      }
    } catch (e) {
      logger.e('Ошибка хэндшейка: $e');
    }
  }

  /// Отключается без автореконнекта.
  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _cleanup();
    await _connection.disconnect();
    _setSessionState(SessionState.disconnected);
  }

  Future<Packet> sendHandshake() async {
    final deviceInfo = DeviceInfoPlugin();

    String deviceType = (Platform.isLinux || Platform.isWindows)
        ? 'DESKTOP'
        : (Platform.isAndroid)
        ? 'ANDROID'
        : 'IOS';
    String osVersion = '';
    String deviceName = 'Unknown';
    String architecture = 'arm64';
    String appVersion = SpoofingService.hardcodedAppVersion;
    int buildNumber = SpoofingService.hardcodedBuildNumber;
    String screen = '1920x1080';

    tz.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    String timezone = timeZoneName.identifier;
    String locale = 'ru';
    String deviceLocale = Platform.localeName.substring(0, 2);
    String deviceId = 'a1b2c3d4e5f6a7b8';

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

    final spoofed = await SpoofingService.getSpoofedSessionData();
    if (spoofed != null) {
      deviceType = (spoofed['device_type'] as String?) ?? deviceType;
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
    }

    _userAgent = {
      'deviceType': deviceType,
      'locale': locale,
      'deviceLocale': deviceLocale,
      'osVersion': osVersion,
      'deviceName': deviceName,
      'appVersion': appVersion,
      'screen': screen,
      'timezone': timezone,
      'pushDeviceType': 'GCM',
      'arch': architecture,
      'buildNumber': buildNumber,
    };

    final payload = <dynamic, dynamic>{
      'mt_instanceid': '550e8400-e29b-41d4-a716-446655440000',
      'clientSessionId': 42,
      'deviceId': deviceId,
      'userAgent': _userAgent,
    };

    return sendRequest(Opcode.sessionInit, payload);
  }

  /// Отправляет запрос и ждёт ответ от сервера.
  Future<Packet> sendRequest(int opcode, Map<dynamic, dynamic> payload) {
    final seq = _sender.send(_connection, opcode, payload);
    return _dispatcher
        .registerPending(seq)
        .timeout(
          ServerConfig.requestTimeout,
          onTimeout: () =>
              throw TimeoutException('${Opcode.name(opcode)} таймаут'),
        );
  }

  /// Вешает обработчик на пуши с указанным опкодом.
  void registerPushHandler(int opcode, void Function(Packet) handler) {
    _dispatcher.registerHandler(opcode, handler);
  }

  /// Стрим всех входящих пушей от сервера.
  Stream<Packet> get pushStream => _dispatcher.pushStream;

  void dispose() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _cleanup();
    _dispatcher.dispose();
    _connection.dispose();
    _stateController.close();
    _sessionExpiredController.close();
  }

  // Внутрянка

  void _setSessionState(SessionState state) {
    if (_sessionState == state) return;
    _sessionState = state;
    _stateController.add(state);
    logger.i('Сессия: ${state.name}');
  }

  Future<void> _onDataReceived(Uint8List data) async {
    await for (final packet in _receiver.feed(data)) {
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

  void Function()? _onReconnectCallback;

  void setReconnectCallback(void Function() callback) {
    _onReconnectCallback = callback;
  }

  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(ServerConfig.pingInterval, (_) {
      if (_connection.isConnected) {
        _sender.send(_connection, Opcode.ping, {});
      }
    });
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

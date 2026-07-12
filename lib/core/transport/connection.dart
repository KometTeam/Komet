import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../config/proxy_config.dart';
import '../utils/logger.dart';
import 'proxy_connector.dart';
import 'tls_config.dart';
import 'traffic_monitor.dart';
import 'vpn_bypass.dart';

enum SocketState { disconnected, connecting, connected }

/// Обёртка над TCP + TLS сокетом.
/// Отдаёт сырые байты через [dataStream], сборкой пакетов занимается [PacketReceiver].
class Connection {
  static const Duration _defaultConnectTimeout = Duration(seconds: 15);
  static const Duration _proxyLoadTimeout = Duration(seconds: 8);
  static const Duration _vpnCallTimeout = Duration(seconds: 5);

  SecureSocket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  SocketState _state = SocketState.disconnected;

  final _dataController = StreamController<Uint8List>.broadcast();
  final _stateController = StreamController<SocketState>.broadcast();

  Stream<Uint8List> get dataStream => _dataController.stream;
  Stream<SocketState> get stateStream => _stateController.stream;
  SocketState get state => _state;
  bool get isConnected => _state == SocketState.connected;

  void _setState(SocketState newState) {
    if (_state == newState) return;
    _state = newState;
    if (!_stateController.isClosed) _stateController.add(newState);
  }

  Future<void> connect(
    String host,
    int port, {
    bool bypassVpn = false,
    Duration? timeout,
  }) async {
    if (_state != SocketState.disconnected) {
      logger.w('Connection.connect пропущен: state=$_state (уже $_state)');
      return;
    }
    _setState(SocketState.connecting);

    try {
      logger.i('Connection: загрузка прокси-конфига');
      ProxySettings proxySettings;
      try {
        proxySettings = await ProxyConfig.load().timeout(_proxyLoadTimeout);
      } catch (e) {
        logger.w('Connection: ProxyConfig.load завис/упал ($e) — без прокси');
        proxySettings = const ProxySettings();
      }

      logger.i(
        'Connection: VPN ${bypassVpn ? 'bind (обход)' : 'restoreDefault'}',
      );
      try {
        if (bypassVpn) {
          await VpnBypassService.instance.bind().timeout(_vpnCallTimeout);
        } else {
          await VpnBypassService.instance
              .restoreDefault()
              .timeout(_vpnCallTimeout);
        }
      } catch (e) {
        logger.w('Connection: VPN-вызов завис/упал ($e) — продолжаю');
      }

      logger.i(
        'Connection: открываю сокет $host:$port '
        '(прокси: ${proxySettings.isEnabled ? proxySettings.type.name : 'нет'})',
      );
      final socket = await _openSecureSocket(
        host,
        port,
        proxySettings,
        timeout: timeout,
      );

      _socket = socket;
      _setState(SocketState.connected);
      logger.i('Подключено к $host:$port');

      final route = proxySettings.isEnabled
          ? 'через прокси ${proxySettings.type.name}'
          : bypassVpn
              ? 'напрямую (обход VPN)'
              : 'прямое соединение';
      TrafficMonitor.instance.recordEvent(
        'Подключено',
        detail: '$host:$port · TLS · $route',
        endpoint: '$host:$port',
      );

      _subscription = _socket!.listen(
        (data) {
          if (!_dataController.isClosed) _dataController.add(data);
        },
        onError: (Object error) {
          logger.e('Ошибка сокета: $error');
          disconnect();
        },
        onDone: () {
          logger.w('Сокет закрыт сервером');
          disconnect();
        },
      );
    } catch (e) {
      logger.e('Не удалось подключиться: $e');
      _setState(SocketState.disconnected);
      rethrow;
    }
  }

  Future<SecureSocket> _openSecureSocket(
    String host,
    int port,
    ProxySettings proxySettings, {
    Duration? timeout,
  }) async {
    final connectTimeout = timeout ?? _defaultConnectTimeout;
    Socket socket;
    if (proxySettings.isEnabled) {
      final connector = ProxyConnector(proxySettings);
      socket = await connector.connect(host, port).timeout(connectTimeout);
      logger.i('Подключено через прокси ${proxySettings.type.name}');
    } else {
      logger.i('Connection: TCP connect $host:$port (лимит ${connectTimeout.inSeconds}с)');
      socket = await Socket.connect(host, port, timeout: connectTimeout);
      logger.i('Connection: TCP установлен, начинаю TLS');
    }
    final allowInsecure = await TlsConfig.isInsecureAllowed();
    if (allowInsecure) {
      logger.w(
        'TLS: проверка сертификата отключена (дебаг) — соединение уязвимо к MitM',
      );
    }
    final secured = allowInsecure
        ? SecureSocket.secure(socket, host: host, onBadCertificate: (_) => true)
        : SecureSocket.secure(socket, host: host);
    try {
      final result = await secured.timeout(connectTimeout);
      logger.i('Connection: TLS-handshake завершён');
      return result;
    } on TimeoutException {
      logger.w('Connection: TLS-handshake таймаут ${connectTimeout.inSeconds}с');
      socket.destroy();
      rethrow;
    }
  }

  void write(Uint8List data) {
    if (_socket == null || !isConnected) {
      throw StateError('Нельзя писать: сокет не подключён');
    }
    _socket!.add(data);
  }

  Future<void> disconnect() async {
    _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;

    if (socket != null) {
      TrafficMonitor.instance.recordEvent('Соединение закрыто');
      try {
        await socket.close();
      } catch (e) {
        logger.w('Ошибка при закрытии сокета: $e');
      }
    }

    _setState(SocketState.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _dataController.close();
    await _stateController.close();
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../config/proxy_config.dart';
import '../utils/logger.dart';
import 'proxy_connector.dart';
import 'vpn_bypass.dart';

enum SocketState { disconnected, connecting, connected }

/// Обёртка над TCP + TLS сокетом.
/// Отдаёт сырые байты через [dataStream], сборкой пакетов занимается [PacketReceiver].
class Connection {
  RawSecureSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
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
    _stateController.add(newState);
  }

  Future<void> connect(
    String host,
    int port, {
    bool bypassVpn = false,
    Duration? timeout,
  }) async {
    if (_state != SocketState.disconnected) return;
    _setState(SocketState.connecting);

    try {
      final proxySettings = await ProxyConfig.load();

      // Решение «обходить VPN или нет» принимает вызывающий (Api):
      // первая попытка идёт через VPN, при её провале — мимо туннеля.
      if (bypassVpn) {
        await VpnBypassService.instance.bind();
      } else {
        await VpnBypassService.instance.restoreDefault();
      }

      final socket = await _openSecureSocket(
        host,
        port,
        proxySettings,
        timeout: timeout,
      );

      _socket = socket;
      _setState(SocketState.connected);
      logger.i('Подключено к $host:$port');

      _subscription = _socket!.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final data = _socket?.read();
            if (data != null) {
              _dataController.add(data);
            }
          } else if (event == RawSocketEvent.readClosed ||
              event == RawSocketEvent.closed) {
            logger.w('Сокет закрыт сервером');
            disconnect();
          }
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

  Future<RawSecureSocket> _openSecureSocket(
    String host,
    int port,
    ProxySettings proxySettings, {
    Duration? timeout,
  }) async {
    RawSocket rawSocket;
    if (proxySettings.isEnabled) {
      final connector = ProxyConnector(proxySettings);
      rawSocket = await connector.connect(host, port);
      logger.i('Подключено через прокси ${proxySettings.type.name}');
    } else {
      rawSocket = timeout == null
          ? await RawSocket.connect(host, port)
          : await RawSocket.connect(host, port, timeout: timeout);
    }
    return RawSecureSocket.secure(
      rawSocket,
      host: host,
      onBadCertificate: (_) => true,
    );
  }

  void write(Uint8List data) {
    if (_socket == null || !isConnected) {
      throw StateError('Нельзя писать: сокет не подключён');
    }
    _socket!.write(data);
  }

  Future<void> disconnect() async {
    _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;

    if (socket != null) {
      try {
        socket.close();
      } catch (e) {
        logger.w('Ошибка при закрытии сокета: $e');
      }
    }

    _setState(SocketState.disconnected);
  }

  void dispose() {
    disconnect();
    _dataController.close();
    _stateController.close();
  }
}

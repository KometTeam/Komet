import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../utils/logger.dart';

enum SocketState { disconnected, connecting, connected }

/// Обёртка над TCP + TLS сокетом.
/// Отдаёт сырые байты через [dataStream], сборкой пакетов занимается [PacketReceiver].
class Connection {
  SecureSocket? _socket;
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

  Future<void> connect(String host, int port) async {
    if (_state != SocketState.disconnected) return;
    _setState(SocketState.connecting);

    try {
      final socket = await Socket.connect(host, port);
      _socket = await SecureSocket.secure(
        socket,
        onBadCertificate: (_) => true,
      );

      _setState(SocketState.connected);
      logger.i('Подключено к $host:$port');

      _socket!.listen(
        (data) => _dataController.add(Uint8List.fromList(data)),
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

  void write(Uint8List data) {
    if (_socket == null || !isConnected) {
      throw StateError('Нельзя писать: сокет не подключён');
    }
    _socket!.add(data);
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;

    if (socket != null) {
      try {
        socket.destroy();
      } catch (_) {}
    }

    _setState(SocketState.disconnected);
  }

  void dispose() {
    disconnect();
    _dataController.close();
    _stateController.close();
  }
}

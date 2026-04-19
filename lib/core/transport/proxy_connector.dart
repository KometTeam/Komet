import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../config/proxy_config.dart';
import '../utils/logger.dart';

/// Устанавливает TCP-соединение через SOCKS5 или HTTP CONNECT прокси.
/// Возвращает [RawSocket], который никогда не слушался —
/// его можно передать в [RawSecureSocket.secure].
class ProxyConnector {
  final ProxySettings settings;

  ProxyConnector(this.settings);

  Future<RawSocket> connect(String targetHost, int targetPort) async {
    switch (settings.type) {
      case ProxyType.socks5:
        return _connectSocks5(targetHost, targetPort);
      case ProxyType.httpConnect:
        return _connectHttpConnect(targetHost, targetPort);
      case ProxyType.none:
        return RawSocket.connect(targetHost, targetPort);
    }
  }

  // ── SOCKS5 (RFC 1928) ──────────────────────────────────────────────────

  Future<RawSocket> _connectSocks5(String targetHost, int targetPort) async {
    final proxySocket = await RawSocket.connect(settings.host, settings.port);
    logger.i('SOCKS5: подключено к прокси ${settings.host}:${settings.port}');

    final io = _RawSocketIO(proxySocket);
    try {
      // 1. Greeting
      final useAuth = settings.hasCredentials;
      if (useAuth) {
        await io.write([0x05, 0x02, 0x00, 0x02]);
      } else {
        await io.write([0x05, 0x01, 0x00]);
      }

      var response = await io.readExact(2);
      if (response[0] != 0x05) {
        throw SocketException(
          'SOCKS5: неверная версия протокола: ${response[0]}',
        );
      }

      final method = response[1];
      if (method == 0xFF) {
        throw SocketException(
          'SOCKS5: сервер отклонил все методы аутентификации',
        );
      }

      // 2. Аутентификация (RFC 1929)
      if (method == 0x02) {
        if (!useAuth) {
          throw SocketException('SOCKS5: прокси требует аутентификацию');
        }
        final usernameBytes = utf8.encode(settings.username!);
        final passwordBytes = utf8.encode(settings.password!);
        final authPacket = BytesBuilder()
          ..addByte(0x01)
          ..addByte(usernameBytes.length)
          ..add(usernameBytes)
          ..addByte(passwordBytes.length)
          ..add(passwordBytes);
        await io.write(authPacket.toBytes());

        final authResponse = await io.readExact(2);
        if (authResponse[1] != 0x00) {
          throw SocketException('SOCKS5: аутентификация не пройдена');
        }
        logger.i('SOCKS5: аутентификация пройдена');
      }

      // 3. Connect request
      final hostBytes = utf8.encode(targetHost);
      final connectPacket = BytesBuilder()
        ..addByte(0x05) // VER
        ..addByte(0x01) // CMD: CONNECT
        ..addByte(0x00) // RSV
        ..addByte(0x03) // ATYP: domain
        ..addByte(hostBytes.length)
        ..add(hostBytes)
        ..addByte((targetPort >> 8) & 0xFF)
        ..addByte(targetPort & 0xFF);
      await io.write(connectPacket.toBytes());

      // 4. Reply
      final reply = await io.readExact(4);
      if (reply[0] != 0x05) {
        throw SocketException('SOCKS5: неверная версия в ответе');
      }
      if (reply[1] != 0x00) {
        throw SocketException(
          'SOCKS5: ошибка подключения, код: ${reply[1]}',
        );
      }

      // Пропускаем bind address
      switch (reply[3]) {
        case 0x01:
          await io.readExact(4 + 2);
          break;
        case 0x03:
          final lenBuf = await io.readExact(1);
          await io.readExact(lenBuf[0] + 2);
          break;
        case 0x04:
          await io.readExact(16 + 2);
          break;
      }

      logger.i('SOCKS5: туннель к $targetHost:$targetPort установлен');

      // Создаём локальную пару и проксируем данные
      return _bridgeToFreshSocket(proxySocket, io);
    } catch (e) {
      io.dispose();
      proxySocket.close();
      rethrow;
    }
  }

  // ── HTTP CONNECT ────────────────────────────────────────────────────────

  Future<RawSocket> _connectHttpConnect(
    String targetHost,
    int targetPort,
  ) async {
    final proxySocket = await RawSocket.connect(settings.host, settings.port);
    logger.i(
      'HTTP CONNECT: подключено к прокси ${settings.host}:${settings.port}',
    );

    final io = _RawSocketIO(proxySocket);
    try {
      final request = StringBuffer()
        ..write('CONNECT $targetHost:$targetPort HTTP/1.1\r\n')
        ..write('Host: $targetHost:$targetPort\r\n');

      if (settings.hasCredentials) {
        final credentials = base64Encode(
          utf8.encode('${settings.username}:${settings.password}'),
        );
        request.write('Proxy-Authorization: Basic $credentials\r\n');
      }
      request.write('\r\n');

      await io.write(utf8.encode(request.toString()));

      // Читаем HTTP-ответ до \r\n\r\n
      final headerBytes = <int>[];
      while (true) {
        final byte = await io.readExact(1);
        headerBytes.add(byte[0]);
        if (headerBytes.length >= 4 &&
            headerBytes[headerBytes.length - 4] == 0x0D &&
            headerBytes[headerBytes.length - 3] == 0x0A &&
            headerBytes[headerBytes.length - 2] == 0x0D &&
            headerBytes[headerBytes.length - 1] == 0x0A) {
          break;
        }
        if (headerBytes.length > 8192) {
          throw SocketException(
            'HTTP CONNECT: заголовок ответа слишком большой',
          );
        }
      }

      final responseStr = utf8.decode(headerBytes, allowMalformed: true);
      final statusLine = responseStr.split('\r\n').first;
      final parts = statusLine.split(' ');
      final statusCode = parts.length >= 2 ? int.tryParse(parts[1]) ?? 0 : 0;
      if (statusCode != 200) {
        throw SocketException(
          'HTTP CONNECT: прокси вернул статус $statusCode',
        );
      }

      logger.i('HTTP CONNECT: туннель к $targetHost:$targetPort установлен');
      return _bridgeToFreshSocket(proxySocket, io);
    } catch (e) {
      io.dispose();
      proxySocket.close();
      rethrow;
    }
  }

  // ── Мост: создаём свежий сокет и проксируем через loopback ─────────────

  /// После handshake proxy-сокет уже прослушан (single-subscription).
  /// Создаём пару локальных сокетов через loopback и проксируем данные
  /// между прокси-сокетом и одним концом. Второй конец возвращаем —
  /// он «свежий» и его можно передать в [RawSecureSocket.secure].
  Future<RawSocket> _bridgeToFreshSocket(
    RawSocket proxySocket,
    _RawSocketIO io,
  ) async {
    final server = await RawServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final clientSide = await RawSocket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    final serverSide = await server.first;
    await server.close();

    // proxy → local (через уже имеющуюся подписку _RawSocketIO)
    io.onData = (data) {
      serverSide.write(data);
    };
    io.onClosed = () {
      serverSide.shutdown(SocketDirection.send);
    };

    // local → proxy
    serverSide.listen((event) {
      if (event == RawSocketEvent.read) {
        final data = serverSide.read();
        if (data != null) proxySocket.write(data);
      } else if (event == RawSocketEvent.readClosed ||
          event == RawSocketEvent.closed) {
        proxySocket.shutdown(SocketDirection.send);
      }
    });

    // Сливаем данные, буферизованные во время handshake
    io.flushBuffered();

    logger.i('Прокси-мост через loopback создан');
    return clientSide;
  }
}

/// Обёртка над единственной подпиской [RawSocket], с буфером для чтения.
///
/// После handshake переключается в режим моста:
/// данные из proxy-сокета пересылаются через [onData] в loopback-пару.
class _RawSocketIO {
  final RawSocket _socket;
  late final StreamSubscription<RawSocketEvent> _sub;

  final _readBuffer = <int>[];
  Completer<void>? _readWaiter;
  Completer<void>? _writeWaiter;
  bool _closed = false;
  Object? _error;

  /// Коллбэк для данных в режиме моста.
  void Function(Uint8List data)? onData;

  /// Коллбэк закрытия в режиме моста.
  void Function()? onClosed;

  _RawSocketIO(this._socket) {
    _sub = _socket.listen(
      _onEvent,
      onError: (Object err) {
        _error = err;
        _closed = true;
        _readWaiter?.completeError(err);
        _readWaiter = null;
        _writeWaiter?.completeError(err);
        _writeWaiter = null;
      },
    );
  }

  void _onEvent(RawSocketEvent event) {
    switch (event) {
      case RawSocketEvent.read:
        final data = _socket.read();
        if (data != null) {
          if (onData != null) {
            // Режим моста — пересылаем напрямую
            onData!(data);
          } else {
            // Режим handshake — буферизуем
            _readBuffer.addAll(data);
            _readWaiter?.complete();
            _readWaiter = null;
          }
        }
        break;
      case RawSocketEvent.write:
        _writeWaiter?.complete();
        _writeWaiter = null;
        break;
      case RawSocketEvent.readClosed:
      case RawSocketEvent.closed:
        _closed = true;
        onClosed?.call();
        _readWaiter?.completeError(
          SocketException('Прокси закрыл соединение'),
        );
        _readWaiter = null;
        _writeWaiter?.completeError(
          SocketException('Прокси закрыл соединение'),
        );
        _writeWaiter = null;
        break;
    }
  }

  /// Читает ровно [count] байт.
  Future<Uint8List> readExact(int count) async {
    while (_readBuffer.length < count) {
      if (_error != null) throw _error!;
      if (_closed) {
        throw SocketException(
          'Соединение закрыто '
          '(ожидали $count байт, получили ${_readBuffer.length})',
        );
      }
      _readWaiter = Completer<void>();
      await _readWaiter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw SocketException('Тайм-аут при чтении от прокси'),
      );
    }
    final result = Uint8List.fromList(_readBuffer.sublist(0, count));
    _readBuffer.removeRange(0, count);
    return result;
  }

  /// Записывает все байты.
  Future<void> write(List<int> data) async {
    var offset = 0;
    while (offset < data.length) {
      if (_error != null) throw _error!;
      if (_closed) throw SocketException('Соединение закрыто при записи');
      final written = _socket.write(data, offset);
      if (written > 0) {
        offset += written;
      } else {
        _writeWaiter = Completer<void>();
        await _writeWaiter!.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw SocketException('Тайм-аут при записи в прокси'),
        );
      }
    }
  }

  /// Пересылает данные, оставшиеся в буфере после handshake, в мост.
  void flushBuffered() {
    if (_readBuffer.isNotEmpty && onData != null) {
      onData!(Uint8List.fromList(_readBuffer));
      _readBuffer.clear();
    }
  }

  void dispose() {
    _sub.cancel();
  }
}

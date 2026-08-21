import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../utils/logger.dart';
import 'max_web_protocol.dart';

class MaxWebException implements Exception {
  final String message;
  final String? code;

  const MaxWebException(this.message, {this.code});

  @override
  String toString() => code == null ? message : '$code: $message';
}

class MaxWebDevice {
  final String deviceId;
  final String appVersion;
  final String osVersion;
  final String deviceName;
  final String screen;
  final String timezone;
  final String locale;
  final String userAgent;

  const MaxWebDevice({
    required this.deviceId,
    this.appVersion = '26.8.8',
    this.osVersion = 'iOS',
    this.deviceName = 'Safari',
    required this.screen,
    this.timezone = 'Europe/Moscow',
    this.locale = 'ru',
    required this.userAgent,
  });

  Map<String, Object?> toHandshakeUserAgent() => <String, Object?>{
    'deviceType': 'WEB',
    'pushDeviceType': 'WEBPUSH',
    'locale': locale,
    'deviceLocale': locale,
    'osVersion': osVersion,
    'deviceName': deviceName,
    'headerUserAgent': userAgent,
    'isPwa': true,
    'appVersion': appVersion,
    'screen': screen,
    'timezone': timezone,
  };
}

class MaxWebSocketSession {
  static const String endpoint = 'wss://api.oneme.ru/websocket';
  static const String origin = 'https://web.max.ru';
  static const Duration requestTimeout = Duration(seconds: 30);

  static const int _opcodePing = 1;
  static const int _opcodeSessionInit = 6;

  final MaxWebDevice device;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  int _seq = 0;
  bool _closed = false;

  MaxWebSocketSession({required this.device});

  Future<Object?> connect() async {
    final socket = await WebSocket.connect(
      endpoint,
      headers: <String, Object>{
        'Origin': origin,
        'User-Agent': device.userAgent,
      },
    );
    _socket = socket;
    _subscription = socket.listen(
      _onFrame,
      onError: (Object error) => _failAll(MaxWebException('сокет: $error')),
      onDone: () => _failAll(const MaxWebException('соединение закрыто сервером')),
      cancelOnError: true,
    );

    return request(_opcodeSessionInit, <String, Object?>{
      'userAgent': device.toHandshakeUserAgent(),
      'deviceId': device.deviceId,
    });
  }

  Future<Object?> request(int opcode, Object? payload) {
    final socket = _socket;
    if (socket == null || _closed) {
      return Future<Object?>.error(
        const MaxWebException('сессия не подключена'),
      );
    }

    _seq += 1;
    final seq = _seq;
    final completer = Completer<Object?>();
    _pending[seq] = completer;

    socket.add(
      MaxWebFraming.encode(
        cmd: MaxWebCmd.request,
        seq: seq,
        opcode: opcode,
        payload: payload,
      ),
    );

    return completer.future.timeout(
      requestTimeout,
      onTimeout: () {
        _pending.remove(seq);
        throw MaxWebException('опкод $opcode: сервер не ответил');
      },
    );
  }

  void _onFrame(dynamic raw) {
    if (raw is! List<int>) return;

    final MaxWebFrame frame;
    try {
      frame = MaxWebFraming.decode(Uint8List.fromList(raw));
    } catch (e) {
      logger.w('WebPush: не разобрал кадр ($e)');
      return;
    }

    if (frame.cmd == MaxWebCmd.request) {
      if (frame.opcode == _opcodePing) {
        _socket?.add(
          MaxWebFraming.encode(
            cmd: MaxWebCmd.ok,
            seq: frame.seq,
            opcode: _opcodePing,
          ),
        );
      }
      return;
    }

    final completer = _pending.remove(frame.seq);
    if (completer == null || completer.isCompleted) return;

    if (frame.isError) {
      completer.completeError(_errorFrom(frame));
      return;
    }
    completer.complete(frame.payload);
  }

  MaxWebException _errorFrom(MaxWebFrame frame) {
    final payload = frame.payload;
    if (payload is Map) {
      final message = payload['localizedMessage'] ?? payload['message'];
      final code = payload['error'];
      if (message is String && message.isNotEmpty) {
        return MaxWebException(message, code: code is String ? code : null);
      }
      if (code is String && code.isNotEmpty) {
        return MaxWebException(code, code: code);
      }
    }
    return MaxWebException('опкод ${frame.opcode}: ошибка сервера (cmd=${frame.cmd})');
  }

  void _failAll(MaxWebException error) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _failAll(const MaxWebException('сессия закрыта'));
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
  }
}

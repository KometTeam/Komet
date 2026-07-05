import 'dart:async';

import '../protocol/packet.dart';
import '../protocol/opcode_map.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';

typedef PacketHandler = void Function(Packet packet);

class _PendingRequest {
  _PendingRequest(this.completer, this.sentAt);

  final Completer<Packet> completer;
  final DateTime sentAt;
}

/// Роутер входящих пакетов.
///
/// Ответы на запросы матчатся по seq (через [registerPending]),
/// пуши — по opcode (через [registerHandler]).
class PacketDispatcher {
  final Map<int, _PendingRequest> _pendingRequests = {};
  final Map<int, PacketHandler> _pushHandlers = {};

  final _pushController = StreamController<Packet>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Стрим всех входящих пушей (cmd == 1)
  Stream<Packet> get pushStream => _pushController.stream;

  Stream<String> get errorStream => _errorController.stream;

  static String? _serverErrorText(dynamic payload) {
    if (payload is! Map) return null;
    for (final key in ['localizedMessage', 'title']) {
      final v = payload[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  Timer? _cleanupTimer;

  PacketDispatcher() {
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _cleanupStaleRequests(),
    );
  }

  /// Регистрирует ожидание ответа — future завершится когда
  /// придёт пакет с совпадающим seq.
  Future<Packet> registerPending(int seq) {
    final existing = _pendingRequests[seq];
    if (existing != null && !existing.completer.isCompleted) {
      existing.completer.completeError(
        StateError('seq=$seq переиспользован до получения ответа'),
      );
    }
    final completer = Completer<Packet>();
    _pendingRequests[seq] = _PendingRequest(completer, DateTime.now());
    return completer.future;
  }

  /// Вешает обработчик на пуши с конкретным опкодом.
  void registerHandler(int opcode, PacketHandler handler) {
    _pushHandlers[opcode] = handler;
  }

  void unregisterHandler(int opcode) {
    _pushHandlers.remove(opcode);
  }

  void dispatch(Packet packet) {
    final tag = Opcode.name(packet.opcode);

    if (packet.cmd == CmdType.ok ||
        packet.cmd == CmdType.error ||
        packet.cmd == CmdType.notFound) {
      final payloadLog = packet.opcode == Opcode.login
          ? '<скрыто: ответ login>'
          : payloadForLog(packet.payload);
      logger.i(
        '<= {ver: ${packet.api}, cmd: ${packet.cmd}, seq: ${packet.seq}, opcode: ${packet.opcode}, payload: $payloadLog}',
      );

      if (packet.isError) {
        final isSessionExpired =
            packet.payload is Map &&
            packet.payload['message'] == 'FAIL_LOGIN_TOKEN';
        final serverText = _serverErrorText(packet.payload);
        if (serverText != null && !isSessionExpired) {
          _errorController.add(serverText);
        }
      }

      final pending = _pendingRequests.remove(packet.seq);
      final completer = pending?.completer;

      if (completer == null) {
        if (packet.opcode != Opcode.ping) {
          logger.w('Нет ожидающего запроса для seq=${packet.seq} [$tag]');
        }
        return;
      }

      if (packet.isError) {
        final message = messageFromErrorPayload(packet.payload);
        final errorKey = packet.payload is Map
            ? packet.payload['error']?.toString()
            : null;
        if (packet.payload is Map &&
            packet.payload['message'] == 'FAIL_LOGIN_TOKEN') {
          completer.completeError(SessionExpiredException(message));
        } else {
          completer.completeError(PacketError(message, errorKey: errorKey));
        }
      } else {
        completer.complete(packet);
      }
    } else if (packet.isPush) {
      logger.i(
        '<= push {ver: ${packet.api}, cmd: ${packet.cmd}, seq: ${packet.seq}, opcode: ${packet.opcode}, payload: ${payloadForLog(packet.payload)}}',
      );
      final handler = _pushHandlers[packet.opcode];
      if (handler != null) {
        try {
          handler(packet);
        } catch (e) {
          logger.w('$tag handler failed: $e');
        }
      }
      _pushController.add(packet);
    }
  }

  /// Чистит зависшие запросы старше 30 секунд
  void _cleanupStaleRequests() {
    final now = DateTime.now();
    final staleKeys = <int>[];

    _pendingRequests.forEach((seq, pending) {
      if (now.difference(pending.sentAt).inSeconds > 30) staleKeys.add(seq);
    });

    for (final seq in staleKeys) {
      final pending = _pendingRequests.remove(seq);
      final completer = pending?.completer;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(TimeoutException('Таймаут запроса seq=$seq'));
      }
    }
  }

  /// Обрывает все ожидающие запросы (при дисконнекте)
  void clearPending() {
    for (final entry in _pendingRequests.entries) {
      if (!entry.value.completer.isCompleted) {
        entry.value.completer.completeError(StateError('Соединение закрыто'));
      }
    }
    _pendingRequests.clear();
  }

  void dispose() {
    _cleanupTimer?.cancel();
    clearPending();
    _pushController.close();
    _errorController.close();
  }
}

import 'dart:async';

import '../protocol/packet.dart';
import '../protocol/opcode_map.dart';
import '../utils/logger.dart';

typedef PacketHandler = void Function(Packet packet);

/// Роутер входящих пакетов.
///
/// Ответы на запросы матчатся по seq (через [registerPending]),
/// пуши — по opcode (через [registerHandler]).
class PacketDispatcher {
  final Map<int, Completer<Packet>> _pendingRequests = {};
  final Map<int, DateTime> _requestTimestamps = {};
  final Map<int, PacketHandler> _pushHandlers = {};

  final _pushController = StreamController<Packet>.broadcast();

  /// Стрим всех входящих пушей (cmd == 1)
  Stream<Packet> get pushStream => _pushController.stream;

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
    final completer = Completer<Packet>();
    _pendingRequests[seq] = completer;
    _requestTimestamps[seq] = DateTime.now();
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
      logger.i(
        '<= {ver: ${packet.api}, cmd: ${packet.cmd}, seq: ${packet.seq}, opcode: ${packet.opcode}, payload: ${packet.payload}}',
      );

      final completer = _pendingRequests.remove(packet.seq);
      _requestTimestamps.remove(packet.seq);

      if (completer == null) {
        if (packet.opcode != Opcode.ping) {
          logger.w('Нет ожидающего запроса для seq=${packet.seq} [$tag]');
        }
        return;
      }

      if (packet.isError) {
        completer.completeError(
          PacketError(messageFromErrorPayload(packet.payload)),
        );
      } else {
        completer.complete(packet);
      }
    } else if (packet.isPush) {
      logger.i(
        '<= push {ver: ${packet.api}, cmd: ${packet.cmd}, seq: ${packet.seq}, opcode: ${packet.opcode}, payload: ${packet.payload}}',
      );
      _pushHandlers[packet.opcode]?.call(packet);
      _pushController.add(packet);
    }
  }

  /// Чистит зависшие запросы старше 30 секунд
  void _cleanupStaleRequests() {
    final now = DateTime.now();
    final staleKeys = <int>[];

    _requestTimestamps.forEach((seq, ts) {
      if (now.difference(ts).inSeconds > 30) staleKeys.add(seq);
    });

    for (final seq in staleKeys) {
      final completer = _pendingRequests.remove(seq);
      _requestTimestamps.remove(seq);
      if (completer != null && !completer.isCompleted) {
        completer.completeError(TimeoutException('Таймаут запроса seq=$seq'));
      }
    }
  }

  /// Обрывает все ожидающие запросы (при дисконнекте)
  void clearPending() {
    for (final entry in _pendingRequests.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(StateError('Соединение закрыто'));
      }
    }
    _pendingRequests.clear();
    _requestTimestamps.clear();
  }

  void dispose() {
    _cleanupTimer?.cancel();
    clearPending();
    _pushController.close();
  }
}

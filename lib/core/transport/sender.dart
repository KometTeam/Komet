import '../protocol/packet.dart';
import '../utils/logger.dart';
import 'connection.dart';

/// Упаковывает и отправляет пакеты, ведёт счётчик seq.
class PacketSender {
  int _seq = 0;

  int get currentSeq => _seq;

  int _nextSeq() {
    _seq = (_seq + 1) % 256;
    return _seq;
  }

  /// Отправляет пакет, возвращает присвоенный seq.
  int send(Connection connection, int opcode, Map<dynamic, dynamic> payload) {
    final seq = _nextSeq();
    final data = packPacket(opcode, payload, seq: seq);
    connection.write(data);
    logger.i(
      '=> {ver: 10, cmd: 0, seq: $seq, opcode: $opcode, payload: $payload}',
    );
    return seq;
  }
}

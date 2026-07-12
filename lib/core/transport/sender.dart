import '../protocol/packet.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'connection.dart';
import 'traffic_monitor.dart';

class PacketSender {
  int _seq = 0;

  int get currentSeq => _seq;

  int _nextSeq() {
    _seq = (_seq + 1) % 65536;
    return _seq;
  }

  int send(Connection connection, int opcode, Map<dynamic, dynamic> payload) {
    final seq = _nextSeq();
    final data = packPacket(opcode, payload, seq: seq);
    connection.write(data);
    TrafficMonitor.instance.recordOutgoing(opcode, payload, seq, data.length);
    logger.i(
      '=> {ver: 10, cmd: 0, seq: $seq, opcode: $opcode, payload: ${payloadForLog(payload)}}',
    );
    return seq;
  }
}

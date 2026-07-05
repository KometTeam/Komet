import '../../api.dart';
import '../../../core/protocol/packet.dart';

abstract class AccountApiBase {
  final Api api;
  const AccountApiBase(this.api);

  void ensureOnline() {
    if (api.state != SessionState.online) {
      throw StateError(
        'AccountModule: сессия не онлайн (текущее состояние: ${api.state.name})',
      );
    }
  }

  void checkPacketError(Packet packet, String method) {
    throwIfPacketError(packet);
  }

  Map requireMapPayload(Packet packet, String method) {
    checkPacketError(packet, method);
    final data = packet.payload;
    if (data is! Map) {
      throw Exception('$method: неожиданный тип payload: ${data.runtimeType}');
    }
    return data;
  }
}

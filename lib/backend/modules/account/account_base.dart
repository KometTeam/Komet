import '../../api.dart';
import '../../../core/protocol/packet.dart';

// #***! общий предок подмодулей, три проверки на каждый запрос
abstract class AccountApiBase {
  final Api api;
  const AccountApiBase(this.api);

  // #***! до хэндшейка запрос бессмысленен, падаем сразу
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

  // #***! ответ обязан быть картой, иначе сервер сменил формат
  Map requireMapPayload(Packet packet, String method) {
    checkPacketError(packet, method);
    final data = packet.payload;
    if (data is! Map) {
      throw Exception('$method: неожиданный тип payload: ${data.runtimeType}');
    }
    return data;
  }
}

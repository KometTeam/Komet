import '../../../core/protocol/opcode_map.dart';
import 'account_base.dart';
import 'account_models.dart';

// #***! активные сессии и вход по QR
class SessionsModule extends AccountApiBase {
  SessionsModule(super.api);

  // #***! где выполнен вход
  Future<List<SessionInfo>> getSessions() async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.sessionsInfo, {});
    checkPacketError(packet, 'getSessions');
    final data = packet.payload;
    if (data is! Map || data['sessions'] is! List) return [];
    final sessions = data['sessions'] as List;
    return sessions
        .map((s) => SessionInfo.fromMap(s as Map<dynamic, dynamic>))
        .toList();
  }

  // #***! разлогинить все кроме текущего
  Future<void> terminateOtherSessions() async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.sessionsClose, {});
    checkPacketError(packet, 'terminateOtherSessions');
  }

  // #***! подтверждение входа в веб по QR
  Future<void> authorizeWebQrLogin(String qrLink) async {
    ensureOnline();
    final link = qrLink.trim();
    if (link.isEmpty) {
      throw ArgumentError('Пустая ссылка из QR');
    }

    // #***! пинг и сессии перед подтверждением, сервер ждёт именно так иначе отклонит
    await api.sendRequest(Opcode.ping, {'interactive': true});
    await api.sendRequest(Opcode.sessionsInfo, {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final packet = await api.sendRequest(Opcode.authQrApprove, {
      'qrLink': link,
    });
    checkPacketError(packet, 'authorizeWebQrLogin');
  }
}

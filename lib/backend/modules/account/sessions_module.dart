import '../../../core/protocol/opcode_map.dart';
import 'account_base.dart';
import 'account_models.dart';

class SessionsModule extends AccountApiBase {
  SessionsModule(super.api);

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

  Future<void> terminateOtherSessions() async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.sessionsClose, {});
    checkPacketError(packet, 'terminateOtherSessions');
  }

  Future<void> authorizeWebQrLogin(String qrLink) async {
    ensureOnline();
    final link = qrLink.trim();
    if (link.isEmpty) {
      throw ArgumentError('Пустая ссылка из QR');
    }

    await api.sendRequest(Opcode.ping, {'interactive': true});
    await api.sendRequest(Opcode.sessionsInfo, {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final packet = await api.sendRequest(Opcode.authQrApprove, {
      'qrLink': link,
    });
    checkPacketError(packet, 'authorizeWebQrLogin');
  }
}

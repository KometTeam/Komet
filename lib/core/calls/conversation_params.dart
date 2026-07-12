import 'package:kolibri/kolibri.dart' as kb;

/// Параметры подключения к звонку (`vcp`), которые сервер присылает в пуше
/// входящего звонка (opcode 137) и в ответе на инициацию исходящего.
///
/// Формат строки: `<rawLen>:<base64(LZ4-block)>`. После распаковки —
/// компактный JSON с короткими ключами. Расшифровка повторяет
/// `ru.ok.android.externcalls.sdk.api.ConversationParams.decode`.
class ConversationParams {
  /// Токен авторизации в сигналинге звонка.
  final String token;

  /// WebSocket сигналинга, напр. `wss://videowebrtc.okcdn.ru/ws2`.
  final String wsEndpoint;
  final List<String> wsIps;

  /// HTTP/3 web-transport fallback, напр. `https://videowebrtc.okcdn.ru:23456/wt`.
  final String? wtEndpoint;
  final List<String> wtIps;

  /// API звонков, напр. `https://calls.okcdn.ru`.
  final String? callsApiEndpoint;
  final List<String> callsApiIps;

  /// Тип клиента, напр. `one_me`.
  final String? clientType;

  /// Время истечения параметров (unix-секунды).
  final int? expiresAt;

  final String? stun;
  final List<String> turn;
  final String? turnUser;
  final String? turnPassword;

  final bool isVideo;

  const ConversationParams({
    required this.token,
    required this.wsEndpoint,
    this.wsIps = const [],
    this.wtEndpoint,
    this.wtIps = const [],
    this.callsApiEndpoint,
    this.callsApiIps = const [],
    this.clientType,
    this.expiresAt,
    this.stun,
    this.turn = const [],
    this.turnUser,
    this.turnPassword,
    this.isVideo = false,
  });

  /// ICE-серверы в формате, который ожидает `flutter_webrtc`
  /// (`RTCPeerConnection`).
  List<Map<String, dynamic>> get iceServers {
    final servers = <Map<String, dynamic>>[];
    if (stun != null && stun!.isNotEmpty) {
      servers.add({'urls': stun});
    }
    if (turn.isNotEmpty) {
      servers.add({
        'urls': turn,
        if (turnUser != null) 'username': turnUser,
        if (turnPassword != null) 'credential': turnPassword,
      });
    }
    return servers;
  }

  /// `true`, если параметры ещё действительны (с запасом в 5 секунд).
  bool get isExpired {
    if (expiresAt == null) return false;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSec >= expiresAt! - 5;
  }

  /// Распаковывает и парсит строку `vcp` через Rust-ядро (kolibri). Возвращает
  /// `null`, если формат не распознан. Требует инициализации `initKolibri()`.
  static ConversationParams? decode(String vcp) {
    final kb.CallParams? p = kb.decodeVcp(vcp: vcp, conversationId: '');
    if (p == null) return null;
    return ConversationParams(
      token: p.token,
      wsEndpoint: p.wsEndpoint,
      stun: p.stun,
      turn: p.turn,
      turnUser: p.turnUser,
      turnPassword: p.turnPassword,
      isVideo: p.isVideo,
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import '../protocol/lz4_block.dart';

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

  static List<String> _splitTurn(Object? value) {
    if (value is! String || value.isEmpty) return const [];
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  /// Распаковывает и парсит строку `vcp`. Возвращает `null`, если формат
  /// не распознан.
  static ConversationParams? decode(String vcp) {
    final sep = vcp.indexOf(':');
    if (sep <= 0) return null;

    final rawLen = int.tryParse(vcp.substring(0, sep));
    if (rawLen == null || rawLen <= 0) return null;

    final Uint8List compressed;
    try {
      compressed = base64.decode(vcp.substring(sep + 1));
    } catch (_) {
      return null;
    }

    final Uint8List bytes;
    try {
      final decompressed = lz4BlockDecompress(compressed, rawLen);
      bytes = decompressed.length > rawLen
          ? Uint8List.sublistView(decompressed, 0, rawLen)
          : decompressed;
    } catch (_) {
      return null;
    }

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;

    final token = json['tkn'];
    final wse = json['wse'];
    if (token is! String || wse is! String) return null;

    return ConversationParams(
      token: token,
      wsEndpoint: wse,
      wsIps: _stringList(json['wsip']),
      wtEndpoint: json['wte'] as String?,
      wtIps: _stringList(json['wtip']),
      callsApiEndpoint: json['vcae'] as String?,
      callsApiIps: _stringList(json['vcaip']),
      clientType: json['srcp'] as String?,
      expiresAt: json['et'] is int ? json['et'] as int : null,
      stun: json['stne'] as String?,
      turn: _splitTurn(json['trne']),
      turnUser: json['trnu'] as String?,
      turnPassword: json['trnp'] as String?,
      isVideo: json['iv'] == true,
    );
  }
}

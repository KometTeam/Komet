// Backend module for parsing calls from Komet platform
import 'dart:convert';
import 'dart:math';

import 'contacts.dart';
import '../api.dart';
import '../../core/protocol/opcode_map.dart';

enum CallStatus { missed, canceled, outgoing, incoming }

/// Параметры подключения для исходящего звонка (ответ opcode 78).
class OutgoingCallParams {
  final String conversationId;

  /// Полный ws2 URL с уже вшитым токеном (`internalCallerParams.endpoint`).
  final String endpoint;

  /// Наш id в системе звонков (`internalCallerParams.id.internal`).
  final int callsUserId;

  final int peerExternalId;
  final bool isVideo;

  const OutgoingCallParams({
    required this.conversationId,
    required this.endpoint,
    required this.callsUserId,
    required this.peerExternalId,
    required this.isVideo,
  });
}

class CallLogEntry {
  final String id;
  final int accountId;
  final int peerId;
  final String name;
  final String? avatarUrl;
  final CallStatus status;
  final int time;
  final int count;

  const CallLogEntry({
    required this.id,
    required this.accountId,
    required this.peerId,
    required this.name,
    this.avatarUrl,
    required this.status,
    required this.time,
    this.count = 1,
  });
}

class CallsModule {
  final Api _api;

  CallsModule(this._api);

  /// Инициирует исходящий 1:1 звонок (opcode 78).
  Future<OutgoingCallParams> initiateCall(
    int calleeId, {
    bool isVideo = false,
  }) async {
    final conversationId = _uuidV4();
    final internalParams = jsonEncode({
      'deviceId': _api.deviceId ?? '',
      'sdkVersion': '2.8.9',
      'clientAppKey': _clientAppKey(),
      'platform': 'ANDROID',
      'protocolVersion': 5,
      'domainId': '',
      'capabilities': '3c03f',
    });

    final response = await _api.sendRequest(Opcode.videoChatStartActive, {
      'conversationId': conversationId,
      'calleeIds': [calleeId],
      'internalParams': internalParams,
      'isVideo': isVideo,
    });

    if (!response.isOk || response.payload is! Map) {
      throw Exception('initiateCall: bad response');
    }
    final payload = response.payload as Map;

    final icpRaw = payload['internalCallerParams'];
    final icp = icpRaw is String
        ? jsonDecode(icpRaw) as Map<dynamic, dynamic>
        : const <dynamic, dynamic>{};

    final endpoint = icp['endpoint'] as String?;
    if (endpoint == null) {
      throw Exception('initiateCall: no endpoint');
    }

    final id = icp['id'];
    final callsUserId = (id is Map ? id['internal'] as int? : null) ?? 0;
    final external =
        (id is Map ? int.tryParse('${id['external']}') : null) ?? calleeId;

    return OutgoingCallParams(
      conversationId: (payload['conversationId'] as String?) ?? conversationId,
      endpoint: endpoint,
      callsUserId: callsUserId,
      peerExternalId: external,
      isVideo: isVideo,
    );
  }

  static String _uuidV4() {
    final r = Random();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int i) => b[i].toRadixString(16).padLeft(2, '0');
    final s = List.generate(16, hex).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}'
        '-${s.substring(16, 20)}-${s.substring(20)}';
  }

  static String _clientAppKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final r = Random();
    return List.generate(17, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Fetch call history from opcode 79
  Future<List<CallLogEntry>> fetchHistory(
    int accountId,
    int currentUserId,
  ) async {
    final response = await _api.sendRequest(Opcode.videoChatHistory, {});
    if (!response.isOk || response.payload is! Map) return [];

    final payload = response.payload as Map<dynamic, dynamic>;
    return parseHistoryPayload(payload, accountId, currentUserId);
  }

  /// Парсинг истории звонков (opcode 79: videoChatHistory)
  static Future<List<CallLogEntry>> parseHistoryPayload(
    Map<dynamic, dynamic> payload,
    int accountId,
    int currentUserId,
  ) async {
    final history = payload['history'];
    if (history is! List || history.isEmpty) return [];

    final recentContacts = await ContactsModule.getContacts(accountId);
    final contactsMap = {for (final c in recentContacts) c.id: c};

    final List<CallLogEntry> extractedCalls = [];

    for (final item in history.whereType<Map>()) {
      final msg = item['message'];
      if (msg is! Map) continue;

      final attaches = msg['attaches'];
      if (attaches is! List || attaches.isEmpty) continue;

      final callAttach = attaches.firstWhere(
        (a) => a is Map && a['_type'] == 'CALL',
        orElse: () => null,
      );

      if (callAttach == null) continue;

      final senderId = (msg['sender'] as int?) ?? 0;
      final isOutgoing = senderId == currentUserId;

      int peerId = 0;
      if (isOutgoing) {
        final contactIds = callAttach['contactIds'];
        if (contactIds is List && contactIds.isNotEmpty) {
          peerId = (contactIds.first as int?) ?? 0;
        }
      } else {
        peerId = senderId;
      }

      final contact = contactsMap[peerId];
      final status = _parseCallStatus(callAttach, isOutgoing);
      final time = (msg['time'] as int?) ?? 0;
      final msgId =
          msg['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final name = (contact != null && contact.firstName.isNotEmpty)
          ? '${contact.firstName} ${contact.lastName ?? ''}'.trim()
          : 'Неизвестный';

      extractedCalls.add(
        CallLogEntry(
          id: msgId,
          accountId: accountId,
          peerId: peerId,
          name: name,
          avatarUrl: contact?.baseUrl,
          status: status,
          time: time,
        ),
      );
    }

    return extractedCalls;
  }

  static CallStatus _parseCallStatus(
    Map<dynamic, dynamic> callAttach,
    bool isOutgoing,
  ) {
    final hangupType = callAttach['hangupType'];
    final duration = (callAttach['duration'] as int?) ?? 0;

    if (isOutgoing) {
      if (hangupType == 'CANCELED' || duration == 0) return CallStatus.canceled;
      return CallStatus.outgoing;
    } else {
      if (hangupType == 'CANCELED' ||
          hangupType == 'REJECTED' ||
          hangupType == 'MISSED' ||
          duration == 0) {
        return CallStatus.missed;
      }
      return CallStatus.incoming;
    }
  }
}

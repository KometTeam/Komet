// Backend module for parsing calls from Komet platform
import 'contacts.dart';
import '../api.dart';
import '../../core/protocol/opcode_map.dart';

enum CallStatus { missed, canceled, outgoing, incoming }

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

      final name = contact?.firstName != null
          ? '${contact!.firstName} ${contact.lastName ?? ''}'.trim()
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

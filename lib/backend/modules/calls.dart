import 'dart:convert';

import 'contacts.dart';
import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/logger.dart';

enum CallStatus { missed, canceled, outgoing, incoming }

class OutgoingCallParams {
  final String conversationId;

  final String endpoint;

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

class CallLinkPreview {
  final String? conferenceId;
  final String? callName;
  final int participantsCount;
  final bool isVideo;

  const CallLinkPreview({
    this.conferenceId,
    this.callName,
    this.participantsCount = 0,
    this.isVideo = false,
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
  final bool isGroup;

  const CallLogEntry({
    required this.id,
    required this.accountId,
    required this.peerId,
    required this.name,
    this.avatarUrl,
    required this.status,
    required this.time,
    this.count = 1,
    this.isGroup = false,
  });
}

class _CallerEndpointMissingException implements Exception {
  final String message;

  const _CallerEndpointMissingException(this.message);

  @override
  String toString() => 'Exception: $message';
}

typedef _CallerEndpoint = ({String endpoint, int callsUserId, int? external});

class CallsModule {
  final Api _api;

  CallsModule(this._api);

  _CallerEndpoint _parseCallerEndpoint(
    Map payload,
    String key, {
    required String context,
  }) {
    final raw = payload[key];
    final parsed = raw is String
        ? jsonDecode(raw) as Map<dynamic, dynamic>
        : const <dynamic, dynamic>{};

    final endpoint = parsed['endpoint'] as String?;
    if (endpoint == null) {
      throw _CallerEndpointMissingException('$context: no endpoint');
    }

    final id = parsed['id'];
    final callsUserId = (id is Map ? id['internal'] as int? : null) ?? 0;
    final external = id is Map ? int.tryParse('${id['external']}') : null;

    return (endpoint: endpoint, callsUserId: callsUserId, external: external);
  }

  Future<OutgoingCallParams> initiateCall(
    int calleeId, {
    bool isVideo = false,
  }) async {
    final conversationId = uuidV4();

    final payload = await _api.sendRequestMap(Opcode.videoChatStartActive, {
      'conversationId': conversationId,
      'calleeIds': [calleeId],
      'internalParams': _internalParams(),
      'isVideo': isVideo,
    });

    if (payload == null) {
      throw Exception('initiateCall: bad response');
    }

    final parsed = _parseCallerEndpoint(
      payload,
      'internalCallerParams',
      context: 'initiateCall',
    );

    return OutgoingCallParams(
      conversationId: (payload['conversationId'] as String?) ?? conversationId,
      endpoint: parsed.endpoint,
      callsUserId: parsed.callsUserId,
      peerExternalId: parsed.external ?? calleeId,
      isVideo: isVideo,
    );
  }

  String _internalParams() => jsonEncode({
    'platform': 'ANDROID',
    'sdkVersion': '0.1.16.4',
    'clientAppKey': 'CGPGAGLGDIHBABABA',
    'deviceId': _api.deviceId ?? '',
    'protocolVersion': 5,
    'onlyAdminCanRecord': false,
    'waitForAdmin': false,
    'capabilities': '3c03f',
  });

  Future<CallLinkPreview?> resolveCallLink(String url) async {
    final payload = await _api.sendRequestMap(Opcode.linkInfo, {'link': url});
    if (payload == null) return null;

    final vc = payload['videoConference'];
    if (vc is! Map) return null;

    return CallLinkPreview(
      conferenceId: vc['conferenceId']?.toString(),
      callName: (vc['callName'] as String?)?.trim(),
      participantsCount: (vc['participantsCount'] as int?) ?? 0,
      isVideo: vc['callType'] == 'VIDEO',
    );
  }

  Future<OutgoingCallParams> joinByLink(
    String token, {
    bool isVideo = false,
  }) async {
    final payload = await _api.sendRequestMap(Opcode.videoChatJoinByLink, {
      'joinLink': token,
      'internalParams': _internalParams(),
      'isVideo': isVideo,
    });

    if (payload == null) {
      throw Exception('joinByLink: bad response');
    }

    final parsed = _parseCallerEndpoint(
      payload,
      'internalParams',
      context: 'joinByLink',
    );

    return OutgoingCallParams(
      conversationId: (payload['conversationId'] as String?) ?? '',
      endpoint: parsed.endpoint,
      callsUserId: parsed.callsUserId,
      peerExternalId: 0,
      isVideo: isVideo,
    );
  }

  Future<List<CallLogEntry>> fetchHistory(
    int accountId,
    int currentUserId,
  ) async {
    final payload = await _api.sendRequestMap(Opcode.videoChatHistory, {});
    if (payload == null) return [];

    return parseHistoryPayload(
      payload,
      accountId,
      currentUserId,
      resolver: resolveContacts,
    );
  }

  Future<Map<int, Map<String, dynamic>>> resolveContacts(List<int> ids) async {
    if (ids.isEmpty) return const {};
    final out = <int, Map<String, dynamic>>{};
    try {
      final resp = await _api.sendRequest(Opcode.contactInfo, {
        'contactIds': ids,
      });
      final data = resp.payload;
      final contacts = data is Map ? data['contacts'] : null;
      if (contacts is List) {
        for (final c in contacts) {
          if (c is Map) {
            final id = c['id'];
            if (id is int) out[id] = Map<String, dynamic>.from(c);
          }
        }
      }
    } catch (e) {
      logger.w('resolveContacts: $e');
    }
    return out;
  }

  Future<bool> deleteHistory(List<int> historyIds) async {
    if (historyIds.isEmpty) return true;
    return _api.sendRequestOk(Opcode.videoChatDeleteHistory, {
      'historyIds': historyIds,
    });
  }

  static Future<List<CallLogEntry>> parseHistoryPayload(
    Map<dynamic, dynamic> payload,
    int accountId,
    int currentUserId, {
    Future<Map<int, Map<String, dynamic>>> Function(List<int> ids)? resolver,
  }) async {
    final history = payload['history'];
    if (history is! List || history.isEmpty) return [];

    final recentContacts = await ContactsModule.getContacts(accountId);
    final contactsMap = {for (final c in recentContacts) c.id: c};

    final parsed = <({int peerId, CallStatus status, int time, String id})>[];

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

      parsed.add((
        peerId: peerId,
        status: _parseCallStatus(callAttach, isOutgoing),
        time: (msg['time'] as int?) ?? 0,
        id:
            msg['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
      ));
    }

    bool localResolved(int id) {
      final c = contactsMap[id];
      return c != null && c.firstName.isNotEmpty;
    }

    final unresolvedIds = parsed
        .map((e) => e.peerId)
        .where((id) => id != 0 && !localResolved(id))
        .toSet()
        .toList();

    var fetched = const <int, Map<String, dynamic>>{};
    if (unresolvedIds.isNotEmpty && resolver != null) {
      fetched = await resolver(unresolvedIds);
    }

    final List<CallLogEntry> extractedCalls = [];
    for (final e in parsed) {
      final contact = contactsMap[e.peerId];
      String name;
      String? avatarUrl;
      bool isGroup = false;
      if (contact != null && contact.firstName.isNotEmpty) {
        name = '${contact.firstName} ${contact.lastName ?? ''}'.trim();
        avatarUrl = contact.baseUrl;
      } else {
        final info = fetched[e.peerId];
        final resolved = _nameFromInfo(info);
        if (resolved != null) {
          name = resolved;
          avatarUrl = (info?['baseUrl'] as String?) ?? contact?.baseUrl;
        } else {
          name = 'Групповой звонок';
          isGroup = true;
        }
      }

      extractedCalls.add(
        CallLogEntry(
          id: e.id,
          accountId: accountId,
          peerId: e.peerId,
          name: name,
          avatarUrl: avatarUrl,
          status: e.status,
          time: e.time,
          isGroup: isGroup,
        ),
      );
    }

    return extractedCalls;
  }

  static String? _nameFromInfo(Map<String, dynamic>? info) {
    if (info == null) return null;
    final names = info['names'];
    if (names is List && names.isNotEmpty) {
      final n = names.first;
      if (n is Map) {
        final full = n['name']?.toString();
        if (full != null && full.isNotEmpty) return full;
        final first = n['firstName']?.toString() ?? '';
        final last = n['lastName']?.toString() ?? '';
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) return combined;
      }
    }
    return null;
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

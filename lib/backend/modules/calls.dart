import 'dart:convert';

import 'contacts.dart';
import 'messages.dart' show ContactCache;
import '../api.dart';
import '../../core/cache/info_cache.dart';
import '../../core/calls/call_link.dart';
import '../../core/calls/ws2_signaling.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/logger.dart';
import '../../models/contact_info.dart';

// #***! как звонок выглядит в истории
enum CallStatus { missed, canceled, outgoing, incoming }

// #***! всё для медиа сессии, адрес сервера звонков и наши id
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

// #***! созданная конференция
class CreatedCall {
  final String conversationId;
  final String joinToken;
  final String? callName;
  final int? chatId;

  const CreatedCall({
    required this.conversationId,
    required this.joinToken,
    this.callName,
    this.chatId,
  });

  String get url => CallLink.url(joinToken);
}

// #***! превью звонка по ссылке до входа
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

// #***! строка в журнале звонков
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
  final bool isBot;
  final List<String> ids;

  CallLogEntry({
    required this.id,
    required this.accountId,
    required this.peerId,
    required this.name,
    this.avatarUrl,
    required this.status,
    required this.time,
    this.count = 1,
    this.isGroup = false,
    this.isBot = false,
    List<String>? ids,
  }) : ids = ids ?? [id];

  bool get canCallBack => !isGroup && !isBot;

  CallLogEntry mergedWith(CallLogEntry other) => CallLogEntry(
    id: id,
    accountId: accountId,
    peerId: peerId,
    name: name,
    avatarUrl: avatarUrl,
    status: status,
    time: time,
    count: count + 1,
    isGroup: isGroup,
    isBot: isBot,
    ids: [...ids, ...other.ids],
  );
}

class CallPeerIsBotException implements Exception {
  final int peerId;

  const CallPeerIsBotException(this.peerId);

  @override
  String toString() => 'CallPeerIsBotException: $peerId';
}

class _CallerEndpointMissingException implements Exception {
  final String message;

  const _CallerEndpointMissingException(this.message);

  @override
  String toString() => 'Exception: $message';
}

typedef _CallerEndpoint = ({String endpoint, int callsUserId, int? external});

// #***! сигналка звонков, сама медиа сессия в core/calls
class CallsModule {
  final Api _api;

  CallsModule(this._api);

  // #***! адрес спрятан в джейсон строке внутри ответа и поле зовётся по разному
  _CallerEndpoint _parseCallerEndpoint(
    Map payload,
    List<String> keys, {
    required String context,
  }) {
    for (final key in keys) {
      final raw = payload[key];
      final parsed = raw is String
          ? jsonDecode(raw) as Map<dynamic, dynamic>
          : const <dynamic, dynamic>{};

      final endpoint = parsed['endpoint'] as String?;
      if (endpoint == null) continue;

      final id = parsed['id'];
      final callsUserId = (id is Map ? id['internal'] as int? : null) ?? 0;
      final external = id is Map ? int.tryParse('${id['external']}') : null;

      return (endpoint: endpoint, callsUserId: callsUserId, external: external);
    }

    throw _CallerEndpointMissingException('$context: no endpoint');
  }

  // #***! личный звонок
  Future<OutgoingCallParams> initiateCall(
    int calleeId, {
    bool isVideo = false,
  }) async {
    if (await _isBotPeer(calleeId)) throw CallPeerIsBotException(calleeId);

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

    final parsed = _parseCallerEndpoint(payload, const [
      'internalCallerParams',
    ], context: 'initiateCall');

    return OutgoingCallParams(
      conversationId: (payload['conversationId'] as String?) ?? conversationId,
      endpoint: parsed.endpoint,
      callsUserId: parsed.callsUserId,
      peerExternalId: parsed.external ?? calleeId,
      isVideo: isVideo,
    );
  }

  static Future<bool> _isBotPeer(int userId) async {
    if (_isCachedBot(userId)) return true;
    final info = await ContactInfoFetch.get(userId);
    return info?.isBot ?? false;
  }

  static bool _isCachedBot(int userId) =>
      (ContactCache.getOptions(userId)?.contains('BOT') ?? false) ||
      (ContactInfoFetch.peek(userId)?.isBot ?? false);

  // #***! конференция со ссылкой
  Future<CreatedCall> createConference() async {
    final conversationId = uuidV4();
    logger.i('[call] VIDEO_CHAT_START conv=$conversationId');

    final payload = await _api.sendRequestMap(Opcode.videoChatStart, {
      'conversationId': conversationId,
    });
    logger.i('[call] VIDEO_CHAT_START keys=${payload?.keys.toList()}');

    if (payload == null) {
      throw Exception('createConference: bad response');
    }

    final id = (payload['conversationId'] as String?) ?? conversationId;
    final rawLink =
        (payload['joinLink'] as String?) ?? await createJoinLink(id) ?? '';
    final token = CallLink.normalizeToken(rawLink);
    if (token == null) {
      throw Exception('createConference: no joinLink');
    }

    final name = (payload['callName'] as String?)?.trim();

    return CreatedCall(
      conversationId: id,
      joinToken: token,
      callName: (name?.isEmpty ?? true) ? null : name,
      chatId: payload['chatId'] is int ? payload['chatId'] as int : null,
    );
  }

  // #***! отдельный запрос ссылки если сервер не отдал сразу
  Future<String?> createJoinLink(String conversationId) async {
    if (conversationId.isEmpty) return null;

    final payload = await _api.sendRequestMap(Opcode.videoChatCreateJoinLink, {
      'conversationId': conversationId,
    });

    final link = payload?['joinLink'];
    return link is String && link.isNotEmpty ? link : null;
  }

  // #***! представляемся официальным SDK, свои значения не принимает
  String _internalParams() => jsonEncode({
    'platform': 'ANDROID',
    'sdkVersion': '0.2.1.3',
    'clientAppKey': 'CGPGAGLGDIHBABABA',
    'deviceId': _api.deviceId ?? '',
    'protocolVersion': 5,
    'onlyAdminCanRecord': false,
    'isWaitForAdminEnabled': false,
    'hexCapability': Ws2Config.defaultCapabilities,
  });

  // #***! разбор ссылки до входа, имя и сколько внутри
  Future<CallLinkPreview?> resolveCallLink(String url) async {
    final token = CallLink.normalizeToken(url);
    final payload = await _api.sendRequestMap(Opcode.linkInfo, {
      'link': token == null ? url : CallLink.path(token),
    });
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

  // #***! вход по ссылке, поле с параметрами зовётся иначе
  Future<OutgoingCallParams> joinByLink(
    String token, {
    bool isVideo = false,
  }) async {
    logger.i('[call] VIDEO_CHAT_JOIN link=$token isVideo=$isVideo');
    final payload = await _api.sendRequestMap(Opcode.videoChatJoinByLink, {
      'joinLink': token,
      'internalParams': _internalParams(),
      'isVideo': isVideo,
    });
    logger.i('[call] VIDEO_CHAT_JOIN keys=${payload?.keys.toList()}');

    if (payload == null) {
      throw Exception('joinByLink: bad response');
    }

    final parsed = _parseCallerEndpoint(payload, const [
      'internalParams',
      'internalCallerParams',
    ], context: 'joinByLink');

    return OutgoingCallParams(
      conversationId: (payload['conversationId'] as String?) ?? '',
      endpoint: parsed.endpoint,
      callsUserId: parsed.callsUserId,
      peerExternalId: 0,
      isVideo: isVideo,
    );
  }

  // #***! журнал звонков
  Future<List<CallLogEntry>> fetchHistory(
    int accountId,
    int currentUserId,
  ) async {
    final payload = await _api.sendRequestMap(Opcode.callHistorySync, {
      'callHistorySync': 0,
    });
    if (payload == null) return [];

    final items = payload['callHistoryItems'];
    if (items is! List) return [];
    return _entriesFromItems(
      items.whereType<Map>().toList(),
      accountId,
      currentUserId,
      resolver: resolveContacts,
    );
  }

  // #***! имена тех кого нет в контактах
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

  // #***! разбор истории, запись это сообщение с вложением CALL
  Future<List<CallLogEntry>> _entriesFromItems(
    List<Map> items,
    int accountId,
    int currentUserId, {
    Future<Map<int, Map<String, dynamic>>> Function(List<int> ids)? resolver,
  }) async {

    final recentContacts = await ContactsModule.getContacts(accountId);
    final contactsMap = {for (final c in recentContacts) c.id: c};






      // #***! у исходящего собеседник в contactIds, у входящего отправитель
    int peerOf(Map item) {
      final isOutgoing = item['callerId'] == currentUserId;
      return isOutgoing
          ? ((item['chatId'] as int?) ?? 0) ^ currentUserId
          : (item['callerId'] as int?) ?? 0;
    }

    // #***! на сервер идём только за теми кого нет локально
    bool isGroupItem(Map item) =>
        ((item['chatId'] as int?) ?? 0) < 0 || item['callName'] != null;

    bool localResolved(int id) {
      final c = contactsMap[id];
      return c != null && c.firstName.isNotEmpty;
    }

    final unresolvedIds = items
        .where((item) => !isGroupItem(item))
        .map(peerOf)
        .where((id) => id != 0 && !localResolved(id))
        .toSet()
        .toList();

    var fetched = const <int, Map<String, dynamic>>{};
    if (unresolvedIds.isNotEmpty && resolver != null) {
      fetched = await resolver(unresolvedIds);
    }

    final entries = <CallLogEntry>[];
    for (final item in items) {
      final historyId = item['historyId'];
      if (historyId == null) continue;
      final isOutgoing = item['callerId'] == currentUserId;
      final isGroup = isGroupItem(item);
      final peerId = isGroup ? 0 : peerOf(item);
      final contact = contactsMap[peerId];
      final info = fetched[peerId];

      String name;
      String? avatarUrl;
      if (isGroup) {
        name = (item['callName'] as String?) ?? 'Групповой звонок';
      } else if (contact != null && contact.firstName.isNotEmpty) {
        name = '${contact.firstName} ${contact.lastName ?? ''}'.trim();
        avatarUrl = contact.baseUrl;
      } else {
          // #***! имя не нашлось, значит групповой
        name = _nameFromInfo(info) ?? '$peerId';
        avatarUrl = (info?['baseUrl'] as String?) ?? contact?.baseUrl;
      }

      final duration = ((item['durationMs'] as int?) ?? 0) ~/ 1000;
      entries.add(
        CallLogEntry(
          id: historyId.toString(),
          accountId: accountId,
          peerId: peerId,
          name: name,
          avatarUrl: avatarUrl,
          status: _parseCallStatus({
            'hangupType': item['hangupType'],
            'duration': duration,
          }, isOutgoing),
          time: (item['time'] as int?) ?? 0,
          isGroup: isGroup,
          isBot: !isGroup && _isHistoryPeerBot(peerId, contact, info),
        ),
      );
    }
    return entries;
  }

  static bool _isHistoryPeerBot(
    int peerId,
    CachedContact? contact,
    Map<String, dynamic>? info,
  ) =>
      (contact?.isBot ?? false) ||
      (info != null && ContactInfo.fromMap(info).isBot) ||
      _isCachedBot(peerId);

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

  // #***! статус из направления, типа сброса и длительности
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

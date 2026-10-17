import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/shared_content.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/models/attachment.dart';

const _chat = 909;
const _base = 1700000000000;

class _MediaApi extends Api {
  final pages = <List<Map<String, dynamic>>>[];
  int total = 0;
  final requests = <Map<dynamic, dynamic>>[];

  @override
  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
    void Function()? beforeSend,
  }) async {
    requests.add(payload);
    final page = pages.isEmpty
        ? const <Map<String, dynamic>>[]
        : pages.removeAt(0);
    return Packet(
      cmd: CmdType.ok,
      opcode: opcode,
      payload: {'messages': page, 'total': total},
    );
  }
}

Map<String, dynamic> _photo(int id) => {
  '_type': 'PHOTO',
  'photoId': id,
  'baseUrl': 'https://example.test/photo/$id',
};

Map<String, dynamic> _post(
  int id,
  int at, {
  List<Map<String, dynamic>>? attaches,
}) => {
  'id': id,
  'time': _base + at * 1000,
  'sender': 202,
  'text': 'Synthetic post $id',
  'attaches': attaches ?? [_photo(id * 10)],
};

Map<String, dynamic> _forward(int id, int at, int photoId) => {
  'id': id,
  'time': _base + at * 1000,
  'sender': 303,
  'attaches': const [],
  'link': {
    'type': 'FORWARD',
    'chatId': 404,
    'message': {
      'id': 77,
      'sender': 505,
      'time': _base,
      'text': 'Synthetic original caption',
      'attaches': [_photo(photoId)],
    },
  },
};

void main() {
  late _MediaApi api;
  late SharedContentModule module;

  setUp(() {
    SharedContentModule.clearMediaIndex();
    api = _MediaApi();
    module = SharedContentModule(api);
  });

  tearDown(() => api.dispose());

  test('a forwarded post counts as media of the chat it was sent to', () async {
    api.total = 3;
    api.pages.add([_post(3, 3), _forward(2, 2, 900), _post(1, 1)]);

    final page = await module.fetchMedia(
      chatId: _chat,
      anchorMessageId: '3',
      attachTypes: const ['PHOTO', 'VIDEO'],
    );

    final forwarded = page.items.singleWhere((i) => i.messageId == '2');
    expect(forwarded.chatId, _chat);
    expect(forwarded.senderId, 303);
    expect(forwarded.time, _base + 2000);
    expect(forwarded.text, 'Synthetic original caption');
    expect((forwarded.attachment as PhotoAttachment).photoId, 900);
    expect(
      forwarded.dedupKey,
      mediaDedupKey('2', const PhotoAttachment(photoId: 900)),
    );
  });

  test('the feed finds a forwarded photo on the first page', () async {
    api.total = 3;
    api.pages.add([_post(3, 3), _forward(2, 2, 900), _post(1, 1)]);

    final feed = await module.mediaFeedFor(
      chatId: _chat,
      mediaKey: mediaDedupKey('2', const PhotoAttachment(photoId: 900)),
      mediaTime: _base + 2000,
      resolveAnchor: () async => '3',
    );

    expect(feed, isNotNull);
    expect(feed!.items.map((i) => i.messageId), ['3', '2', '1']);
    expect(api.requests, hasLength(1));
  });

  test('the feed stops once it has paged past a missing item', () async {
    api.total = 200;
    api.pages
      ..add([for (var i = 60; i > 30; i--) _post(i, i)])
      ..add([for (var i = 30; i > 0; i--) _post(i, i)])
      ..add([_post(0, 0)]);

    final feed = await module.mediaFeedFor(
      chatId: _chat,
      mediaKey: mediaDedupKey('999', const PhotoAttachment(photoId: 1)),
      mediaTime: _base + 20 * 1000,
      resolveAnchor: () async => '60',
    );

    expect(feed, isNotNull);
    expect(feed!.reachedEnd, isFalse);
    expect(api.requests, hasLength(2));
  });

  test('media newer than the cached feed rebuilds it', () async {
    api.total = 2;
    api.pages.add([_post(2, 2), _post(1, 1)]);
    await module.mediaFeedFor(
      chatId: _chat,
      mediaKey: mediaDedupKey('2', const PhotoAttachment(photoId: 20)),
      mediaTime: _base + 2000,
      resolveAnchor: () async => '2',
    );

    api.total = 3;
    api.pages.add([_post(3, 3), _post(2, 2), _post(1, 1)]);
    final feed = await module.mediaFeedFor(
      chatId: _chat,
      mediaKey: mediaDedupKey('3', const PhotoAttachment(photoId: 30)),
      mediaTime: _base + 3000,
      resolveAnchor: () async => '3',
    );

    expect(feed!.items.map((i) => i.messageId), ['3', '2', '1']);
    expect(feed.total, 3);
  });
}

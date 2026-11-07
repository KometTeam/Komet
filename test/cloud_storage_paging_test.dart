import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/cloud_storage.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/models/attachment.dart';

const int _account = 900001;
const int _chat = -900201;

class _SyntheticHistory extends MessagesModule {
  _SyntheticHistory(this.times) : super(Api());

  final List<int> times;

  @override
  Future<List<CachedMessage>> fetchHistory(
    int accountId,
    int chatId, {
    int? fromTime,
    int count = 50,
    int forward = 0,
    int? backward,
  }) async {
    final upTo = fromTime ?? 1 << 50;
    final window = [
      for (final t in times)
        if (t <= upTo) t,
    ];
    final start = window.length > count ? window.length - count : 0;
    return [
      for (final t in window.sublist(start))
        CachedMessage(
          id: '$t',
          accountId: accountId,
          chatId: chatId,
          senderId: accountId,
          time: t,
          attachments: [FileAttachment(fileId: t, name: 'synthetic_$t.bin')],
        ),
    ];
  }
}

void main() {
  test('pages walk back through the whole storage without repeats', () async {
    final history = _SyntheticHistory([for (var t = 1; t <= 250; t++) t]);
    final seen = <int>[];
    int? before;
    var pages = 0;
    while (true) {
      final page = await CloudStorageModule.fetchPage(
        history,
        _account,
        _chat,
        before: before,
      );
      if (page.oldestTime == null) break;
      seen.addAll(page.files.map((f) => f.fileId!));
      before = page.oldestTime;
      pages++;
    }
    expect(pages, 3);
    expect(seen, [for (var t = 250; t >= 1; t--) t]);
  });

  test('an empty storage reports no older page', () async {
    final page = await CloudStorageModule.fetchPage(
      _SyntheticHistory(const []),
      _account,
      _chat,
    );
    expect(page.files, isEmpty);
    expect(page.oldestTime, isNull);
  });
}

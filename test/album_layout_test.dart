import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/shared_content.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/album_layout.dart';
import 'package:komet/models/attachment.dart';

SharedMediaItem _item(String messageId, int time, int photoId) =>
    SharedMediaItem(
      messageId: messageId,
      chatId: 1,
      senderId: 2,
      time: time,
      attachment: PhotoAttachment(photoId: photoId),
    );

void main() {
  group('AlbumLayout.rows', () {
    test('nine square photos form a 3×3 collage', () {
      expect(AlbumLayout.rows(List.filled(9, 1.0)), [3, 3, 3]);
    });

    test('four photos form two rows of two', () {
      expect(AlbumLayout.rows(List.filled(4, 1.0)), [2, 2]);
    });

    test('landscape photos go two per row', () {
      expect(AlbumLayout.rows(List.filled(6, 1.6)), [2, 2, 2]);
    });

    test('every row holds two or three tiles and covers the album', () {
      const mixed = [1.6, 0.6, 1.0, 0.75, 1.6, 0.6, 1.0, 1.6, 0.75, 1.0];
      for (var count = 4; count <= mixed.length; count++) {
        final rows = AlbumLayout.rows(mixed.sublist(0, count));
        expect(rows.fold<int>(0, (sum, row) => sum + row), count);
        expect(rows.every((row) => row == 2 || row == 3), isTrue);
      }
    });
  });

  test('media feed keeps album order when photos share a timestamp', () {
    final items = [
      for (var i = 0; i < 40; i++) _item('old$i', 1000 + i, 500 + i),
      _item('album', 5000, 1),
      _item('album', 5000, 2),
      _item('album', 5000, 3),
    ];

    sortMediaNewestFirst(items);

    final album = items.where((item) => item.messageId == 'album').toList();
    expect(items.take(3).every((item) => item.messageId == 'album'), isTrue);
    expect(
      [for (final item in album) (item.attachment as PhotoAttachment).photoId],
      [1, 2, 3],
    );
  });
}

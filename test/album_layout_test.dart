import 'dart:ui';

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
    test('ten square photos grow from pairs to triples', () {
      expect(AlbumLayout.rows(List.filled(10, 1.0)), [2, 2, 3, 3]);
    });

    test('rows never hold more than four tiles', () {
      for (var count = 2; count <= AlbumLayout.maxTiles; count++) {
        final rows = AlbumLayout.rows(List.filled(count, 0.7), narrow: true);
        expect(rows.fold<int>(0, (sum, row) => sum + row), count);
        expect(rows.every((row) => row >= 1 && row <= 4), isTrue);
      }
    });
  });

  group('AlbumLayout.layout', () {
    const mixed = [1.78, 0.56, 1.0, 0.75, 1.33, 3.2, 0.5, 1.6, 0.8, 1.0];

    Rect bounds(List<Rect> tiles) =>
        tiles.reduce((a, b) => a.expandToInclude(b));

    double area(Rect rect) => rect.width * rect.height;

    test('tiles cover the album without overlapping', () {
      for (var count = 2; count <= mixed.length; count++) {
        for (final ratios in [
          mixed.sublist(0, count),
          mixed.reversed.take(count).toList(),
          List.filled(count, 0.6),
          List.filled(count, 1.9),
        ]) {
          final grid = AlbumLayout.layout(ratios);
          expect(grid.tiles, hasLength(count));
          expect(grid.aspectRatio, greaterThan(0));

          final box = bounds(grid.tiles);
          expect(box.left, closeTo(0, 1e-9));
          expect(box.top, closeTo(0, 1e-9));
          expect(box.right, closeTo(1, 1e-9));
          expect(box.bottom, closeTo(1, 1e-9));

          final covered = grid.tiles.fold<double>(0, (sum, t) => sum + area(t));
          expect(covered, closeTo(1, 1e-6), reason: '$ratios');

          for (var i = 0; i < count; i++) {
            expect(grid.tiles[i].width, greaterThan(0));
            expect(grid.tiles[i].height, greaterThan(0));
            for (var j = i + 1; j < count; j++) {
              final overlap = grid.tiles[i].intersect(grid.tiles[j]);
              final overlaps = overlap.width > 1e-9 && overlap.height > 1e-9;
              expect(overlaps, isFalse, reason: '$ratios: $i and $j');
            }
          }
        }
      }
    });

    test('a tall photo among three spans the full height on the left', () {
      final grid = AlbumLayout.layout([0.6, 1.0, 1.0]);
      expect(grid.tiles[0].left, 0);
      expect(grid.tiles[0].top, 0);
      expect(grid.tiles[0].bottom, closeTo(1, 1e-9));
      expect(grid.tiles[1].left, grid.tiles[0].right);
      expect(grid.tiles[2].left, grid.tiles[0].right);
      expect(grid.tiles[2].top, grid.tiles[1].bottom);
    });

    test('a wide first photo of four sits above a row of three', () {
      final grid = AlbumLayout.layout([1.6, 1.0, 1.0, 1.0]);
      expect(grid.tiles[0].width, closeTo(1, 1e-9));
      for (final tile in grid.tiles.skip(1)) {
        expect(tile.top, grid.tiles[0].bottom);
      }
    });

    test('unknown sizes fall back to squares', () {
      final grid = AlbumLayout.layout([0, double.nan, 1]);
      expect(grid.tiles, hasLength(3));
      expect(grid.aspectRatio.isFinite, isTrue);
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

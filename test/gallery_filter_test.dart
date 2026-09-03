import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/gallery_source.dart';
import 'package:photo_manager/photo_manager.dart';

const int _minInt32 = -0x80000000;
const int _maxInt32 = 0x7fffffff;

void main() {
  test('длительности в фильтре галереи влезают в int32 миллисекунд', () {
    final filter = GallerySource.mediaFilter();

    for (final type in [AssetType.image, AssetType.video, AssetType.audio]) {
      final duration = filter.getOption(type).durationConstraint.toMap();

      expect(
        duration['min'],
        inInclusiveRange(_minInt32, _maxInt32),
        reason: 'min для $type',
      );
      expect(
        duration['max'],
        inInclusiveRange(_minInt32, _maxInt32),
        reason: 'max для $type',
      );
    }
  });

  test('размеры в фильтре галереи влезают в int32', () {
    final filter = GallerySource.mediaFilter();

    for (final type in [AssetType.image, AssetType.video, AssetType.audio]) {
      final size = filter.getOption(type).sizeConstraint.toMap();

      for (final entry in size.entries) {
        final value = entry.value;
        if (value is! int) continue;
        expect(
          value,
          inInclusiveRange(_minInt32, _maxInt32),
          reason: '${entry.key} для $type',
        );
      }
    }
  });

  test('фильтр пропускает видео любой разумной длины', () {
    final video = GallerySource.mediaFilter().getOption(AssetType.video);

    expect(video.sizeConstraint.ignoreSize, isTrue);
    expect(video.durationConstraint.allowNullable, isTrue);
    expect(
      video.durationConstraint.max,
      greaterThan(const Duration(hours: 24)),
    );
  });

  test('фильтр не режет фото по размеру и дате создания', () {
    final filter = GallerySource.mediaFilter();

    expect(filter.getOption(AssetType.image).sizeConstraint.ignoreSize, isTrue);
    expect(filter.createTimeCond.ignore, isTrue);
  });
}

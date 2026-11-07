import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:komet/core/media/audio_file_metadata.dart';
import 'package:komet/core/utils/media_cache.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reads title, artist, album and embedded cover from an audio file',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'synthetic_audio_metadata',
      );
      addTearDown(() {
        AudioFileMetadata.resetForTesting();
        MediaCache.resetForTesting();
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
      MediaCache.resetForTesting();
      AudioFileMetadata.resetForTesting();

      final metadata = await AudioFileMetadata.read(
        File('test/fixtures/audio_metadata.mp3'),
        cacheName: 'synthetic-audio.mp3',
      );

      expect(metadata, isNotNull);
      expect(metadata!.title, 'Synthetic Track');
      expect(metadata.artist, 'Synthetic Artist');
      expect(metadata.album, 'Synthetic Album');
      expect(metadata.artworkUri, isNotNull);
      final artwork = File.fromUri(metadata.artworkUri!);
      expect(await artwork.exists(), isTrue);
      final decoded = img.decodeImage(await artwork.readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width, 160);
      expect(decoded.height, 160);
      expect(AudioFileMetadata.parseCountForTesting, 1);

      await File(
        'test/fixtures/audio_metadata.mp3',
      ).setLastModified(DateTime.now().add(const Duration(seconds: 1)));
      AudioFileMetadata.resetMemoryForTesting();
      final cached = await AudioFileMetadata.read(
        File('test/fixtures/audio_metadata.mp3'),
        cacheName: 'synthetic-audio.mp3',
      );
      expect(cached?.title, 'Synthetic Track');
      expect(cached?.artworkUri, metadata.artworkUri);
      expect(AudioFileMetadata.parseCountForTesting, 1);
    },
  );
}

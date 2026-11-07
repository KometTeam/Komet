import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../utils/media_cache.dart';
import 'audio_file_track.dart';

class AudioFileMetadataInfo {
  const AudioFileMetadataInfo({
    this.title,
    this.artist,
    this.album,
    this.artworkUri,
  });

  final String? title;
  final String? artist;
  final String? album;
  final Uri? artworkUri;
}

abstract final class AudioFileMetadata {
  static const int _cacheVersion = 2;
  static const int _artworkMaxEdge = 160;
  static final Map<String, Future<AudioFileMetadataInfo?>> _cache = {};
  static int _parseCount = 0;

  static Future<AudioFileMetadataInfo?> read(
    File file, {
    required String cacheName,
  }) async {
    try {
      final stat = await file.stat();
      final key = '${file.path}:${stat.size}';
      return await _cache.putIfAbsent(key, () => _read(file, cacheName, stat));
    } catch (_) {
      return null;
    }
  }

  static Future<AudioFileTrack> enrich(AudioFileTrack track) async {
    final metadata = await read(File(track.path), cacheName: track.cacheName);
    if (metadata == null) return track;
    final source = _text(metadata.artist) ?? _text(metadata.album);
    return track.copyWith(
      name: _text(metadata.title) ?? track.name,
      sourceName: source ?? track.sourceName,
      thumbnailUrl: metadata.artworkUri?.toString() ?? track.thumbnailUrl,
    );
  }

  @visibleForTesting
  static int get parseCountForTesting => _parseCount;

  @visibleForTesting
  static void resetMemoryForTesting() => _cache.clear();

  @visibleForTesting
  static void resetForTesting() {
    _cache.clear();
    _parseCount = 0;
  }

  static Future<AudioFileMetadataInfo?> _read(
    File file,
    String cacheName,
    FileStat stat,
  ) async {
    final digest = sha1.convert(utf8.encode(cacheName)).toString();
    final metadataFile = await MediaCache.fileFor('audiometa_$digest.json');
    final artworkFile = await MediaCache.fileFor('audioart_$digest.jpg');
    final cached = await _readDiskCache(metadataFile, artworkFile, stat);
    if (cached != null) return cached;

    _parseCount++;
    final parsed = await Isolate.run(
      () => _parseAudioMetadata(file.path, _artworkMaxEdge),
    );
    final artwork = parsed?.artwork;
    Uri? artworkUri;
    if (artwork != null) {
      await artworkFile.writeAsBytes(
        artwork.materialize().asUint8List(),
        flush: true,
      );
      artworkUri = artworkFile.uri;
    } else if (await artworkFile.exists()) {
      await artworkFile.delete();
    }

    final info = AudioFileMetadataInfo(
      title: _text(parsed?.title),
      artist: _text(parsed?.artist),
      album: _text(parsed?.album),
      artworkUri: artworkUri,
    );
    await metadataFile.writeAsString(
      jsonEncode({
        'version': _cacheVersion,
        'sourceSize': stat.size,
        'title': info.title,
        'artist': info.artist,
        'album': info.album,
        'hasArtwork': artworkUri != null,
      }),
      flush: true,
    );
    return info;
  }

  static Future<AudioFileMetadataInfo?> _readDiskCache(
    File metadataFile,
    File artworkFile,
    FileStat source,
  ) async {
    if (!await metadataFile.exists()) return null;
    try {
      final decoded = jsonDecode(await metadataFile.readAsString());
      if (decoded is! Map) return null;
      if (decoded['version'] != _cacheVersion ||
          decoded['sourceSize'] != source.size) {
        return null;
      }
      final hasArtwork = decoded['hasArtwork'] == true;
      if (hasArtwork && !await artworkFile.exists()) return null;
      return AudioFileMetadataInfo(
        title: _text(decoded['title']?.toString()),
        artist: _text(decoded['artist']?.toString()),
        album: _text(decoded['album']?.toString()),
        artworkUri: hasArtwork ? artworkFile.uri : null,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _text(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

({
  String? title,
  String? artist,
  String? album,
  TransferableTypedData? artwork,
})?
_parseAudioMetadata(String path, int artworkMaxEdge) {
  try {
    final metadata = readMetadata(File(path), getImage: true);
    Picture? picture;
    for (final candidate in metadata.pictures) {
      if (candidate.pictureType == PictureType.coverFront) {
        picture = candidate;
        break;
      }
      picture ??= candidate;
    }

    TransferableTypedData? artwork;
    if (picture != null && picture.bytes.isNotEmpty) {
      final decoded = img.decodeImage(picture.bytes);
      if (decoded != null) {
        final resized =
            decoded.width <= artworkMaxEdge && decoded.height <= artworkMaxEdge
            ? decoded
            : decoded.width >= decoded.height
            ? img.copyResize(
                decoded,
                width: artworkMaxEdge,
                interpolation: img.Interpolation.average,
              )
            : img.copyResize(
                decoded,
                height: artworkMaxEdge,
                interpolation: img.Interpolation.average,
              );
        artwork = TransferableTypedData.fromList([
          img.encodeJpg(resized, quality: 82),
        ]);
      }
    }

    return (
      title: metadata.title,
      artist: metadata.artist ?? metadata.albumArtist,
      album: metadata.album,
      artwork: artwork,
    );
  } catch (_) {
    return null;
  }
}

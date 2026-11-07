import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

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
  static final Map<String, Future<AudioFileMetadataInfo?>> _cache = {};

  static Future<AudioFileMetadataInfo?> read(
    File file, {
    required String cacheName,
  }) async {
    try {
      final stat = await file.stat();
      final key =
          '${file.path}:${stat.size}:${stat.modified.millisecondsSinceEpoch}';
      return await _cache.putIfAbsent(key, () => _read(file, cacheName));
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
  static void resetForTesting() => _cache.clear();

  static Future<AudioFileMetadataInfo?> _read(
    File file,
    String cacheName,
  ) async {
    final parsed = await Isolate.run(() => _parseAudioMetadata(file.path));
    if (parsed == null) return null;

    Uri? artworkUri;
    final artwork = parsed.artwork;
    if (artwork != null) {
      final extension = _artworkExtension(parsed.artworkMime);
      final digest = sha1.convert(utf8.encode(cacheName)).toString();
      final target = await MediaCache.fileFor('audioart_$digest.$extension');
      await target.writeAsBytes(
        artwork.materialize().asUint8List(),
        flush: true,
      );
      artworkUri = target.uri;
    }

    return AudioFileMetadataInfo(
      title: _text(parsed.title),
      artist: _text(parsed.artist),
      album: _text(parsed.album),
      artworkUri: artworkUri,
    );
  }

  static String _artworkExtension(String? mime) => switch (mime) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };

  static String? _text(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

({
  String? title,
  String? artist,
  String? album,
  String? artworkMime,
  TransferableTypedData? artwork,
})?
_parseAudioMetadata(String path) {
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
    return (
      title: metadata.title,
      artist: metadata.artist ?? metadata.albumArtist,
      album: metadata.album,
      artworkMime: picture?.mimetype.toLowerCase(),
      artwork: picture == null || picture.bytes.isEmpty
          ? null
          : TransferableTypedData.fromList([picture.bytes]),
    );
  } catch (_) {
    return null;
  }
}

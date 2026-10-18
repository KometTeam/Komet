import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../utils/logger.dart';

// #***! чтение MessagePack из ответа
class MsgpackReader {
  final Uint8List _data;
  int _pos = 0;

  MsgpackReader(this._data);

  bool get exhausted => _pos >= _data.length;

  bool get nextIsString {
    final b = _data[_pos];
    return (b & 0xE0) == 0xA0 || b == 0xD9 || b == 0xDA || b == 0xDB;
  }

  int readInt() {
    final b = _data[_pos++];
    if (b < 0x80) return b;
    if (b >= 0xE0) return b - 256;
    switch (b) {
      case 0xCC:
        return _uint(1);
      case 0xCD:
        return _uint(2);
      case 0xCE:
        return _uint(4);
      case 0xCF:
        return _uint(8);
      case 0xD0:
        final v = _uint(1);
        return v >= 0x80 ? v - 0x100 : v;
      case 0xD1:
        final v = _uint(2);
        return v >= 0x8000 ? v - 0x10000 : v;
      case 0xD2:
        final v = _uint(4);
        return v >= 0x80000000 ? v - 0x100000000 : v;
      case 0xD3:
        return _uint(8);
    }
    throw FormatException('не целое: 0x${b.toRadixString(16)}');
  }

  String readString() {
    final b = _data[_pos++];
    int length;
    if ((b & 0xE0) == 0xA0) {
      length = b & 0x1F;
    } else if (b == 0xD9) {
      length = _uint(1);
    } else if (b == 0xDA) {
      length = _uint(2);
    } else if (b == 0xDB) {
      length = _uint(4);
    } else {
      throw FormatException('не строка: 0x${b.toRadixString(16)}');
    }
    final value = utf8.decode(_data.sublist(_pos, _pos + length));
    _pos += length;
    return value;
  }

  int readMapHeader() {
    final b = _data[_pos++];
    if ((b & 0xF0) == 0x80) return b & 0x0F;
    if (b == 0xDE) return _uint(2);
    if (b == 0xDF) return _uint(4);
    throw FormatException('не map: 0x${b.toRadixString(16)}');
  }

  int readArrayHeader() {
    final b = _data[_pos++];
    if ((b & 0xF0) == 0x90) return b & 0x0F;
    if (b == 0xDC) return _uint(2);
    if (b == 0xDD) return _uint(4);
    throw FormatException('не array: 0x${b.toRadixString(16)}');
  }

  int _uint(int bytes) {
    var value = 0;
    for (var i = 0; i < bytes; i++) {
      value = (value << 8) | _data[_pos++];
    }
    return value;
  }
}

// #***! раскладка одного видеоокна
class SfuLayoutItem {
  final String trackKey;
  final int width;
  final int height;
  final bool cover;

  const SfuLayoutItem({
    required this.trackKey,
    this.width = 640,
    this.height = 360,
    this.cover = true,
  });

  String get signalingLayout =>
      'sz=${width}x$height:fit=${cover ? 'cv' : 'cn'}';
}

// #***! уведомления SFU: алиасы ключей дорожек, кто говорит, чьё видео зависло и сеть участников
class SfuNotificationChannel {
  static const String label = 'producerNotification';

  static const int _notifyAliases = 1;
  static const int _notifyAudioActivity = 2;
  static const int _notifyStalled = 4;
  static const int _notifyNetworkStatus = 6;

  // #***! сервер шлёт короткие алиасы вместо ключей треков, держим таблицу
  final Map<int, String> _aliases = {};
  final _activity = StreamController<Set<String>>.broadcast();
  final _stalled = StreamController<Set<String>>.broadcast();
  final _network = StreamController<Map<String, double>>.broadcast();

  Stream<Set<String>> get audioActivity => _activity.stream;
  Stream<Set<String>> get stalledVideo => _stalled.stream;
  Stream<Map<String, double>> get networkStatus => _network.stream;

  void bind(RTCDataChannel channel) {
    if (channel.label != label) return;
    channel.onMessage = _onNotification;
  }

  String? aliasOf(int alias) => _aliases[alias];

  @visibleForTesting
  void debugHandle(RTCDataChannelMessage message) => _onNotification(message);

  void _onNotification(RTCDataChannelMessage message) {
    if (!message.isBinary) return;
    final bytes = message.binary;
    if (bytes.isEmpty) return;
    final type = bytes[0];
    final reader = MsgpackReader(Uint8List.sublistView(bytes, 1));
    try {
      switch (type) {
        case _notifyAliases:
          final count = reader.readMapHeader();
          for (var i = 0; i < count; i++) {
            final key = reader.readString();
            _aliases[reader.readInt()] = key;
          }
          break;
        case _notifyAudioActivity:
          _emit(_activity, _readKeys(reader));
          break;
        case _notifyStalled:
          _emit(_stalled, _readKeys(reader));
          break;
        case _notifyNetworkStatus:
          final count = reader.readMapHeader();
          final statuses = <String, double>{};
          for (var i = 0; i < count; i++) {
            final key = _aliases[reader.readInt()];
            final rating = reader.readInt() / 100;
            if (key != null) statuses[key] = rating;
          }
          _emit(_network, statuses);
          break;
      }
    } catch (e) {
      logger.w('[call][sfu] notify type=$type parse failed: $e');
    }
  }

  Set<String> _readKeys(MsgpackReader reader) {
    final count = reader.readArrayHeader();
    return {for (var i = 0; i < count; i++) ?_aliases[reader.readInt()]};
  }

  void _emit<T>(StreamController<T> controller, T value) {
    if (!controller.isClosed) controller.add(value);
  }

  Future<void> dispose() async {
    _aliases.clear();
    for (final controller in [_activity, _stalled, _network]) {
      if (!controller.isClosed) await controller.close();
    }
  }
}

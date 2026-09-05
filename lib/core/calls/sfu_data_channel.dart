import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../utils/logger.dart';

class MsgpackWriter {
  final BytesBuilder _out = BytesBuilder();

  Uint8List takeBytes() => _out.takeBytes();

  void raw(int byte) => _out.addByte(byte);

  void nil() => raw(0xC0);

  // #***! свой мини MessagePack, сервер SFU принимает команды только в нём
  void boolean(bool value) => raw(value ? 0xC3 : 0xC2);

  void integer(int value) {
    if (value >= 0) {
      if (value < 0x80) return raw(value);
      if (value <= 0xFF) {
        raw(0xCC);
        return raw(value);
      }
      if (value <= 0xFFFF) {
        raw(0xCD);
        return _uint(value, 2);
      }
      if (value <= 0xFFFFFFFF) {
        raw(0xCE);
        return _uint(value, 4);
      }
      raw(0xCF);
      return _uint(value, 8);
    }
    if (value >= -32) return raw(0xE0 | (value + 32));
    if (value >= -128) {
      raw(0xD0);
      return _uint(value & 0xFF, 1);
    }
    if (value >= -32768) {
      raw(0xD1);
      return _uint(value & 0xFFFF, 2);
    }
    if (value >= -2147483648) {
      raw(0xD2);
      return _uint(value & 0xFFFFFFFF, 4);
    }
    raw(0xD3);
    _uint(value, 8);
  }

  void string(String value) {
    final bytes = utf8.encode(value);
    final length = bytes.length;
    if (length < 32) {
      raw(0xA0 | length);
    } else if (length <= 0xFF) {
      raw(0xD9);
      raw(length);
    } else if (length <= 0xFFFF) {
      raw(0xDA);
      _uint(length, 2);
    } else {
      raw(0xDB);
      _uint(length, 4);
    }
    _out.add(bytes);
  }

  void arrayHeader(int length) {
    if (length < 16) return raw(0x90 | length);
    if (length <= 0xFFFF) {
      raw(0xDC);
      return _uint(length, 2);
    }
    raw(0xDD);
    _uint(length, 4);
  }

  void _uint(int value, int bytes) {
    for (var shift = (bytes - 1) * 8; shift >= 0; shift -= 8) {
      raw((value >> shift) & 0xFF);
    }
  }
}

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

  const SfuLayoutItem({
    required this.trackKey,
    this.width = 640,
    this.height = 360,
  });
}

// #***! служебный канал SFU, раскладка слоты и уровни звука
class SfuCommandChannel {
  // #***! коды команд и уведомлений SFU
  static const int _commandDisplayLayout = 0;
  static const int _fitMode = 0;

  static const int _notifyAliases = 1;
  static const int _notifySlots = 2;
  static const int _notifyAudioLevels = 6;

  RTCDataChannel? _command;
  int _sequence = 1;

  // #***! сервер шлёт короткие алиасы вместо ключей треков, держим таблицу
  final Map<int, String> _aliases = {};
  final _slots = StreamController<Map<String, int>>.broadcast();
  final _levels = StreamController<Map<String, int>>.broadcast();

  Stream<Map<String, int>> get slotUpdates => _slots.stream;
  Stream<Map<String, int>> get audioLevels => _levels.stream;

  // #***! привязка к открытому каналу
  void bind(RTCDataChannel channel) {
    if (channel.label == 'producerCommand') {
      _command = channel;
      channel.onMessage = _onCommandReply;
      return;
    }
    if (channel.label != 'producerNotification') return;
    channel.onMessage = _onNotification;
  }

  bool get ready => _command?.state == RTCDataChannelState.RTCDataChannelOpen;

  // #***! говорим серверу какие видео и в каком размере нужны, от этого битрейт
  Future<bool> sendDisplayLayout(
    List<SfuLayoutItem> items, {
    bool snapshot = true,
  }) async {
    final channel = _command;
    if (channel == null) return false;
    if (channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      logger.w('[call][sfu] producerCommand не открыт, слои не отправлены');
      return false;
    }

    final writer = MsgpackWriter()
      ..integer(_commandDisplayLayout)
      ..integer(0)
      ..integer(_sequence++)
      ..boolean(snapshot);

    if (items.isEmpty) {
      writer.nil();
    } else {
      writer.arrayHeader(items.length * 2);
      for (final item in items) {
        writer
          ..string(item.trackKey)
          ..integer(0)
          ..nil()
          ..integer(item.width)
          ..integer(item.height)
          ..integer(_fitMode);
      }
    }
    writer.nil();

    final payload = writer.takeBytes();
    try {
      await channel.send(RTCDataChannelMessage.fromBinary(payload));
      logger.i(
        '[call][sfu] update-display-layout: '
        '${items.map((i) => i.trackKey).join(', ')} '
        'raw=${payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
      return true;
    } catch (e) {
      logger.w('[call][sfu] update-display-layout failed: $e');
      return false;
    }
  }

  // #***! ответ на нашу команду
  void _onCommandReply(RTCDataChannelMessage message) {
    if (!message.isBinary) return;
    final bytes = message.binary;
    final head = bytes.length > 32 ? bytes.sublist(0, 32) : bytes;
    final hex = head.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    try {
      final reader = MsgpackReader(bytes);
      final type = reader.readInt();
      final version = reader.readInt();
      final error = reader.readInt();
      if (error != 0) {
        logger.w(
          '[call][sfu] command reply type=$type version=$version '
          'ERROR=$error raw=$hex',
        );
        return;
      }
      logger.i('[call][sfu] command reply type=$type ok raw=$hex');
    } catch (e) {
      logger.w('[call][sfu] command reply parse failed: $e raw=$hex');
    }
  }

  int _dumped = 0;

  // #***! уведомления, алиасы слоты и уровни для подсветки говорящего
  void _onNotification(RTCDataChannelMessage message) {
    if (!message.isBinary) return;
    if (_dumped < 12) {
      _dumped++;
      final bytes = message.binary;
      final head = bytes.length > 64 ? bytes.sublist(0, 64) : bytes;
      logger.i(
        '[call][sfu] notify raw len=${bytes.length} '
        '${head.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
    }
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
        case _notifySlots:
          final count = reader.readArrayHeader();
          final slots = <String, int>{};
          for (var i = 0; i < count; i++) {
            final key = _aliases[reader.readInt()];
            if (key != null) slots[key] = i;
          }
          logger.i('[call][sfu] slots: $slots');
          if (!_slots.isClosed) _slots.add(slots);
          break;
        case _notifyAudioLevels:
          final count = reader.readMapHeader();
          final levels = <String, int>{};
          for (var i = 0; i < count; i++) {
            final key = _aliases[reader.readInt()];
            final level = reader.readInt();
            if (key != null) levels[key] = level;
          }
          if (!_levels.isClosed) _levels.add(levels);
          break;
      }
    } catch (e) {
      logger.w('[call][sfu] notify type=$type parse failed: $e');
    }
  }

  Future<void> dispose() async {
    _command = null;
    _aliases.clear();
    if (!_slots.isClosed) await _slots.close();
    if (!_levels.isClosed) await _levels.close();
  }
}

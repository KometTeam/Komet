import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/calls/sfu_screen_channel.dart';

Uint8List _packet({
  required int seq,
  required int flags,
  int codec = 1,
  int source = 3,
  List<int> payload = const [],
}) {
  final header = ByteData(11)
    ..setUint8(0, 1)
    ..setUint16(1, seq)
    ..setUint32(3, 5000 + seq)
    ..setUint8(7, codec)
    ..setUint16(8, source)
    ..setUint8(10, flags);
  return (BytesBuilder()
        ..add(header.buffer.asUint8List())
        ..add(payload))
      .toBytes();
}

void main() {
  late SfuScreenChannel channel;
  late List<ScreenFrame> frames;
  late List<int> ended;

  setUp(() {
    channel = SfuScreenChannel();
    frames = [];
    ended = [];
    channel.frames.listen(frames.add);
    channel.ended.listen(ended.add);
  });

  tearDown(() => channel.dispose());

  test('кадр собирается из кусков с первого по последний', () async {
    channel
      ..receive(_packet(seq: 1, flags: 1 | 4, payload: [1, 2]))
      ..receive(_packet(seq: 2, flags: 0, payload: [3]))
      ..receive(_packet(seq: 3, flags: 2, payload: [4, 5]));
    await Future<void>.delayed(Duration.zero);

    expect(frames, hasLength(1));
    final frame = frames.single;
    expect(frame.data, [1, 2, 3, 4, 5]);
    expect(frame.key, isTrue);
    expect(frame.codec, ScreenCodec.vp9);
    expect(frame.source, 3);
    expect(frame.timestamp, 5001);
  });

  test('куски без начала кадра отбрасываются', () async {
    channel
      ..receive(_packet(seq: 1, flags: 0, payload: [9]))
      ..receive(_packet(seq: 2, flags: 2, payload: [9]))
      ..receive(_packet(seq: 3, flags: 1 | 2, codec: 0, payload: [7]));
    await Future<void>.delayed(Duration.zero);

    expect(frames, hasLength(1));
    expect(frames.single.data, [7]);
    expect(frames.single.key, isFalse);
    expect(frames.single.codec, ScreenCodec.vp8);
  });

  test('источники собираются независимо', () async {
    channel
      ..receive(_packet(seq: 1, flags: 1, source: 1, payload: [1]))
      ..receive(_packet(seq: 2, flags: 1, source: 2, payload: [2]))
      ..receive(_packet(seq: 3, flags: 2, source: 1, payload: [1]))
      ..receive(_packet(seq: 4, flags: 2, source: 2, payload: [2]));
    await Future<void>.delayed(Duration.zero);

    expect(frames.map((f) => f.source), [1, 2]);
    expect(frames.map((f) => f.data), [
      [1, 1],
      [2, 2],
    ]);
  });

  test('флаг конца показа сбрасывает недособранный кадр', () async {
    channel
      ..receive(_packet(seq: 1, flags: 1, payload: [1]))
      ..receive(_packet(seq: 2, flags: 1 | 2 | 8))
      ..receive(_packet(seq: 3, flags: 2, payload: [1]));
    await Future<void>.delayed(Duration.zero);

    expect(ended, [3]);
    expect(frames, isEmpty);
  });

  test('чужой формат пакета игнорируется', () async {
    channel
      ..receive(Uint8List.fromList([2, 0, 0]))
      ..receive(Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]));
    await Future<void>.delayed(Duration.zero);

    expect(frames, isEmpty);
    expect(ended, isEmpty);
  });
}

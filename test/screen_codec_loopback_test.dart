import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/calls/screen_decoder.dart';
import 'package:komet/core/calls/screen_encoder.dart';
import 'package:komet/core/calls/sfu_screen_channel.dart';

const int _width = 320;
const int _height = 180;

Uint8List _gradient(int shift) {
  final frame = Uint8List(RawScreenFrame.i420Length(_width, _height));
  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      frame[y * _width + x] = 16 + ((x + y + shift) % 200);
    }
  }
  frame.fillRange(_width * _height, frame.length, 128);
  return frame;
}

ScreenFrame _frame(int length, {bool key = false}) => ScreenFrame(
  source: 0,
  codec: ScreenCodec.vp8,
  key: key,
  timestamp: 0,
  data: Uint8List.fromList(List.generate(length, (i) => i & 0xFF)),
);

void main() {
  group('ScreenPacketizer', () {
    test('splits a frame into 8000-byte chunks the receiver reassembles', () {
      final packetizer = ScreenPacketizer();
      final receiver = SfuScreenChannel();
      final received = <ScreenFrame>[];
      receiver.frames.listen(received.add);

      final frame = _frame(ScreenPacketizer.maxChunk * 2 + 17, key: true);
      final packets = packetizer.packetize(frame, timestamp: 42);

      expect(packets, hasLength(3));
      expect(packets.map((p) => p.length - 11), [8000, 8000, 17]);
      expect(packets.map((p) => p[10]), [1 | 4, 4, 2 | 4]);
      expect(packets.map((p) => p[7]).toSet(), {0});
      expect(packets.map((p) => ByteData.sublistView(p).getUint16(1)), [
        1,
        2,
        3,
      ]);

      packets.forEach(receiver.receive);
      return Future<void>.delayed(Duration.zero, () {
        expect(received, hasLength(1));
        expect(received.single.key, isTrue);
        expect(received.single.data, frame.data);
      });
    });

    test('a frame that fits one chunk is first and last at once', () {
      final packets = ScreenPacketizer().packetize(_frame(100), timestamp: 0);
      expect(packets.single[10], 1 | 2);
    });

    test('end of stream carries no payload and ends the source', () {
      final packetizer = ScreenPacketizer()
        ..packetize(_frame(10), timestamp: 0);
      final end = packetizer.endOfStream(codec: ScreenCodec.vp8, timestamp: 0);
      expect(end, hasLength(11));
      expect(end[10], 0x0B);
      expect(ByteData.sublistView(end).getUint16(1), 2);

      final receiver = SfuScreenChannel();
      final ended = <int>[];
      receiver.ended.listen(ended.add);
      receiver.receive(end);
      return Future<void>.delayed(Duration.zero, () => expect(ended, [0]));
    });
  });

  test('libvpx encoder output goes through packets and decodes back', () async {
    final encoder = await ScreenEncoder.start();
    final decoder = await ScreenDecoder.start();
    if (encoder == null || decoder == null) {
      await encoder?.dispose();
      await decoder?.dispose();
      markTestSkipped('libvpx is not installed');
      return;
    }
    addTearDown(encoder.dispose);
    addTearDown(decoder.dispose);

    final packetizer = ScreenPacketizer();
    final receiver = SfuScreenChannel();
    receiver.frames.listen(decoder.push);
    final encoded = <ScreenFrame>[];
    encoder.encoded.listen((frame) {
      encoded.add(frame);
      packetizer.packetize(frame, timestamp: 0).forEach(receiver.receive);
    });
    final decoded = decoder.decoded.first.timeout(const Duration(seconds: 10));

    expect(
      encoder.push(
        RawScreenFrame(width: _width, height: _height, i420: _gradient(0)),
      ),
      isTrue,
    );
    final image = await decoded;

    expect(encoded.first.key, isTrue);
    expect(image.width, _width);
    expect(image.height, _height);
    final luma = image.rgba[(90 * _width + 160) * 4];
    final expected = ((16 + (160 + 90) % 200) - 16) * 298 ~/ 256;
    expect((luma - expected).abs(), lessThan(24));
  });
}

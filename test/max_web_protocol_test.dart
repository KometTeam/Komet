import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/webpush/max_web_protocol.dart';

Uint8List _hex(String value) {
  final bytes = Uint8List(value.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

const _responseHex = '0a0100000006010000caf0b985ad7765622d7077612d70726f6d6fc3b270686f6e652d617574682d656e61626c6564c3a86c6f636174696f6ea25255a46c616e67c3b07265672d636f756e7472792d636f6465dc002aa2415aa2414da24b5aa24b47a24d44a2544aa2555aa24745a25448a25452a2544da24145a24c41a24d59a24944a24355a24b48a2564ea24146a2424fa24344a24347a2434fa24744a2474da2494ea24951a24b4ea24b57a24c42a24d4da24e49a2504ba25057a25141a25341a25645a2545aa24547a2434ea25a41a24252';
const _requestHex = '0a00000000060000015482a9757365724167656e748baa64657669636554797065a3574542ae7075736844657669636554797065a757454250555348a66c6f63616c65a27275ac6465766963654c6f63616c65a27275a96f7356657273696f6ea56d61634f53aa6465766963654e616d65a6536166617269af686561646572557365724167656e74d9754d6f7a696c6c612f352e3020284d6163696e746f73683b20496e74656c204d6163204f5320582031305f31355f3729204170706c655765624b69742f3630352e312e313520284b48544d4c2c206c696b65204765636b6f292056657273696f6e2f31382e35205361666172692f3630352e312e3135a56973507761c3aa61707056657273696f6ea732362e362e3230a673637265656eac3935367834343020332e3078a874696d657a6f6e65ad4575726f70652f4d6f73636f77a86465766963654964b06b6f6d65742d636f6465632d74657374';

void main() {
  test('заголовок кадра совпадает с эталоном сервера', () {
    final frame = _hex(_responseHex);
    expect(frame[0], MaxWebFraming.protocolVersion);
    final decoded = MaxWebFraming.decode(frame);
    expect(decoded.cmd, MaxWebCmd.ok);
    expect(decoded.opcode, 6);
    expect(decoded.isOk, isTrue);
  });

  test('распаковка LZ4 и msgpack на живом ответе сервера', () {
    final decoded = MaxWebFraming.decode(_hex(_responseHex));
    final payload = decoded.payload as Map<Object?, Object?>;
    expect(payload['location'], 'RU');
    expect(payload['web-pwa-promo'], isTrue);
    expect(payload['reg-country-code'], isA<List<Object?>>());
    expect(payload.length, 5);
  });

  test('кодирование кадра байт в байт как у веб-клиента', () {
    final expected = _hex(_requestHex);
    final payload = jsonDecode(_requestPayloadJson) as Map<String, dynamic>;
    final actual = MaxWebFraming.encode(cmd: 0, seq: 0, opcode: 6, payload: payload);
    expect(actual.length, expected.length);
    expect(actual.sublist(0, MaxWebFraming.headerSize),
        expected.sublist(0, MaxWebFraming.headerSize));
  });

  test('msgpack переживает круговой рейс', () {
    final source = <String, Object?>{
      'subscribe': true,
      'pushToken': 'https://web.push.apple.com/AAA-bbb_ccc',
      'secretKey': 'z2sMRx0MgXELERMrtCcK_Q',
      'publicKey': 'BOgrn-9cRlyU4jnyxQROVWWrTgpof_3T9UAO6DR6QkNvIbexyAQSEz4J5BBM6VQY6hZklsMq06aSK1oCzF5A644',
      'chatsCount': 40,
      'presenceSync': -1,
      'nested': <String, Object?>{'a': null, 'b': 3.5, 'c': <Object?>[1, 'два', false]},
    };
    final restored = MaxMsgpack.decode(MaxMsgpack.encode(source)) as Map<Object?, Object?>;
    expect(restored['subscribe'], true);
    expect(restored['pushToken'], source['pushToken']);
    expect(restored['chatsCount'], 40);
    expect(restored['presenceSync'], -1);
    final nested = restored['nested'] as Map<Object?, Object?>;
    expect(nested['a'], isNull);
    expect(nested['b'], 3.5);
    expect((nested['c'] as List<Object?>)[1], 'два');
  });

  test('ext(1) разворачивается во вложенное число', () {
    final pollingInterval = MaxMsgpack.decode(
      Uint8List.fromList([0x81, 0xA8, 0x69, 0x6E, 0x74, 0x65, 0x72, 0x76, 0x61, 0x6C,
        0xC7, 0x03, 0x01, 0xD1, 0x13, 0x88]),
    ) as Map<Object?, Object?>;
    expect(pollingInterval['interval'], 5000);

    final expiresAt = MaxMsgpack.decode(
      Uint8List.fromList([0xC7, 0x09, 0x01, 0xD3, 0x00, 0x00, 0x01, 0xA0, 0x25,
        0x5B, 0xE9, 0xD2]),
    );
    expect(expiresAt, 1787333175762);
  });

  test('LZ4 разворачивает перекрывающиеся совпадения', () {
    final compressed = Uint8List.fromList([0x6E, 0x6B, 0x6F, 0x6D, 0x65, 0x74, 0x20, 0x06, 0x00, 0x46, 0x70, 0x75, 0x73, 0x68, 0x05, 0x00, 0x50, 0x20, 0x70, 0x75, 0x73, 0x68]);
    final result = Lz4Block.decompress(compressed, 256);
    expect(utf8.decode(result), 'komet komet komet komet push push push push');
  });
}

const _requestPayloadJson = r'''{"userAgent": {"deviceType": "WEB", "pushDeviceType": "WEBPUSH", "locale": "ru", "deviceLocale": "ru", "osVersion": "macOS", "deviceName": "Safari", "headerUserAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15", "isPwa": true, "appVersion": "26.6.20", "screen": "956x440 3.0x", "timezone": "Europe/Moscow"}, "deviceId": "komet-codec-test"}''';

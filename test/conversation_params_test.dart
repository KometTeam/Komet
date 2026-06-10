import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/calls/conversation_params.dart';

void main() {
  // Реальный `vcp` из захвата входящего звонка (docs/PCAPdroid_10_июн._15_32_04).
  const sampleVcp =
      '532:8Ux7InRrbiI6IjZ5OHFHbkx4czJ0TXk5d1dOZjZFVms2OEN6QlR3Vmg3OGxBaDZZem4zems9Iiwid3NlIjoid3NzOi8vdmlkZW93ZWJydGMub2tjZG4ucnUvd3My'
      'JwD6B2lwIjpbIjE1NS4yMTIuMjA0LjExIiwRAIA5NiJdLCJ3dFMAT2h0dHBVAAWQOjIzNDU2L3d0gQAfdFoAFzh2Y2FbAFVjYWxsc6oAESIgAA9NAAAsOTWoAADSAAnKABEzuQDwFHNyY3AiOiJvbmVfbWUi'
      'LCJldCI6MTc4MTA5NDc1Mywic3RufwBWc3R1bjo/AJA1LjgyOjE5MzBWACF0ciMAP3R1ciMAAx0sGgAoMTQ9AEB1IjoicwDyBDEyMzM3Mzo5MTAyMTUzNDUyOTdeAAChAPAMOVhWbTduUnoxMEFuVkZWN2t0M003aGdDL3hR0wGgaXYiOmZhbHNlfQ==';

  test('decodes the captured vcp blob', () {
    final params = ConversationParams.decode(sampleVcp);

    expect(params, isNotNull);
    expect(params!.token, '6y8qGnLxs2tMy9wWNf6EVk68CzBTwVh78lAh6Yzn3zk=');
    expect(params.wsEndpoint, 'wss://videowebrtc.okcdn.ru/ws2');
    expect(params.wtEndpoint, 'https://videowebrtc.okcdn.ru:23456/wt');
    expect(params.callsApiEndpoint, 'https://calls.okcdn.ru');
    expect(params.clientType, 'one_me');
    expect(params.expiresAt, 1781094753);
    expect(params.stun, 'stun:155.212.205.82:19302');
    expect(params.turn, [
      'turn:155.212.205.82:19302',
      'turn:155.212.205.14:19302',
    ]);
    expect(params.turnUser, '1781123373:910215345297');
    expect(params.turnPassword, '9XVm7nRz10AnVFV7kt3M7hgC/xQ=');
    expect(params.isVideo, false);
  });

  test('builds ice servers for flutter_webrtc', () {
    final params = ConversationParams.decode(sampleVcp)!;
    final ice = params.iceServers;

    expect(ice, hasLength(2));
    expect(ice[0]['urls'], 'stun:155.212.205.82:19302');
    expect(ice[1]['urls'], isA<List<String>>());
    expect(ice[1]['username'], '1781123373:910215345297');
    expect(ice[1]['credential'], '9XVm7nRz10AnVFV7kt3M7hgC/xQ=');
  });

  test('rejects malformed input', () {
    expect(ConversationParams.decode('not-a-vcp'), isNull);
    expect(ConversationParams.decode(''), isNull);
    expect(ConversationParams.decode('0:'), isNull);
  });
}

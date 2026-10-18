import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:komet/core/calls/call_session.dart';
import 'package:komet/core/calls/sfu_data_channel.dart';
import 'package:komet/core/calls/ws2_signaling.dart';

const _selfId = 1001;

CallSession _session() => CallSession(
  ws2Config: Ws2Config(
    uri: Uri.parse('wss://calls.invalid/ws'),
    userId: _selfId,
  ),
  role: CallRole.joiner,
  isGroup: true,
);

Future<void> _join(
  CallSession session,
  int id, {
  bool video = false,
  bool screen = false,
}) => session.debugHandleNotification({
  'notification': 'participant-joined',
  'participant': {
    'id': id,
    'externalId': {'id': '${id + 500}'},
    'mediaSettings': {
      'isAudioEnabled': true,
      'isVideoEnabled': video,
      'isScreenSharingEnabled': screen,
    },
    'roles': const <String>[],
  },
});

void main() {
  test('без запроса от экрана просит все камеры и трансляции', () async {
    final session = _session();
    await _join(session, _selfId, video: true);
    await _join(session, 2, video: true);
    await _join(session, 3);
    await _join(session, 4, screen: true);

    final layout = session.debugDisplayLayout();

    expect(layout.layouts, {
      'u2:sCAMERA': 'sz=640x360:fit=cv',
      'u4:sSCREEN': 'sz=640x360:fit=cv',
    });
    expect(layout.cameras, [2]);
  });

  test('просит только видимые видео под размер плитки', () async {
    final session = _session();
    await _join(session, _selfId, video: true);
    await _join(session, 2, video: true);
    await _join(session, 3, video: true);
    await _join(session, 4);

    session.setVideoRequests({
      (_selfId, CallVideoSource.camera): (
        size: const Size(900, 700),
        cover: true,
      ),
      (2, CallVideoSource.camera): (size: const Size(500, 380), cover: true),
      (4, CallVideoSource.camera): (size: const Size(500, 380), cover: true),
    });
    final layout = session.debugDisplayLayout();

    expect(layout.layouts, {'u2:sCAMERA': 'sz=480x360:fit=cv'});
    expect(layout.cameras, [2]);
  });

  test('на сцене трансляция идёт в 1280x720 целиком', () async {
    final session = _session();
    await _join(session, _selfId);
    await _join(session, 2, video: true, screen: true);

    session.setVideoRequests({
      (2, CallVideoSource.screen): CallSession.stageVideoRequest,
      (2, CallVideoSource.camera): (size: const Size(320, 240), cover: true),
    });

    expect(session.debugDisplayLayout().layouts, {
      'u2:sSCREEN': 'sz=1280x720:fit=cn',
      'u2:sCAMERA': 'sz=320x240:fit=cv',
    });
  });

  test('камер в раскладке не больше десяти', () async {
    final session = _session();
    await _join(session, _selfId);
    for (var id = 2; id <= 14; id++) {
      await _join(session, id, video: true);
    }

    session.setVideoRequests({
      for (var id = 2; id <= 14; id++)
        (id, CallVideoSource.camera): (size: const Size(320, 240), cover: true),
    });
    final layout = session.debugDisplayLayout();

    expect(layout.cameras, [for (var id = 2; id <= 11; id++) id]);
    expect(layout.layouts, hasLength(10));
  });

  test('уведомление AudioActivity даёт список говорящих', () async {
    final channel = SfuNotificationChannel();
    final received = <Set<String>>[];
    final sub = channel.audioActivity.listen(received.add);

    channel.debugHandle(
      RTCDataChannelMessage.fromBinary(
        Uint8List.fromList([
          0x01,
          0x82,
          0xA2,
          0x75,
          0x37,
          0x01,
          0xA2,
          0x75,
          0x39,
          0x02,
        ]),
      ),
    );
    channel.debugHandle(
      RTCDataChannelMessage.fromBinary(
        Uint8List.fromList([0x02, 0x92, 0x01, 0x02]),
      ),
    );
    channel.debugHandle(
      RTCDataChannelMessage.fromBinary(Uint8List.fromList([0x02, 0x90])),
    );
    await Future<void>.delayed(Duration.zero);

    expect(received, [
      {'u7', 'u9'},
      <String>{},
    ]);
    await sub.cancel();
    await channel.dispose();
  });

  test('сеть и зависшее видео приходят по служебному каналу SFU', () async {
    final channel = SfuNotificationChannel();
    final stalled = <Set<String>>[];
    final network = <Map<String, double>>[];
    final subs = [
      channel.stalledVideo.listen(stalled.add),
      channel.networkStatus.listen(network.add),
    ];

    channel.debugHandle(
      RTCDataChannelMessage.fromBinary(
        Uint8List.fromList([0x01, 0x81, 0xA2, 0x75, 0x37, 0x05]),
      ),
    );
    channel.debugHandle(
      RTCDataChannelMessage.fromBinary(Uint8List.fromList([0x04, 0x91, 0x05])),
    );
    channel.debugHandle(
      RTCDataChannelMessage.fromBinary(
        Uint8List.fromList([0x06, 0x81, 0x05, 0x19]),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(stalled, [
      {'u7'},
    ]);
    expect(network, [
      {'u7': 0.25},
    ]);
    for (final sub in subs) {
      await sub.cancel();
    }
    await channel.dispose();
  });

  test('сессия раскладывает сеть и зависание по участникам', () async {
    final session = _session();
    await _join(session, _selfId);
    await _join(session, 2, video: true);
    await _join(session, 3, video: true);

    session.debugSfuNetwork({'u2': 0.2, 'u3:d1': 0.9});
    session.debugSfuStalled({'u3'});
    final byId = {for (final p in session.participants) p.id: p};

    expect(byId[2]!.badNetwork, isTrue);
    expect(byId[3]!.badNetwork, isFalse);
    expect(byId[3]!.networkRating, 0.9);
    expect(byId[3]!.videoStalled, isTrue);
    expect(byId[2]!.videoStalled, isFalse);

    session.debugSfuStalled(const {});
    expect(byId[3]!.videoStalled, isFalse);
  });

  test(
    'из participant-joined и registered-peer берутся технические данные',
    () async {
      final session = _session();
      await _join(session, _selfId);
      await session.debugHandleNotification({
        'notification': 'participant-joined',
        'stamp': 1700000000000000000,
        'participant': {
          'id': 5,
          'externalId': {'id': '505', 'type': 'ONE_ME'},
          'state': 'ACCEPTED',
          'mediaSettings': {'isAudioEnabled': true},
          'peerId': {'id': 77},
          'sessionState': {'connected': false},
          'markers': {
            'GRID': {'rank': 1, 'ts': 1700000001000},
          },
        },
      });
      await session.debugHandleNotification({
        'notification': 'registered-peer',
        'participantId': 5,
        'participantType': 'USER',
        'clientType': 'ONE_ME',
        'platform': 'WEB',
        'peerId': {'id': 77, 'type': 'WEB_TRANSPORT'},
      });
      await session.debugHandleNotification({
        'notification': 'session-state',
        'participantId': 5,
        'connected': true,
      });

      final p = session.participants.firstWhere((p) => p.id == 5);
      expect(p.externalId, 505);
      expect(p.externalType, 'ONE_ME');
      expect(p.platform, 'WEB');
      expect(p.clientType, 'ONE_ME');
      expect(p.transport, 'WEB_TRANSPORT');
      expect(p.joinedAt, 1700000001000);
      expect(p.mediaConnected, isTrue);
    },
  );
}

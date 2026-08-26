import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/calls/audio_devices.dart';
import 'package:komet/core/calls/pulse_audio.dart';
import 'package:komet/core/config/call_no_mute.dart';

const _deviceId = 'mic-test-0';

const _sourcesJson = '''
[
  {
    "name": "alsa_input.test-device",
    "description": "(null)",
    "monitor_source": "",
    "properties": {"device.description": "Тестовая звуковая карта"}
  },
  {
    "name": "alsa_output.test-device.monitor",
    "description": "(null)",
    "monitor_source": "alsa_output.test-device",
    "properties": {"device.description": "Тестовая звуковая карта"}
  },
  {
    "name": "virtual_sink.monitor",
    "description": "Monitor of Virtual Sink",
    "monitor_source": "virtual_sink",
    "properties": {}
  },
  {
    "name": "komet_capture_4242",
    "description": "komet_capture_4242",
    "monitor_source": "",
    "properties": {}
  }
]
''';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    CallNoMute.enabled = false;
  });

  test('--no-mute включается только своим флагом', () {
    CallNoMute.enabled = false;
    CallNoMute.parse(const ['--debug-test']);
    expect(CallNoMute.enabled, isFalse);

    CallNoMute.parse(const ['--debug-test', '--no-mute']);
    expect(CallNoMute.enabled, isTrue);
  });

  test('desktop выбирает вход через sourceId', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(AudioDevices.switchesInsideEngine, isFalse);
    expect(AudioDevices.micConstraints(_deviceId), <String, dynamic>{
      'optional': [
        {'sourceId': _deviceId},
      ],
    });
  });

  test('мобильные платформы переключают вход внутри движка', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AudioDevices.switchesInsideEngine, isTrue);
    expect(AudioDevices.micConstraints(_deviceId), isTrue);
  });

  test('без выбранного устройства ограничений нет', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(AudioDevices.micConstraints(null), isTrue);
    expect(AudioDevices.micConstraints(''), isTrue);
  });

  test('захват монитора глушит шумодав и АРУ, но оставляет эхоподавление', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final constraints =
        AudioDevices.micConstraints(_deviceId, monitorCapture: true)
            as Map<String, dynamic>;
    expect(constraints['optional'], [
      {'sourceId': _deviceId},
    ]);
    expect(constraints['echoCancellation'], isTrue);
    expect(constraints['noiseSuppression'], isFalse);
    expect(constraints['autoGainControl'], isFalse);
    expect(constraints['highpassFilter'], isFalse);
  });

  test('источники pulse разбираются вместе с мониторами', () {
    final sources = PulseAudio.parseSources(_sourcesJson);
    expect(sources.map((s) => s.name), [
      'alsa_input.test-device',
      'alsa_output.test-device.monitor',
      'virtual_sink.monitor',
    ]);
    expect(sources[0].isMonitor, isFalse);
    expect(sources[0].label, 'Тестовая звуковая карта');
    expect(sources[1].isMonitor, isTrue);
    expect(sources[1].label, 'Monitor of Тестовая звуковая карта');
    expect(sources[2].label, 'Monitor of Virtual Sink');
  });

  test('битый вывод pactl не роняет разбор', () {
    expect(PulseAudio.parseSources('не json'), isEmpty);
  });
}

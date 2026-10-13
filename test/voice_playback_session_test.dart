import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/voice_playback_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.ryanheise.audio_session');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('на iOS голосовые играют в категории playback, мимо беззвучного', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await VoicePlaybackSession.prepare();

    final configured = calls.where((c) => c.method == 'setConfiguration');
    expect(configured, isNotEmpty);
    final json = (configured.last.arguments as List).first as Map;
    expect(
      json['avAudioSessionCategory'],
      AVAudioSessionCategory.playback.rawValue,
    );
  });

  test('на Android сессию не трогаем', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await VoicePlaybackSession.prepare();
    expect(calls.where((c) => c.method == 'setConfiguration'), isEmpty);
  });
}

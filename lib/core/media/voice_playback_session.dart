import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import '../calls/active_call.dart';
import '../utils/logger.dart';

abstract final class VoicePlaybackSession {
  static const AudioSessionConfiguration configuration =
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      );

  static Future<void> prepare() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (ActiveCall.instance.current.value != null) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(configuration);
      await session.setActive(true);
    } catch (e) {
      logger.w('VoicePlaybackSession.prepare: $e');
    }
  }
}

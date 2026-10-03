import 'package:just_audio_media_kit/just_audio_media_kit.dart';

abstract final class DesktopAudioBackend {
  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    JustAudioMediaKit.ensureInitialized(linux: true, windows: true);
  }
}

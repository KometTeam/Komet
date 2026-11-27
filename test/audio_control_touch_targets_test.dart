import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/voice_bubble.dart';
import 'package:komet/frontend/widgets/media_playback_pill.dart';

void main() {
  test('compact audio controls keep comfortable touch targets', () {
    expect(voiceTranscriptionButtonExtent, greaterThanOrEqualTo(40));
    expect(MediaPlaybackPill.height, greaterThanOrEqualTo(40));
    expect(mediaPlaybackControlExtent, greaterThanOrEqualTo(40));
  });
}

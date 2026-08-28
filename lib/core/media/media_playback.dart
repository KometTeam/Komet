import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'audio_file_track.dart';
import 'audio_playback_controller.dart';
import 'voice_audio_controller.dart';

enum PlaybackKind { voice, videoNote, audioFile }

class VoiceTrack {
  const VoiceTrack({
    required this.cacheName,
    required this.chatId,
    required this.messageId,
    required this.senderId,
    required this.isMe,
    required this.time,
    required this.audio,
  });

  final String cacheName;
  final int chatId;
  final String messageId;
  final int senderId;
  final bool isMe;
  final int time;
  final VoiceAudioController audio;
}

class VideoNoteTrack {
  const VideoNoteTrack({
    required this.cacheName,
    required this.chatId,
    required this.messageId,
    required this.senderId,
    required this.isMe,
    required this.time,
    required this.controller,
    required this.preview,
  });

  final String cacheName;
  final int chatId;
  final String messageId;
  final int senderId;
  final bool isMe;
  final int time;
  final VideoPlayerController controller;
  final Uint8List? preview;
}

class MediaPlayback {
  MediaPlayback._();

  static final MediaPlayback instance = MediaPlayback._();

  static const List<double> speeds = [1.0, 1.5, 2.0];

  final ValueNotifier<PlaybackKind?> primary = ValueNotifier(null);
  final ValueNotifier<AudioFileTrack?> audioFile = ValueNotifier(null);

  final ValueNotifier<int?> visibleChatId = ValueNotifier(null);

  void enterChat(int chatId) => visibleChatId.value = chatId;

  void leaveChat(int chatId) {
    if (visibleChatId.value == chatId) visibleChatId.value = null;
  }

  final ValueNotifier<VoiceTrack?> voice = ValueNotifier(null);
  final ValueNotifier<double> voiceSpeed = ValueNotifier(speeds.first);

  final Set<VoiceAudioController> _heldVoice = {};

  VoiceAudioController acquireVoice({
    required String cacheName,
    required Future<String?> Function() resolveUrl,
    required Duration fallbackDuration,
  }) {
    final active = voice.value;
    if (active != null && active.cacheName == cacheName) {
      _heldVoice.add(active.audio);
      return active.audio;
    }
    final created = VoiceAudioController(
      cacheName: cacheName,
      resolveUrl: resolveUrl,
      fallbackDuration: fallbackDuration,
    );
    _heldVoice.add(created);
    return created;
  }

  void releaseVoice(VoiceAudioController audio) {
    _heldVoice.remove(audio);
    _disposeVoiceIfIdle(audio);
  }

  void activateVoice(VoiceTrack track) {
    _clearAudioFile();
    _clearVideoNote();
    final previous = voice.value;
    if (previous != null && previous.audio != track.audio) {
      previous.audio.pause();
      voice.value = null;
      _disposeVoiceIfIdle(previous.audio);
    }
    voice.value = track;
    primary.value = PlaybackKind.voice;
    track.audio.setSpeed(voiceSpeed.value);
  }

  void cycleVoiceSpeed() {
    final next = speeds[(speeds.indexOf(voiceSpeed.value) + 1) % speeds.length];
    voiceSpeed.value = next;
    voice.value?.audio.setSpeed(next);
  }

  void closeVoice() {
    if (!_clearVoice()) return;
    primary.value = videoNote.value == null ? null : PlaybackKind.videoNote;
  }

  bool _clearVoice() {
    final track = voice.value;
    if (track == null) return false;
    voice.value = null;
    track.audio.stopAndReset();
    _disposeVoiceIfIdle(track.audio);
    return true;
  }

  void _disposeVoiceIfIdle(VoiceAudioController audio) {
    if (_heldVoice.contains(audio)) return;
    if (voice.value?.audio == audio) return;
    audio.dispose();
  }

  final ValueNotifier<VideoNoteTrack?> videoNote = ValueNotifier(null);
  final ValueNotifier<double> videoNoteSpeed = ValueNotifier(speeds.first);

  final Set<VideoPlayerController> _heldNotes = {};

  VideoPlayerController? liveVideoNote(String cacheName) {
    final active = videoNote.value;
    if (active == null || active.cacheName != cacheName) return null;
    _heldNotes.add(active.controller);
    return active.controller;
  }

  void holdVideoNote(VideoPlayerController controller) =>
      _heldNotes.add(controller);

  bool isActiveVideoNote(VideoPlayerController controller) =>
      videoNote.value?.controller == controller;

  void releaseVideoNote(VideoPlayerController controller) {
    _heldNotes.remove(controller);
    _disposeNoteIfIdle(controller);
  }

  void activateVideoNote(VideoNoteTrack track) {
    _clearAudioFile();
    _clearVoice();
    final previous = videoNote.value;
    if (previous != null && previous.controller != track.controller) {
      previous.controller.pause();
      videoNote.value = null;
      _disposeNoteIfIdle(previous.controller);
    }
    videoNote.value = track;
    primary.value = PlaybackKind.videoNote;
    track.controller.setPlaybackSpeed(videoNoteSpeed.value);
  }

  void cycleVideoNoteSpeed() {
    final index = speeds.indexOf(videoNoteSpeed.value);
    final next = speeds[(index + 1) % speeds.length];
    videoNoteSpeed.value = next;
    videoNote.value?.controller.setPlaybackSpeed(next);
  }

  void closeVideoNote() {
    if (!_clearVideoNote()) return;
    primary.value = voice.value == null ? null : PlaybackKind.voice;
  }

  bool _clearVideoNote() {
    final track = videoNote.value;
    if (track == null) return false;
    videoNote.value = null;
    track.controller.pause();
    track.controller.seekTo(Duration.zero);
    _disposeNoteIfIdle(track.controller);
    return true;
  }

  void _disposeNoteIfIdle(VideoPlayerController controller) {
    if (_heldNotes.contains(controller)) return;
    if (videoNote.value?.controller == controller) return;
    controller.dispose();
  }

  Future<void> activateAudioFile(AudioFileTrack track) async {
    if (!AudioPlaybackController.isInitialized) {
      throw StateError('Audio playback is not initialized');
    }
    final current = audioFile.value;
    if (current?.cacheName == track.cacheName) {
      await AudioPlaybackController.instance.toggle();
      return;
    }
    _clearVoice();
    _clearVideoNote();
    audioFile.value = track;
    primary.value = PlaybackKind.audioFile;
    try {
      await AudioPlaybackController.instance.playTrack(track);
    } catch (_) {
      audioFile.value = null;
      primary.value = null;
      rethrow;
    }
  }

  void closeAudioFile() {
    if (!_clearAudioFile()) return;
    primary.value = voice.value != null
        ? PlaybackKind.voice
        : videoNote.value != null
        ? PlaybackKind.videoNote
        : null;
  }

  bool _clearAudioFile() {
    if (audioFile.value == null) return false;
    audioFile.value = null;
    if (AudioPlaybackController.isInitialized) {
      unawaited(AudioPlaybackController.instance.stop());
    }
    return true;
  }
}

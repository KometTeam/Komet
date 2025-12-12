import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' as io;

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? albumArtUrl;
  final int? duration;
  final String? filePath;
  final String? fileUrl;
  final int? fileId;
  final String? token;
  final int? chatId;
  final String? messageId;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.albumArtUrl,
    this.duration,
    this.filePath,
    this.fileUrl,
    this.fileId,
    this.token,
    this.chatId,
    this.messageId,
  });

  factory MusicTrack.fromAttachment(Map<String, dynamic> attach) {
    final preview = attach['preview'] as Map<String, dynamic>?;
    final fileId = attach['fileId'] as int?;
    final token = attach['token'] as String?;
    final name = attach['name'] as String? ?? 'Unknown';

    final durationSeconds = preview?['duration'] as int?;
    final duration = durationSeconds != null ? durationSeconds * 1000 : null;

    return MusicTrack(
      id:
          fileId?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: preview?['title'] as String? ?? name,
      artist: preview?['artistName'] as String? ?? 'Unknown Artist',
      album: preview?['albumName'] as String?,
      albumArtUrl: preview?['baseUrl'] as String?,
      duration: duration,
      fileId: fileId,
      token: token,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtUrl': albumArtUrl,
      'duration': duration,
      'filePath': filePath,
      'fileUrl': fileUrl,
      'fileId': fileId,
      'token': token,
      'chatId': chatId,
      'messageId': messageId,
    };
  }

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String?,
      albumArtUrl: json['albumArtUrl'] as String?,
      duration: json['duration'] as int?,
      filePath: json['filePath'] as String?,
      fileUrl: json['fileUrl'] as String?,
      fileId: json['fileId'] as int?,
      token: json['token'] as String?,
      chatId: json['chatId'] as int?,
      messageId: json['messageId'] as String?,
    );
  }
}

class MusicPlayerService extends ChangeNotifier {
  static final MusicPlayerService _instance = MusicPlayerService._internal();
  factory MusicPlayerService() => _instance;
  MusicPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  List<MusicTrack> _playlist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _wasCompleted = false;

  MusicTrack? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _playlist.length
      ? _playlist[_currentIndex]
      : null;

  List<MusicTrack> get playlist => List.unmodifiable(_playlist);
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  int get currentIndex => _currentIndex;
  double get volume => _volume;

  Future<void> initialize() async {
    
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble('music_volume') ?? 1.0;
    await _audioPlayer.setVolume(_volume);

    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      final wasCompleted = _wasCompleted;
      _isPlaying = state.playing;
      _isLoading =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      
      if (state.processingState == ProcessingState.completed && !wasCompleted) {
        _wasCompleted = true;
        _autoPlayNext();
      } else if (state.processingState != ProcessingState.completed) {
        _wasCompleted = false;
      }

      notifyListeners();
    });

    await loadPlaylist();
  }

  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? playlist}) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (playlist != null) {
        _playlist = playlist;
        _currentIndex = _playlist.indexWhere((t) => t.id == track.id);
        if (_currentIndex == -1) {
          _currentIndex = 0;
          _playlist.insert(0, track);
        }
      } else {
        if (_playlist.isEmpty || !_playlist.any((t) => t.id == track.id)) {
          _playlist = [track];
          _currentIndex = 0;
        } else {
          _currentIndex = _playlist.indexWhere((t) => t.id == track.id);
        }
      }

      await _loadAndPlayTrack(track);
      await savePlaylist();
    } catch (e) {
      print('Error playing track: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAndPlayTrack(MusicTrack track) async {
    try {
      String? audioSource;

      if (track.filePath != null) {
        final file = io.File(track.filePath!);
        if (await file.exists()) {
          audioSource = track.filePath;
        }
      }

      if (audioSource == null && track.fileId != null) {
        final prefs = await SharedPreferences.getInstance();
        final fileIdMap = prefs.getStringList('file_id_to_path_map') ?? [];
        final fileIdString = track.fileId.toString();

        for (final mapping in fileIdMap) {
          if (mapping.startsWith('$fileIdString:')) {
            final filePath = mapping.substring(fileIdString.length + 1);
            final file = io.File(filePath);
            if (await file.exists()) {
              audioSource = filePath;
              final updatedTrack = MusicTrack(
                id: track.id,
                title: track.title,
                artist: track.artist,
                album: track.album,
                albumArtUrl: track.albumArtUrl,
                duration: track.duration,
                filePath: filePath,
                fileUrl: track.fileUrl,
                fileId: track.fileId,
                token: track.token,
                chatId: track.chatId,
                messageId: track.messageId,
              );
              _playlist[_currentIndex] = updatedTrack;
              break;
            }
          }
        }
      }

      if (audioSource == null && track.fileUrl != null) {
        throw Exception('File not downloaded. Please download the file first.');
      }

      if (audioSource == null) {
        throw Exception('No audio source available');
      }

      await _audioPlayer.setFilePath(audioSource);
      await _audioPlayer.play();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('music_volume', _volume);
    notifyListeners();
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _playlist.length;
    await _loadAndPlayTrack(_playlist[_currentIndex]);
    await savePlaylist();
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    await _loadAndPlayTrack(_playlist[_currentIndex]);
    await savePlaylist();
  }

  Future<void> _autoPlayNext() async {
    if (_playlist.isEmpty || _playlist.length <= 1) return;

    try {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
      await _loadAndPlayTrack(_playlist[_currentIndex]);
      await savePlaylist();
    } catch (e) {
      print('Error auto-playing next track: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToPlaylist(MusicTrack track) async {
    if (!_playlist.any((t) => t.id == track.id)) {
      _playlist.add(track);
      await savePlaylist();
      notifyListeners();
    }
  }

  Future<void> removeFromPlaylist(int index) async {
    if (index >= 0 && index < _playlist.length) {
      if (index == _currentIndex) {
        await _audioPlayer.stop();
        _currentIndex = -1;
      } else if (index < _currentIndex) {
        _currentIndex--;
      }
      _playlist.removeAt(index);
      await savePlaylist();
      notifyListeners();
    }
  }

  Future<void> savePlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistJson = _playlist.map((t) => t.toJson()).toList();
      final jsonString = jsonEncode(playlistJson);
      await prefs.setString('music_playlist', jsonString);
      await prefs.setInt('music_current_index', _currentIndex);
    } catch (e) {
      print('Error saving playlist: $e');
    }
  }

  Future<void> loadPlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('music_playlist');
      if (jsonString != null) {
        final List<dynamic> playlistJson = jsonDecode(jsonString);
        _playlist = playlistJson
            .map((json) => MusicTrack.fromJson(json as Map<String, dynamic>))
            .toList();
        _currentIndex = prefs.getInt('music_current_index') ?? -1;
      }
    } catch (e) {
      print('Error loading playlist: $e');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

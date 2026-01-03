import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:io' as io;
import 'dart:convert';
import '../services/music_player_service.dart';
import '../widgets/bottom_sheet_music_player.dart';
import 'package:gwid/app_sizes.dart';

class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({super.key});

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  List<MusicTrack> _musicTracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMusicTracks();
  }

  Future<void> _loadMusicTracks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final fileIdMap = prefs.getStringList('file_id_to_path_map') ?? [];
      final List<MusicTrack> tracks = [];

      final musicMetadataJson = prefs.getString('music_metadata') ?? '{}';
      final Map<String, dynamic> musicMetadata = jsonDecode(musicMetadataJson);

      for (final mapping in fileIdMap) {
        final parts = mapping.split(':');
        if (parts.length >= 2) {
          final fileId = parts[0];
          final filePath = parts.skip(1).join(':');
          final file = io.File(filePath);

          if (await file.exists()) {
            final extension = filePath.split('.').last.toLowerCase();
            if ([
              'mp3',
              'wav',
              'flac',
              'm4a',
              'aac',
              'ogg',
            ].contains(extension)) {
              final metadata = musicMetadata[fileId] as Map<String, dynamic>?;

              if (metadata != null) {
                tracks.add(
                  MusicTrack.fromJson({
                    ...metadata,
                    'filePath': filePath,
                    'fileId': int.tryParse(fileId),
                  }),
                );
              } else {
                final fileName = filePath.split('/').last;
                final nameWithoutExt = fileName.substring(
                  0,
                  fileName.lastIndexOf('.'),
                );
                tracks.add(
                  MusicTrack(
                    id: fileId,
                    title: nameWithoutExt,
                    artist: 'Unknown Artist',
                    filePath: filePath,
                    fileId: int.tryParse(fileId),
                  ),
                );
              }
            }
          }
        }
      }

      tracks.sort((a, b) => a.title.compareTo(b.title));

      setState(() {
        _musicTracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading music tracks: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _playTrack(MusicTrack track) async {
    final musicPlayer = MusicPlayerService();
    await musicPlayer.playTrack(track, playlist: _musicTracks);

    BottomSheetMusicPlayer.isExpandedNotifier.value = true;
    BottomSheetMusicPlayer.isFullscreenNotifier.value = true;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String _formatDuration(int? milliseconds) {
    if (milliseconds == null) return '--:--';
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final musicPlayer = context.watch<MusicPlayerService>();

    return ValueListenableBuilder<bool>(
      valueListenable: BottomSheetMusicPlayer.isExpandedNotifier,
      builder: (context, isPlayerExpanded, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: BottomSheetMusicPlayer.isFullscreenNotifier,
          builder: (context, isFullscreen, _) {
            return PopScope(
              canPop: !isPlayerExpanded,
              onPopInvoked: (didPop) {
                if (!didPop && isPlayerExpanded) {
                  BottomSheetMusicPlayer.isExpandedNotifier.value = false;
                  BottomSheetMusicPlayer.isFullscreenNotifier.value = false;
                }
              },
              child: Scaffold(
                appBar: isFullscreen
                    ? null
                    : AppBar(title: const Text('Музыка')),
                body: Stack(
                  children: [
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _musicTracks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.music_off,
                                  size: 64,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Нет музыки',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.7,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Скачайте музыку из чатов',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: musicPlayer.currentTrack != null
                                  ? 120
                                  : 16,
                            ),
                            itemCount: _musicTracks.length,
                            itemBuilder: (context, index) {
                              final track = _musicTracks[index];
                              final isCurrentTrack =
                                  musicPlayer.currentTrack?.id == track.id;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                color: isCurrentTrack
                                    ? colorScheme.primaryContainer.withOpacity(
                                        0.3,
                                      )
                                    : null,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      color: colorScheme.primaryContainer,
                                      child: track.albumArtUrl != null
                                          ? Image.network(
                                              track.albumArtUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Icon(
                                                    Icons.music_note,
                                                    color: colorScheme
                                                        .onPrimaryContainer,
                                                  ),
                                            )
                                          : Icon(
                                              Icons.music_note,
                                              color: colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                    ),
                                  ),
                                  title: Text(
                                    track.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        track.artist,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.7),
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (track.album != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          track.album!,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.5),
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (track.duration != null) ...[
                                            Text(
                                              _formatDuration(track.duration),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme.onSurface
                                                        .withOpacity(0.5),
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '•',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme.onSurface
                                                        .withOpacity(0.5),
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (track.filePath != null) ...[
                                            FutureBuilder<io.FileStat>(
                                              future: io.File(
                                                track.filePath!,
                                              ).stat(),
                                              builder: (context, snapshot) {
                                                if (snapshot.hasData) {
                                                  return Text(
                                                    _formatFileSize(
                                                      snapshot.data!.size,
                                                    ),
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurface
                                                              .withOpacity(0.5),
                                                        ),
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Builder(
                                    builder: (context) {
                                      final isCurrentTrack =
                                          musicPlayer.currentTrack?.id ==
                                          track.id;
                                      final isPlaying =
                                          isCurrentTrack &&
                                          musicPlayer.isPlaying;

                                      return IconButton(
                                        onPressed: () {
                                          if (isCurrentTrack && isPlaying) {
                                            musicPlayer.pause();
                                          } else {
                                            _playTrack(track);
                                          }
                                        },
                                        icon: isCurrentTrack && isPlaying
                                            ? const Icon(Icons.pause)
                                            : const Icon(Icons.play_arrow),
                                        style: IconButton.styleFrom(
                                          backgroundColor: isCurrentTrack
                                              ? colorScheme.primary
                                              : colorScheme.primaryContainer,
                                          foregroundColor: isCurrentTrack
                                              ? colorScheme.onPrimary
                                              : colorScheme.onPrimaryContainer,
                                        ),
                                      );
                                    },
                                  ),
                                  onTap: () {
                                    final isCurrentTrack =
                                        musicPlayer.currentTrack?.id ==
                                        track.id;
                                    if (isCurrentTrack &&
                                        musicPlayer.isPlaying) {
                                      musicPlayer.pause();
                                    } else {
                                      _playTrack(track);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                    if (musicPlayer.currentTrack != null)
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: BottomSheetMusicPlayer(),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

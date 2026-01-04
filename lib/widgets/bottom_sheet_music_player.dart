import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/music_player_service.dart';

class BottomSheetMusicPlayer extends StatefulWidget {
  const BottomSheetMusicPlayer({super.key});

  static final ValueNotifier<bool> isExpandedNotifier = ValueNotifier<bool>(
    false,
  );
  static final ValueNotifier<bool> isFullscreenNotifier = ValueNotifier<bool>(
    false,
  );

  @override
  State<BottomSheetMusicPlayer> createState() => _BottomSheetMusicPlayerState();
}

enum _PlayerState { collapsed, expanded, fullscreen }

class _BottomSheetMusicPlayerState extends State<BottomSheetMusicPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;
  _PlayerState _currentState = _PlayerState.collapsed;
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    _heightAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    BottomSheetMusicPlayer.isExpandedNotifier.addListener(_onExpandedChanged);
    BottomSheetMusicPlayer.isFullscreenNotifier.addListener(
      _onFullscreenChanged,
    );
  }

  void _onExpandedChanged() {
    final shouldBeExpanded = BottomSheetMusicPlayer.isExpandedNotifier.value;
    if (shouldBeExpanded && _currentState == _PlayerState.collapsed) {
      setState(() {
        _currentState = _PlayerState.expanded;
        _animationController.forward();
      });
    } else if (!shouldBeExpanded && _currentState != _PlayerState.collapsed) {
      setState(() {
        _currentState = _PlayerState.collapsed;
        _animationController.reverse();
        BottomSheetMusicPlayer.isFullscreenNotifier.value = false;
      });
    }
  }

  void _onFullscreenChanged() {
    final shouldBeFullscreen =
        BottomSheetMusicPlayer.isFullscreenNotifier.value;
    if (shouldBeFullscreen && _currentState != _PlayerState.fullscreen) {
      setState(() {
        _currentState = _PlayerState.fullscreen;
        if (_animationController.value < 1.0) {
          _animationController.forward();
        }
      });
    } else if (!shouldBeFullscreen &&
        _currentState == _PlayerState.fullscreen) {
      setState(() {
        _currentState = _PlayerState.expanded;
        _animationController.value = 1.0;
      });
    }
  }

  @override
  void dispose() {
    BottomSheetMusicPlayer.isExpandedNotifier.removeListener(
      _onExpandedChanged,
    );
    BottomSheetMusicPlayer.isFullscreenNotifier.removeListener(
      _onFullscreenChanged,
    );
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_currentState == _PlayerState.collapsed) {
        _currentState = _PlayerState.fullscreen;
        _animationController.forward();
        BottomSheetMusicPlayer.isExpandedNotifier.value = true;
        BottomSheetMusicPlayer.isFullscreenNotifier.value = true;
      } else if (_currentState == _PlayerState.fullscreen) {
        _currentState = _PlayerState.collapsed;
        _animationController.reverse();
        BottomSheetMusicPlayer.isExpandedNotifier.value = false;
        BottomSheetMusicPlayer.isFullscreenNotifier.value = false;
      } else {
        _currentState = _PlayerState.collapsed;
        _animationController.reverse();
        BottomSheetMusicPlayer.isExpandedNotifier.value = false;
        BottomSheetMusicPlayer.isFullscreenNotifier.value = false;
      }
    });
  }

  void _toggleFullscreen() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_currentState == _PlayerState.fullscreen) {
        _currentState = _PlayerState.expanded;

        _animationController.value = 1.0;
        BottomSheetMusicPlayer.isFullscreenNotifier.value = false;
      } else {
        _currentState = _PlayerState.fullscreen;
        BottomSheetMusicPlayer.isFullscreenNotifier.value = true;
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final musicPlayer = context.watch<MusicPlayerService>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final track = musicPlayer.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _heightAnimation,
      builder: (context, child) {
        final screenHeight = MediaQuery.of(context).size.height;
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final collapsedHeight = 88.0 + bottomPadding;
        final expandedHeight = screenHeight * 0.85;
        final fullscreenHeight = screenHeight;

        double targetHeight;
        if (_currentState == _PlayerState.fullscreen) {
          targetHeight = fullscreenHeight;
        } else if (_currentState == _PlayerState.expanded) {
          targetHeight = expandedHeight;
        } else {
          targetHeight = collapsedHeight;
        }

        final currentHeight =
            collapsedHeight +
            (targetHeight - collapsedHeight) * _heightAnimation.value;

        return Material(
          color: Colors.transparent,
          elevation: 0,
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeInOutCubic,
            height: currentHeight,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: _currentState == _PlayerState.fullscreen
                  ? BorderRadius.zero
                  : BorderRadius.only(
                      topLeft: const Radius.circular(28),
                      topRight: const Radius.circular(28),
                      bottomLeft: Radius.circular(
                        28 * (1 - _heightAnimation.value),
                      ),
                      bottomRight: Radius.circular(
                        28 * (1 - _heightAnimation.value),
                      ),
                    ),
              boxShadow: _currentState == _PlayerState.fullscreen
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.15 * _heightAnimation.value,
                        ),
                        blurRadius: 20,
                        offset: Offset(0, -6 * _heightAnimation.value),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: _currentState == _PlayerState.fullscreen
                  ? BorderRadius.zero
                  : BorderRadius.only(
                      topLeft: const Radius.circular(28),
                      topRight: const Radius.circular(28),
                      bottomLeft: Radius.circular(
                        28 * (1 - _heightAnimation.value),
                      ),
                      bottomRight: Radius.circular(
                        28 * (1 - _heightAnimation.value),
                      ),
                    ),
              child: _buildAnimatedContent(
                context,
                musicPlayer,
                track,
                colorScheme,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedContent(
    BuildContext context,
    MusicPlayerService musicPlayer,
    MusicTrack track,
    ColorScheme colorScheme,
  ) {
    return AnimatedSwitcher(
      duration: _animationDuration,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
      child: _currentState == _PlayerState.collapsed
          ? _buildCollapsedView(context, musicPlayer, track, colorScheme)
          : _buildExpandedView(context, musicPlayer, track, colorScheme),
    );
  }

  Widget _buildCollapsedView(
    BuildContext context,
    MusicPlayerService musicPlayer,
    MusicTrack track,
    ColorScheme colorScheme,
  ) {
    return SafeArea(
      key: const ValueKey('collapsed'),
      top: false,
      bottom: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleExpand,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Hero(
                  tag: 'album-art-${track.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: colorScheme.primaryContainer,
                      child: track.albumArtUrl != null
                          ? Image.network(
                              track.albumArtUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _buildAlbumArtPlaceholder(
                                      colorScheme,
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildAlbumArtPlaceholder(colorScheme),
                            )
                          : _buildAlbumArtPlaceholder(colorScheme),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          track.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Flexible(
                        child: Text(
                          track.artist,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                                fontSize: 13,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (musicPlayer.isPlaying) {
                        musicPlayer.pause();
                      } else {
                        musicPlayer.resume();
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: musicPlayer.isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : Icon(
                              musicPlayer.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 26,
                              color: colorScheme.onPrimary,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    MusicPlayerService musicPlayer,
    MusicTrack track,
    ColorScheme colorScheme,
  ) {
    return SafeArea(
      key: const ValueKey('expanded'),
      top: _currentState == _PlayerState.fullscreen,
      bottom: true,
      child: Column(
        children: [
          Row(
            children: [
              if (_currentState == _PlayerState.fullscreen)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleExpand,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, right: 16),
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.fullscreen_exit_rounded,
                        color: colorScheme.onSurface,
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth;
                        final albumSize = maxWidth < 380 ? maxWidth : 380.0;
                        return Hero(
                          tag: 'album-art-${track.id}',
                          child: Container(
                            width: albumSize,
                            height: albumSize,
                            margin: EdgeInsets.symmetric(
                              horizontal: (maxWidth - albumSize) / 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: track.albumArtUrl != null
                                  ? Image.network(
                                      track.albumArtUrl!,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return _buildLargeAlbumArtPlaceholder(
                                              context,
                                              colorScheme,
                                            );
                                          },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _buildLargeAlbumArtPlaceholder(
                                                context,
                                                colorScheme,
                                              ),
                                    )
                                  : _buildLargeAlbumArtPlaceholder(
                                      context,
                                      colorScheme,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      track.artist,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.album != null && track.album!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        track.album!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (track.duration != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(
                          Duration(milliseconds: track.duration!),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 40),

                    Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: colorScheme.primary,
                            inactiveTrackColor:
                                colorScheme.surfaceContainerHigh,
                            thumbColor: colorScheme.primary,
                            overlayColor: colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: musicPlayer.duration.inMilliseconds > 0
                                ? (musicPlayer.position.inMilliseconds /
                                          musicPlayer.duration.inMilliseconds)
                                      .clamp(0.0, 1.0)
                                : 0.0,
                            onChanged: (value) {
                              HapticFeedback.selectionClick();
                              final newPosition = Duration(
                                milliseconds:
                                    (value *
                                            musicPlayer.duration.inMilliseconds)
                                        .round(),
                              );
                              musicPlayer.seek(newPosition);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(musicPlayer.position),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                              ),
                              Text(
                                _formatDuration(musicPlayer.duration),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              musicPlayer.previous();
                            },
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.skip_previous_rounded,
                                size: 28,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              if (musicPlayer.isPlaying) {
                                musicPlayer.pause();
                              } else {
                                musicPlayer.resume();
                              }
                            },
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: musicPlayer.isLoading
                                  ? Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              colorScheme.onPrimary,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      musicPlayer.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 40,
                                      color: colorScheme.onPrimary,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              musicPlayer.next();
                            },
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.skip_next_rounded,
                                size: 28,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Icon(
                          musicPlayer.volume == 0
                              ? Icons.volume_off_rounded
                              : musicPlayer.volume < 0.5
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded,
                          size: 20,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: colorScheme.primary,
                              inactiveTrackColor:
                                  colorScheme.surfaceContainerHigh,
                              thumbColor: colorScheme.primary,
                              overlayColor: colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: musicPlayer.volume,
                              onChanged: (value) {
                                HapticFeedback.selectionClick();
                                musicPlayer.setVolume(value);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(musicPlayer.volume * 100).round()}%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArtPlaceholder(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildLargeAlbumArtPlaceholder(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
          size: 100,
        ),
      ),
    );
  }
}

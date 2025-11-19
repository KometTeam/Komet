import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const FullScreenVideoPlayer({Key? key, required this.videoUrl})
      : super(key: key);

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isDragging = false;
  double _currentVolume = 1.0;
  double _currentBrightness = 1.0;
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  double _volumeIndicatorOpacity = 0.0;
  double _brightnessIndicatorOpacity = 0.0;
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoPlay: true,
        looping: false,
        showControls: false, // Используем кастомные элементы управления
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blueAccent,
          handleColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.3),
          bufferedColor: Colors.white.withOpacity(0.5),
        ),
        allowFullScreen: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
      );

      // Получаем текущую громкость
      _currentVolume = _videoPlayerController!.value.volume;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _startHideControlsTimer();
      }
    } catch (e) {
      print('❌ [FullScreenVideoPlayer] Error initializing Chewie player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isDragging) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _togglePlayPause() {
    if (_chewieController?.isPlaying ?? false) {
      _chewieController?.pause();
    } else {
      _chewieController?.play();
    }
    _toggleControls();
  }

  void _displayVolumeIndicator(double volume) {
    setState(() {
      _showVolumeIndicator = true;
      _currentVolume = volume;
      _volumeIndicatorOpacity = 1.0;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _volumeIndicatorOpacity = 0.0;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _showVolumeIndicator = false;
            });
          }
        });
      }
    });
  }

  void _displayBrightnessIndicator(double brightness) {
    setState(() {
      _showBrightnessIndicator = true;
      _currentBrightness = brightness;
      _brightnessIndicatorOpacity = 1.0;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _brightnessIndicatorOpacity = 0.0;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _showBrightnessIndicator = false;
            });
          }
        });
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
  void dispose() {
    _hideControlsTimer?.cancel();
    _indicatorTimer?.cancel();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Видео плеер
            Center(
              child: _isLoading
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text(
                          'Загрузка видео...',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    )
                  : _hasError
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 60),
                            const SizedBox(height: 20),
                            const Text(
                              'Не удалось загрузить видео',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Проверьте интернет или попробуйте позже',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _hasError = false;
                                });
                                _initializePlayer();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Попробовать снова'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        )
                      : _chewieController != null &&
                              _chewieController!
                                  .videoPlayerController.value.isInitialized
                          ? GestureDetector(
                              onTap: _toggleControls,
                              onDoubleTap: _togglePlayPause,
                              onVerticalDragUpdate: (details) {
                                if (!_isDragging) {
                                  _isDragging = true;
                                  setState(() {
                                    _showControls = true;
                                  });
                                }
                                _hideControlsTimer?.cancel();

                                final delta = details.delta.dy;
                                final screenHeight = MediaQuery.of(context).size.height;
                                final change = -delta / screenHeight;

                                // Левая сторона экрана - яркость
                                if (details.globalPosition.dx <
                                    MediaQuery.of(context).size.width / 2) {
                                  final newBrightness = (_currentBrightness + change)
                                      .clamp(0.0, 1.0);
                                  _currentBrightness = newBrightness;
                                  // Здесь можно изменить яркость экрана, но это требует системных разрешений
                                  _displayBrightnessIndicator(newBrightness);
                                } else {
                                  // Правая сторона экрана - громкость
                                  final newVolume = (_currentVolume + change).clamp(0.0, 1.0);
                                  _videoPlayerController?.setVolume(newVolume);
                                  _currentVolume = newVolume;
                                  _displayVolumeIndicator(newVolume);
                                }
                              },
                              onVerticalDragEnd: (_) {
                                _isDragging = false;
                                _startHideControlsTimer();
                              },
                              child: Chewie(controller: _chewieController!),
                            )
                          : const Center(
                              child: Text(
                                'Ошибка плеера',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
            ),

            // Кастомные элементы управления
            if (!_isLoading && !_hasError && _chewieController != null)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildCustomControls(),
              ),

            // Индикатор громкости
            if (_showVolumeIndicator)
              Center(
                child: AnimatedOpacity(
                  opacity: _volumeIndicatorOpacity,
                  duration: const Duration(milliseconds: 200),
                  child: _buildVolumeIndicator(),
                ),
              ),

            // Индикатор яркости
            if (_showBrightnessIndicator)
              Center(
                child: AnimatedOpacity(
                  opacity: _brightnessIndicatorOpacity,
                  duration: const Duration(milliseconds: 200),
                  child: _buildBrightnessIndicator(),
                ),
              ),

            // Кнопка назад
            if (_showControls && !_isLoading && !_hasError)
              Positioned(
                top: 10,
                left: 10,
                child: SafeArea(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomControls() {
    if (_chewieController == null) return const SizedBox.shrink();

    final controller = _chewieController!;
    final videoController = controller.videoPlayerController;
    final isPlaying = controller.isPlaying;
    final duration = videoController.value.duration;
    final position = videoController.value.position;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Верхняя панель
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Spacer(),
                // Кнопка скорости воспроизведения
                _buildSpeedButton(controller),
                const SizedBox(width: 12),
                // Кнопка полноэкранного режима
                _buildFullScreenButton(),
              ],
            ),
          ),

          // Центральная кнопка воспроизведения/паузы
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),

          // Нижняя панель управления
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Прогресс бар
                VideoProgressIndicator(
                  videoController,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.blueAccent,
                    bufferedColor: Colors.white.withOpacity(0.3),
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                ),
                const SizedBox(height: 12),
                // Время и кнопки управления
                Row(
                  children: [
                    // Кнопка перемотки назад
                    IconButton(
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      onPressed: () {
                        final newPosition = position - const Duration(seconds: 10);
                        final clampedPosition = newPosition < Duration.zero
                            ? Duration.zero
                            : (newPosition > duration ? duration : newPosition);
                        videoController.seekTo(clampedPosition);
                      },
                    ),
                    // Время
                    Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // Кнопка перемотки вперед
                    IconButton(
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      onPressed: () {
                        final newPosition = position + const Duration(seconds: 10);
                        final clampedPosition = newPosition < Duration.zero
                            ? Duration.zero
                            : (newPosition > duration ? duration : newPosition);
                        videoController.seekTo(clampedPosition);
                      },
                    ),
                    const SizedBox(width: 8),
                    // Кнопка громкости
                    _buildVolumeButton(controller),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(ChewieController controller) {
    final speed = controller.videoPlayerController.value.playbackSpeed;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
          final currentIndex = speeds.indexOf(speed);
          final nextIndex = (currentIndex + 1) % speeds.length;
          controller.videoPlayerController.setPlaybackSpeed(speeds[nextIndex]);
          setState(() {});
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${speed}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Переключение ориентации
          if (MediaQuery.of(context).orientation == Orientation.portrait) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          } else {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            MediaQuery.of(context).orientation == Orientation.portrait
                ? Icons.fullscreen
                : Icons.fullscreen_exit,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeButton(ChewieController controller) {
    final isMuted = controller.videoPlayerController.value.volume == 0;
    return IconButton(
      icon: Icon(
        isMuted ? Icons.volume_off : Icons.volume_up,
        color: Colors.white,
      ),
      onPressed: () {
        if (isMuted) {
          controller.videoPlayerController.setVolume(_currentVolume > 0 ? _currentVolume : 0.5);
        } else {
          controller.videoPlayerController.setVolume(0);
        }
        setState(() {});
      },
    );
  }

  Widget _buildVolumeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _currentVolume == 0
                ? Icons.volume_off
                : _currentVolume < 0.5
                    ? Icons.volume_down
                    : Icons.volume_up,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              value: _currentVolume,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_currentVolume * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrightnessIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _currentBrightness < 0.3
                ? Icons.brightness_2
                : _currentBrightness < 0.7
                    ? Icons.brightness_medium
                    : Icons.brightness_high,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              value: _currentBrightness,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_currentBrightness * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

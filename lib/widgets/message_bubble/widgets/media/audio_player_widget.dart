import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:gwid/services/cache_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  final int duration;
  final String durationText;
  final String? wave;
  final Uint8List? waveBytes;
  final int? audioId;
  final Color textColor;
  final BorderRadius borderRadius;
  final double messageTextOpacity;

  const AudioPlayerWidget({
    super.key,
    required this.url,
    required this.duration,
    required this.durationText,
    this.wave,
    this.waveBytes,
    this.audioId,
    required this.textColor,
    required this.borderRadius,
    required this.messageTextOpacity,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isCompleted = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  List<int>? _waveformData;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _totalDuration = Duration(milliseconds: widget.duration);

    if (widget.waveBytes != null && widget.waveBytes!.isNotEmpty) {
      _waveformData = widget.waveBytes!.toList();
    } else if (widget.wave != null && widget.wave!.isNotEmpty) {
      _decodeWaveform(widget.wave!);
    }

    if (widget.url.isNotEmpty) {
      _preCacheAudio();
    }

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        final wasCompleted = _isCompleted;
        setState(() {
          _isPlaying = state.playing;
          _isLoading =
              state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
          _isCompleted = state.processingState == ProcessingState.completed;
        });

        if (state.processingState == ProcessingState.completed &&
            !wasCompleted) {
          _audioPlayer.pause();
        }
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        final reachedEnd =
            _totalDuration.inMilliseconds > 0 &&
            position.inMilliseconds >= _totalDuration.inMilliseconds - 50 &&
            _isPlaying;

        if (reachedEnd) {
          _audioPlayer.pause();
        }

        setState(() {
          _position = position;
          if (reachedEnd) {
            _isPlaying = false;
            _isCompleted = true;
          }
        });
      }
    });

    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null && duration.inMilliseconds > 0) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });
  }

  void _decodeWaveform(String waveBase64) {
    try {
      String base64Data = waveBase64;
      if (waveBase64.contains(',')) {
        base64Data = waveBase64.split(',')[1];
      }

      final bytes = base64Decode(base64Data);
      _waveformData = bytes.toList();
    } catch (e) {
      _waveformData = null;
    }
  }

  Future<void> _preCacheAudio() async {
    try {
      final cacheService = CacheService();
      final hasCached = await cacheService.hasCachedAudioFile(
        widget.url,
        customKey: widget.audioId?.toString(),
      );
      if (!hasCached) {
        await cacheService.cacheAudioFile(
          widget.url,
          customKey: widget.audioId?.toString(),
        );
      }
    } catch (e) {}
  }

  Future<void> _togglePlayPause() async {
    if (_isLoading) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      } else {
        if (_isCompleted ||
            (_totalDuration.inMilliseconds > 0 &&
                _position.inMilliseconds >=
                    _totalDuration.inMilliseconds - 100)) {
          await _audioPlayer.stop();
          await _audioPlayer.seek(Duration.zero);
          if (mounted) {
            setState(() {
              _isCompleted = false;
              _isPlaying = false;
              _position = Duration.zero;
            });
          }
          await Future.delayed(const Duration(milliseconds: 150));
        }

        if (_audioPlayer.processingState == ProcessingState.idle) {
          if (widget.url.isNotEmpty) {
            final cacheService = CacheService();
            var cachedFile = await cacheService.getCachedAudioFile(
              widget.url,
              customKey: widget.audioId?.toString(),
            );

            if (cachedFile != null && await cachedFile.exists()) {
              await _audioPlayer.setFilePath(cachedFile.path);
            } else {
              final hasCached = await cacheService.hasCachedAudioFile(
                widget.url,
                customKey: widget.audioId?.toString(),
              );

              if (!hasCached) {
                try {
                  await _audioPlayer.setUrl(widget.url);

                  cacheService
                      .cacheAudioFile(
                        widget.url,
                        customKey: widget.audioId?.toString(),
                      )
                      .catchError((error) => null);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Не удалось загрузить аудио: ${e.toString()}',
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  return;
                }
              } else {
                await _audioPlayer.setUrl(widget.url);
              }
            }
          }
        }
        await _audioPlayer.play();
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _seek(Duration position) async {
    if (_audioPlayer.processingState == ProcessingState.idle) {
      if (widget.url.isNotEmpty) {
        final cacheService = CacheService();
        var cachedFile = await cacheService.getCachedAudioFile(
          widget.url,
          customKey: widget.audioId?.toString(),
        );

        if (cachedFile != null && await cachedFile.exists()) {
          await _audioPlayer.setFilePath(cachedFile.path);
        } else {
          await _audioPlayer.setUrl(widget.url);
        }
      }
    }
    await _audioPlayer.seek(position);
    if (mounted) {
      setState(() {
        _isCompleted = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDuration.inMilliseconds > 0
        ? _position.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onLongPress: () {},
      child: Container(
        decoration: BoxDecoration(
          color: widget.textColor.withValues(alpha: 0.05),
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: widget.textColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.textColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: widget.textColor.withValues(
                            alpha: 0.8 * widget.messageTextOpacity,
                          ),
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_waveformData != null && _waveformData!.isNotEmpty)
                      SizedBox(
                        height: 30,
                        child: CustomPaint(
                          painter: WaveformPainter(
                            waveform: _waveformData!,
                            progress: progress,
                            color: widget.textColor.withValues(
                              alpha: 0.6 * widget.messageTextOpacity,
                            ),
                            progressColor: widget.textColor.withValues(
                              alpha: 0.9 * widget.messageTextOpacity,
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) {
                                  final tapProgress =
                                      details.localPosition.dx /
                                      constraints.maxWidth;
                                  final clampedProgress = tapProgress.clamp(
                                    0.0,
                                    1.0,
                                  );
                                  final newPosition = Duration(
                                    milliseconds:
                                        (_totalDuration.inMilliseconds *
                                                clampedProgress)
                                            .round(),
                                  );
                                  _seek(newPosition);
                                },
                                onLongPress: () {},
                              );
                            },
                          ),
                        ),
                      )
                    else
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: widget.textColor.withValues(
                            alpha: 0.8 * widget.messageTextOpacity,
                          ),
                          inactiveTrackColor: widget.textColor.withValues(
                            alpha: 0.1,
                          ),
                          thumbColor: widget.textColor.withValues(
                            alpha: 0.9 * widget.messageTextOpacity,
                          ),
                          overlayColor: widget.textColor.withValues(alpha: 0.1),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (value) {
                            final newPosition = Duration(
                              milliseconds:
                                  (_totalDuration.inMilliseconds * value)
                                      .round(),
                            );
                            _seek(newPosition);
                          },
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            color: widget.textColor.withValues(
                              alpha: 0.7 * widget.messageTextOpacity,
                            ),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _totalDuration.inMilliseconds > 0
                              ? _formatDuration(_totalDuration)
                              : widget.durationText,
                          style: TextStyle(
                            color: widget.textColor.withValues(
                              alpha: 0.7 * widget.messageTextOpacity,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<int> waveform;
  final double progress;
  final Color color;
  final Color progressColor;

  WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.color,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / waveform.length;
    final progressX = size.width * progress;

    for (int i = 0; i < waveform.length; i++) {
      final x = i * barWidth;
      final normalizedHeight = (waveform[i] / 255.0).clamp(0.1, 1.0);
      final barHeight = size.height * normalizedHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          (size.height - barHeight) / 2,
          barWidth * 0.8,
          barHeight,
        ),
        const Radius.circular(2),
      );

      paint.color = x < progressX ? progressColor : color;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveform != waveform ||
        oldDelegate.color != color ||
        oldDelegate.progressColor != progressColor;
  }
}

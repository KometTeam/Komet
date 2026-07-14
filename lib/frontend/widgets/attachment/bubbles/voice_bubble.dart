import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ogg_opus_player/ogg_opus_player.dart';
import 'package:komet/main.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/komet_settings.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/media_cache.dart';
import '../../custom_notification.dart';
import '../../small_spinner.dart';

class VoiceMessageBubble extends StatefulWidget {
  final int duration;
  final String url;
  final Color textColor;
  final bool isMe;
  final bool deleted;
  final String? status;
  final ValueListenable<int>? otherReadTime;
  final int time;
  final ColorScheme cs;
  final String? waveData;
  final int chatId;
  final String messageId;
  final int? audioId;
  final String? preloadedText;

  const VoiceMessageBubble({
    super.key,
    required this.duration,
    required this.url,
    required this.textColor,
    required this.isMe,
    this.deleted = false,
    this.status,
    this.otherReadTime,
    required this.time,
    required this.cs,
    this.waveData,
    required this.chatId,
    required this.messageId,
    this.audioId,
    this.preloadedText,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _isPlaying = false;
  final ValueNotifier<double> _progress = ValueNotifier(0.0);
  bool _transcriptionVisible = false;
  String? _transcriptionText;
  bool _transcriptionLoading = false;

  OggOpusPlayer? _player;
  bool _loadingAudio = false;
  Timer? _ticker;
  late final List<int> _amps = _parseWave(widget.waveData);

  static List<int> _parseWave(String? data) {
    if (data == null || data.isEmpty) return const [];
    return data.codeUnits;
  }

  @override
  void initState() {
    super.initState();
    _transcriptionText = widget.preloadedText;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _player?.state.removeListener(_onPlayerState);
    _player?.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_loadingAudio) return;

    if (_player != null) {
      if (_isPlaying) {
        _player!.pause();
      } else {
        if (widget.duration > 0 &&
            _player!.currentPosition >= widget.duration - 0.05) {
          _progress.value = 0;
        }
        _player!.play();
      }
      return;
    }

    final url = widget.url;
    if (url.isEmpty) return;

    setState(() => _loadingAudio = true);
    try {
      final name = '${widget.audioId ?? widget.messageId}.ogg';
      final file = await MediaCache.getOrDownload(name, url);
      if (!mounted) return;
      if (file == null) {
        showCustomNotification(context, 'Не удалось загрузить аудио');
        return;
      }
      final player = OggOpusPlayer(file.path);
      _player = player;
      player.state.addListener(_onPlayerState);
      _ticker = Timer.periodic(
        const Duration(milliseconds: 60),
        (_) => _onTick(),
      );
      player.play();
    } catch (e) {
      logger.w('VoiceBubble._togglePlay: $e');
      if (mounted) showCustomNotification(context, 'Ошибка воспроизведения');
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  void _onTick() {
    final player = _player;
    if (player == null || widget.duration <= 0) return;
    final pos = player.currentPosition;
    _progress.value = (pos / widget.duration).clamp(0.0, 1.0);
  }

  void _onPlayerState() {
    final state = _player?.state.value;
    if (!mounted) return;
    final playing = state == PlayerState.playing;
    if (playing != _isPlaying) setState(() => _isPlaying = playing);
    if (state == PlayerState.ended) {
      _progress.value = 1.0;
    }
  }

  Widget _buildStatusIcon() {
    final rt = widget.otherReadTime;
    if (rt == null) return _statusIconFor(widget.status);
    return ValueListenableBuilder<int>(
      valueListenable: rt,
      builder: (context, readTime, _) =>
          _statusIconFor(_upgradedStatus(readTime)),
    );
  }

  String? _upgradedStatus(int readTime) {
    final base = widget.status;
    if ((base == null || base == 'sent') &&
        readTime > 0 &&
        readTime >= widget.time) {
      return 'read';
    }
    return base;
  }

  Widget _statusIconFor(String? status) {
    IconData icon;
    Color color;

    if (status == null || status == 'sent') {
      icon = Symbols.check;
      color = Colors.white54;
    } else {
      switch (status) {
        case 'sending':
        case 'pending':
          icon = Symbols.schedule;
          color = widget.cs.onPrimaryContainer.withValues(alpha: 0.55);
        case 'sent':
          icon = Symbols.check;
          color = widget.cs.onPrimaryContainer.withValues(alpha: 0.55);
        case 'delivered':
          icon = Symbols.done_all;
          color = widget.cs.onPrimaryContainer.withValues(alpha: 0.55);
        case 'read':
          icon = Symbols.done_all;
          color = kReadReceiptBlue;
        case 'error':
          icon = Symbols.error;
          color = Colors.redAccent;
        default:
          icon = Symbols.check;
          color = widget.cs.onPrimaryContainer.withValues(alpha: 0.55);
      }
    }

    return Icon(icon, size: 14, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final waveInactiveColor = widget.isMe
        ? widget.cs.onPrimaryContainer.withValues(alpha: 0.35)
        : widget.cs.surfaceContainerHighest;
    final waveActiveColor = widget.isMe
        ? widget.cs.onPrimaryContainer.withValues(alpha: 0.7)
        : widget.cs.primary;

    return SizedBox(
      width: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? widget.cs.onPrimaryContainer.withValues(alpha: 0.12)
                        : widget.cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: _loadingAudio
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: SmallSpinner(
                            size: 36,
                            color: widget.isMe
                                ? widget.cs.onPrimaryContainer
                                : widget.cs.primary,
                          ),
                        )
                      : Icon(
                          _isPlaying ? Symbols.pause : Symbols.play_arrow,
                          color: widget.isMe
                              ? widget.cs.onPrimaryContainer
                              : widget.cs.primary,
                          size: 18,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _progress,
                    builder: (context, progress, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _WaveformPainter(
                        amps: _amps,
                        progress: progress,
                        active: waveActiveColor,
                        inactive: waveInactiveColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _requestTranscription,
                child: SizedBox(
                  width: 20,
                  height: 32,
                  child: Center(
                    child: _transcriptionLoading
                        ? SmallSpinner(
                            size: 12,
                            color: widget.textColor.withValues(alpha: 0.6),
                          )
                        : Text(
                            'Т',
                            style: TextStyle(
                              color: widget.textColor.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    formatSecondsMmSs(widget.duration),
                    style: TextStyle(
                      color: widget.textColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topLeft,
                  child: _transcriptionVisible
                      ? Text(
                          _transcriptionText ?? '',
                          style: TextStyle(
                            color: widget.textColor.withValues(alpha: 0.8),
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 10,
                          overflow: TextOverflow.ellipsis,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              if (!_transcriptionVisible) ...[
                Text(
                  formatClock(
                    DateTime.fromMillisecondsSinceEpoch(widget.time),
                    withSeconds: KometSettings.fullTimestamp.value,
                  ),
                  style: TextStyle(
                    color: widget.textColor.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                if (widget.isMe) ...[
                  const SizedBox(width: 2),
                  _buildStatusIcon(),
                ],
                if (widget.deleted) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Symbols.delete,
                    size: 13,
                    color: widget.textColor.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ],
          ),
          if (_transcriptionVisible) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  formatClock(
                    DateTime.fromMillisecondsSinceEpoch(widget.time),
                    withSeconds: KometSettings.fullTimestamp.value,
                  ),
                  style: TextStyle(
                    color: widget.textColor.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                if (widget.isMe) ...[
                  const SizedBox(width: 2),
                  _buildStatusIcon(),
                ],
                if (widget.deleted) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Symbols.delete,
                    size: 13,
                    color: widget.textColor.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _requestTranscription() async {
    if (widget.audioId == null) return;

    if (_transcriptionVisible && _transcriptionText != null) {
      setState(() {
        _transcriptionVisible = false;
      });
      return;
    }

    if (TranscriptionCache.has(widget.messageId)) {
      final cached = TranscriptionCache.get(widget.messageId)!;
      setState(() {
        _transcriptionText = cached.text ?? 'не удалось распознать текст';
        _transcriptionVisible = true;
      });
      return;
    }

    setState(() {
      _transcriptionLoading = true;
    });

    try {
      final result = await messagesModule.requestTranscription(
        widget.chatId,
        int.tryParse(widget.messageId) ?? 0,
        widget.audioId!,
      );

      TranscriptionCache.put(widget.messageId, result);

      if (!mounted) return;
      setState(() {
        _transcriptionLoading = false;
        if (result.status == 1) {
          _transcriptionText = (result.text == null || result.text!.isEmpty)
              ? 'не удалось распознать текст'
              : result.text;
          _transcriptionVisible = true;
        } else if (result.status == 0) {
          _transcriptionText = 'транскрибация...';
          _transcriptionVisible = true;
        }
      });
    } catch (e) {
      logger.w('VoiceBubble._requestTranscription: $e');
      if (!mounted) return;
      setState(() {
        _transcriptionLoading = false;
        _transcriptionText = 'ошибка транскрибации';
        _transcriptionVisible = true;
      });
    }
  }
}

class _WaveformPainter extends CustomPainter {
  final List<int> amps;
  final double progress;
  final Color active;
  final Color inactive;

  const _WaveformPainter({
    required this.amps,
    required this.progress,
    required this.active,
    required this.inactive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;

    if (amps.isEmpty) {
      final track = Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(0, center),
        Offset(size.width, center),
        track..color = inactive,
      );
      if (progress > 0) {
        canvas.drawLine(
          Offset(0, center),
          Offset(size.width * progress.clamp(0.0, 1.0), center),
          track..color = active,
        );
      }
      return;
    }

    final n = amps.length;
    var maxAmp = 1;
    for (final a in amps) {
      if (a > maxAmp) maxAmp = a;
    }
    final slot = size.width / n;
    final barW = (slot * 0.55).clamp(1.0, 3.0);
    final paint = Paint();

    for (var i = 0; i < n; i++) {
      final h = ((amps[i] / maxAmp) * size.height).clamp(2.0, size.height);
      final x = i * slot + (slot - barW) / 2;
      paint.color = ((i + 0.5) / n) <= progress ? active : inactive;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, center - h / 2, barW, h),
          Radius.circular(barW / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.active != active ||
      old.inactive != inactive ||
      !identical(old.amps, amps);
}

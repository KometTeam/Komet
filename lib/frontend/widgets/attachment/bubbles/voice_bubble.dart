import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/main.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/komet_settings.dart';
import '../../../../core/media/media_playback.dart';
import '../../../../core/media/voice_audio_controller.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/logger.dart';
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
  final int senderId;
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
    required this.senderId,
    this.audioId,
    this.preloadedText,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _transcriptionVisible = false;
  String? _transcriptionText;
  bool _transcriptionLoading = false;

  late final VoiceAudioController _audio;
  late final List<int> _amps = _parseWave(widget.waveData);

  static List<int> _parseWave(String? data) {
    if (data == null || data.isEmpty) return const [];
    return data.codeUnits;
  }

  @override
  void initState() {
    super.initState();
    _transcriptionText = widget.preloadedText;
    _audio = MediaPlayback.instance.acquireVoice(
      cacheName: _cacheName,
      resolveUrl: () async => widget.url,
      fallbackDuration: Duration(seconds: widget.duration),
    );
    _audio.failure.addListener(_onFailure);
  }

  @override
  void dispose() {
    _audio.failure.removeListener(_onFailure);
    MediaPlayback.instance.releaseVoice(_audio);
    super.dispose();
  }

  String get _cacheName => '${widget.audioId ?? widget.messageId}.ogg';

  void _claimPlayback() {
    MediaPlayback.instance.activateVoice(
      VoiceTrack(
        cacheName: _cacheName,
        chatId: widget.chatId,
        messageId: widget.messageId,
        senderId: widget.senderId,
        isMe: widget.isMe,
        time: widget.time,
        audio: _audio,
      ),
    );
  }

  void _toggle() {
    _claimPlayback();
    _audio.toggle();
  }

  void _onFailure() {
    if (!mounted) return;
    switch (_audio.failure.value) {
      case VoiceAudioFailure.none:
        return;
      case VoiceAudioFailure.download:
        showCustomNotification(context, 'Не удалось загрузить аудио');
      case VoiceAudioFailure.playback:
        showCustomNotification(context, 'Ошибка воспроизведения');
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

  Color get _accent =>
      widget.isMe ? widget.cs.onPrimaryContainer : widget.cs.primary;

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: widget.isMe
              ? widget.cs.onPrimaryContainer.withValues(alpha: 0.12)
              : widget.cs.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _audio.downloaded,
            _audio.downloadProgress,
            _audio.playing,
          ]),
          builder: (context, _) {
            final progress = _audio.downloadProgress.value;
            if (progress != null) {
              return Padding(
                padding: const EdgeInsets.all(4),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress > 0 ? progress : null,
                  color: _accent,
                  backgroundColor: _accent.withValues(alpha: 0.2),
                ),
              );
            }
            final IconData icon;
            if (_audio.playing.value) {
              icon = Symbols.pause;
            } else if (_audio.downloaded.value) {
              icon = Symbols.play_arrow;
            } else {
              icon = Symbols.arrow_downward;
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                icon,
                key: ValueKey(icon),
                color: _accent,
                size: 18,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeLabel() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _audio.position,
        _audio.duration,
        _audio.playing,
      ]),
      builder: (context, _) {
        final elapsed = _audio.position.value;
        final total = _audio.duration.value;
        final seconds = elapsed > 0 ? elapsed.round() : total.round();
        return Text(
          formatSecondsMmSs(seconds),
          style: TextStyle(
            color: widget.textColor.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final waveInactiveColor = widget.textColor.withValues(alpha: 0.35);
    final waveActiveColor = widget.isMe
        ? widget.cs.onPrimaryContainer
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
              _buildPlayButton(),
              const SizedBox(width: 10),
              Expanded(
                child: _SeekableWaveform(
                  onClaim: _claimPlayback,
                  onToggle: _toggle,
                  audio: _audio,
                  amps: _amps,
                  active: waveActiveColor,
                  inactive: waveInactiveColor,
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
              SizedBox(width: 32, child: Center(child: _buildTimeLabel())),
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

class _SeekableWaveform extends StatefulWidget {
  final VoiceAudioController audio;
  final List<int> amps;
  final Color active;
  final Color inactive;
  final VoidCallback onClaim;
  final VoidCallback onToggle;

  const _SeekableWaveform({
    required this.audio,
    required this.amps,
    required this.active,
    required this.inactive,
    required this.onClaim,
    required this.onToggle,
  });

  @override
  State<_SeekableWaveform> createState() => _SeekableWaveformState();
}

class _SeekableWaveformState extends State<_SeekableWaveform> {
  static const double _hitHeight = 32;
  static const double _waveHeight = 26;

  double _width = 0;

  VoiceAudioController get _audio => widget.audio;

  void _claimPlayback() => widget.onClaim();

  void _toggle() => widget.onToggle();

  double _secondsAt(double dx) {
    final total = _audio.duration.value;
    if (_width <= 0 || total <= 0) return 0;
    return (dx / _width).clamp(0.0, 1.0) * total;
  }

  void _onTapUp(TapUpDetails details) {
    if (!_audio.downloaded.value) {
      _toggle();
      return;
    }
    _claimPlayback();
    _audio.seekTo(_secondsAt(details.localPosition.dx));
  }

  void _onDragStart(DragStartDetails details) {
    if (!_audio.downloaded.value) return;
    _claimPlayback();
    _audio.scrubStart();
    _audio.scrubTo(_secondsAt(details.localPosition.dx));
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_audio.scrubbing) return;
    _audio.scrubTo(_secondsAt(details.localPosition.dx));
  }

  void _onDragEnd(DragEndDetails details) => _audio.scrubEnd();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _onTapUp,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: _audio.scrubEnd,
          child: SizedBox(
            height: _hitHeight,
            child: Center(
              child: SizedBox(
                height: _waveHeight,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _audio.position,
                    _audio.duration,
                    _audio.playing,
                    _audio.downloaded,
                  ]),
                  builder: (context, _) {
                    final total = _audio.duration.value;
                    final progress = total > 0
                        ? (_audio.position.value / total).clamp(0.0, 1.0)
                        : 0.0;
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _WaveformPainter(
                        amps: widget.amps,
                        progress: progress,
                        active: widget.active,
                        inactive: widget.inactive,
                        knob: _audio.downloaded.value && progress > 0,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<int> amps;
  final double progress;
  final Color active;
  final Color inactive;
  final bool knob;

  const _WaveformPainter({
    required this.amps,
    required this.progress,
    required this.active,
    required this.inactive,
    this.knob = false,
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
      _paintKnob(canvas, size, center);
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

    _paintKnob(canvas, size, center);
  }

  void _paintKnob(Canvas canvas, Size size, double center) {
    if (!knob) return;
    final x = (size.width * progress.clamp(0.0, 1.0)).clamp(1.5, size.width - 1.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 1.5, 0, 3, size.height),
        const Radius.circular(1.5),
      ),
      Paint()..color = active,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.active != active ||
      old.inactive != inactive ||
      old.knob != knob ||
      !identical(old.amps, amps);
}

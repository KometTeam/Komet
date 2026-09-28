import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/main.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/ios_release.dart';
import '../../../../core/config/komet_settings.dart';
import '../../../../core/media/media_playback.dart';
import '../../../../core/media/voice_audio_controller.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/logger.dart';
import '../../custom_notification.dart';
import '../../small_spinner.dart';
import '../../text_with_meta.dart';

class VoiceMessageBubble extends StatefulWidget {
  final int duration;
  final String url;
  final Color textColor;
  final bool isMe;
  final bool deleted;
  // #***! время и статус рисует футер с реакциями, тогда здесь не дублируем
  final bool showMeta;
  final String? status;
  final ValueListenable<int>? otherReadTime;
  final int time;
  final ColorScheme cs;
  final String? waveData;
  final int chatId;
  final String messageId;
  final int? sourceChatId;
  final String? sourceMessageId;
  final int senderId;
  final int? audioId;
  final String? preloadedText;
  final ValueListenable<List<double>>? uploadProgress;

  const VoiceMessageBubble({
    super.key,
    required this.duration,
    required this.url,
    required this.textColor,
    required this.isMe,
    this.deleted = false,
    this.showMeta = true,
    this.status,
    this.otherReadTime,
    required this.time,
    required this.cs,
    this.waveData,
    required this.chatId,
    required this.messageId,
    this.sourceChatId,
    this.sourceMessageId,
    required this.senderId,
    this.audioId,
    this.preloadedText,
    this.uploadProgress,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

const double _transcriptionMaxHeight = 132;

// #***! размеры голосового на iOS: кнопка 44, столбики 2,5 через 1,75
const double _kIosPlaySize = 44;
const double _kIosWaveHeight = 22;
const double _kIosWaveHitHeight = 28;
const double _kIosWaveBarWidth = 2.5;
const double _kIosWaveBarGap = 1.75;
const double _kIosTimeSize = 11;
// #***! кнопка расшифровки: одна капсула акцентного цвета
const double _kIosTranscribeWidth = 40;
const double _kIosTranscribeHeight = 28;
const List<FontFeature> _kTabularDigits = [FontFeature.tabularFigures()];

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
    TranscriptionCache.listen(_sourceMessageId, _onTranscriptionPush);
    _adoptCachedTranscription();
  }

  @override
  void dispose() {
    TranscriptionCache.unlisten(_sourceMessageId, _onTranscriptionPush);
    _audio.failure.removeListener(_onFailure);
    MediaPlayback.instance.releaseVoice(_audio);
    super.dispose();
  }

  void _adoptCachedTranscription() {
    final cached = TranscriptionCache.get(_sourceMessageId);
    if (cached == null || cached.status != 1) return;
    _transcriptionText = cached.text ?? TranscriptionResult.emptyText;
    _transcriptionVisible = TranscriptionCache.isExpanded(_sourceMessageId);
  }

  void _onTranscriptionPush() {
    if (!mounted) return;
    setState(() {
      _transcriptionLoading = false;
      _adoptCachedTranscription();
    });
  }

  void _showTranscription(String text) {
    _transcriptionText = text;
    _transcriptionVisible = true;
    TranscriptionCache.setExpanded(_sourceMessageId, true);
  }

  String get _cacheName => '${widget.audioId ?? _sourceMessageId}.ogg';

  int get _sourceChatId => widget.sourceChatId ?? widget.chatId;

  String get _sourceMessageId => widget.sourceMessageId ?? widget.messageId;

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

  bool get _uploading => widget.uploadProgress != null;

  void _toggle() {
    if (_uploading) return;
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
    final uploading = widget.uploadProgress;
    return GestureDetector(
      onTap: uploading == null ? _toggle : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: widget.isMe
              ? widget.cs.onPrimaryContainer.withValues(alpha: 0.12)
              : widget.cs.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: uploading != null
            ? _buildUploadIndicator(uploading)
            : AnimatedBuilder(
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

  Color get _iosPlayIconColor =>
      widget.isMe ? widget.cs.primaryContainer : widget.cs.onPrimary;

  // #***! на iOS залитая кнопка акцентного цвета с белым значком
  Widget _buildIosPlayButton() {
    final uploading = widget.uploadProgress;
    final iconColor = _iosPlayIconColor;
    return GestureDetector(
      key: const ValueKey('voice-play'),
      onTap: uploading == null ? _toggle : null,
      child: Container(
        width: _kIosPlaySize,
        height: _kIosPlaySize,
        decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
        child: uploading != null
            ? _buildUploadIndicator(
                uploading,
                color: iconColor,
                padding: 10,
                strokeWidth: 2.5,
              )
            : AnimatedBuilder(
                animation: Listenable.merge([
                  _audio.downloaded,
                  _audio.downloadProgress,
                  _audio.playing,
                ]),
                builder: (context, _) {
                  final progress = _audio.downloadProgress.value;
                  if (progress != null) {
                    return Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        value: progress > 0 ? progress : null,
                        color: iconColor,
                        backgroundColor: iconColor.withValues(alpha: 0.25),
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
                  // #***! треугольник чуть правее центра, иначе кажется смещённым
                  final nudge = icon == Symbols.play_arrow ? 1.5 : 0.0;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Transform.translate(
                      key: ValueKey(icon),
                      offset: Offset(nudge, 0),
                      child: Icon(icon, color: iconColor, size: 26, fill: 1),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildUploadIndicator(
    ValueListenable<List<double>> progress, {
    Color? color,
    double padding = 4,
    double strokeWidth = 2,
  }) {
    final tint = color ?? _accent;
    return Padding(
      padding: EdgeInsets.all(padding),
      child: ValueListenableBuilder<List<double>>(
        valueListenable: progress,
        builder: (context, values, _) {
          final value = values.isEmpty
              ? 0.0
              : values.reduce((a, b) => a + b) / values.length;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            builder: (context, shown, _) => CircularProgressIndicator(
              strokeWidth: strokeWidth,
              value: shown >= 1.0 ? null : shown,
              color: tint,
              backgroundColor: tint.withValues(
                alpha: color == null ? 0.2 : 0.25,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeLabel({bool ios = false}) {
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
          style: ios
              ? TextStyle(
                  color: widget.textColor.withValues(alpha: 0.55),
                  fontSize: 13,
                  height: 1.1,
                  fontFeatures: _kTabularDigits,
                )
              : TextStyle(
                  color: widget.textColor.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
        );
      },
    );
  }

  Widget _buildIosMetaRow() {
    final dim = widget.textColor.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatClock(
            DateTime.fromMillisecondsSinceEpoch(widget.time),
            withSeconds: KometSettings.fullTimestamp.value,
          ),
          style: TextStyle(
            color: dim,
            fontSize: _kIosTimeSize,
            fontFeatures: _kTabularDigits,
          ),
        ),
        if (widget.isMe) ...[const SizedBox(width: 2), _buildStatusIcon()],
        if (widget.deleted) ...[
          const SizedBox(width: 2),
          Icon(Symbols.delete, size: 13, color: dim),
        ],
      ],
    );
  }

  Widget _buildTranscribeButton() {
    return GestureDetector(
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
    );
  }

  Widget _buildTranscriptionBox() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _transcriptionMaxHeight),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Text(
          _transcriptionText ?? '',
          style: TextStyle(
            color: widget.textColor.withValues(alpha: 0.8),
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  // #***! свёрнуто «→Т», развёрнуто шеврон вверх, смена плавная
  Widget _buildIosTranscribeChip() {
    final accent = _accent;
    final Widget glyph;
    if (_transcriptionLoading) {
      glyph = SmallSpinner(
        key: const ValueKey('voice-transcribe-loading'),
        size: 14,
        color: accent,
      );
    } else if (_transcriptionVisible) {
      glyph = Icon(
        Symbols.keyboard_arrow_up,
        key: const ValueKey('voice-transcribe-expanded'),
        size: 22,
        color: accent,
      );
    } else {
      glyph = Text(
        '→Т',
        key: const ValueKey('voice-transcribe-collapsed'),
        style: TextStyle(
          color: accent,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      );
    }
    return Semantics(
      button: true,
      label: _transcriptionVisible ? 'Скрыть расшифровку' : 'Расшифровать',
      child: GestureDetector(
        key: const ValueKey('voice-transcribe'),
        behavior: HitTestBehavior.opaque,
        onTap: _requestTranscription,
        child: Container(
          width: _kIosTranscribeWidth,
          height: _kIosTranscribeHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(_kIosTranscribeHeight / 2),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: glyph,
          ),
        ),
      ),
    );
  }

  // #***! текст расшифровки во всю ширину, время в конце последней строки
  Widget _buildIosTranscriptionBody() {
    final text = Text(
      _transcriptionText ?? '',
      style: TextStyle(color: widget.textColor, fontSize: 16, height: 1.3),
    );
    if (!widget.showMeta) return text;
    return TextWithMeta(
      text: text,
      meta: Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: _buildIosMetaRow(),
      ),
    );
  }

  // #***! iOS: кнопка слева, под волной длительность, время справа внизу
  Widget _buildIos(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildIosPlayButton(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SeekableWaveform(
                      onClaim: _claimPlayback,
                      onToggle: _toggle,
                      audio: _audio,
                      amps: _amps,
                      active: _accent,
                      inactive: _accent.withValues(alpha: 0.38),
                      iosBars: true,
                    ),
                    const SizedBox(height: 2),
                    _buildTimeLabel(ios: true),
                  ],
                ),
              ),
              if (widget.audioId != null) ...[
                const SizedBox(width: 8),
                _buildIosTranscribeChip(),
              ],
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: _transcriptionVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildIosTranscriptionBody(),
                  )
                : const SizedBox.shrink(),
          ),
          if (!_transcriptionVisible && widget.showMeta)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildIosMetaRow(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (IosRelease.isIOS) return _buildIos(context);
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
              _buildTranscribeButton(),
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
                      ? _buildTranscriptionBox()
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
        TranscriptionCache.setExpanded(_sourceMessageId, false);
      });
      return;
    }

    if (TranscriptionCache.has(_sourceMessageId)) {
      final cached = TranscriptionCache.get(_sourceMessageId)!;
      setState(
        () => _showTranscription(cached.text ?? TranscriptionResult.emptyText),
      );
      return;
    }

    setState(() {
      _transcriptionLoading = true;
    });

    try {
      final result = await messagesModule.requestTranscription(
        _sourceChatId,
        int.tryParse(_sourceMessageId) ?? 0,
        widget.audioId!,
      );

      TranscriptionCache.put(_sourceMessageId, result);

      if (!mounted) return;
      setState(() {
        _transcriptionLoading = false;
        if (result.status == 1) {
          _showTranscription(
            (result.text == null || result.text!.isEmpty)
                ? TranscriptionResult.emptyText
                : result.text!,
          );
        } else if (result.status == 0) {
          _showTranscription('транскрибация...');
        }
      });
    } catch (e) {
      logger.w('VoiceBubble._requestTranscription: $e');
      if (!mounted) return;
      setState(() {
        _transcriptionLoading = false;
        _showTranscription('ошибка транскрибации');
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
  final bool iosBars;

  const _SeekableWaveform({
    required this.audio,
    required this.amps,
    required this.active,
    required this.inactive,
    required this.onClaim,
    required this.onToggle,
    this.iosBars = false,
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
            height: widget.iosBars ? _kIosWaveHitHeight : _hitHeight,
            child: Center(
              child: SizedBox(
                height: widget.iosBars ? _kIosWaveHeight : _waveHeight,
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
                        iosBars: widget.iosBars,
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
  final bool iosBars;

  const _WaveformPainter({
    required this.amps,
    required this.progress,
    required this.active,
    required this.inactive,
    this.knob = false,
    this.iosBars = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (iosBars) {
      _paintIosBars(canvas, size);
      return;
    }
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

  // #***! iOS: столбики фиксированной ширины растут от нижней линии,
  // #***! тишина — точки по 3 pt, лишние отсчёты прореживаем
  void _paintIosBars(Canvas canvas, Size size) {
    final baseline = size.height;
    if (amps.isEmpty) {
      final track = Paint()
        ..strokeWidth = _kIosWaveBarWidth
        ..strokeCap = StrokeCap.round;
      final y = baseline - 1.5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        track..color = inactive,
      );
      if (progress > 0) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width * progress.clamp(0.0, 1.0), y),
          track..color = active,
        );
      }
      _paintKnob(canvas, size, 0);
      return;
    }
    final n = amps.length;
    var maxAmp = 1;
    for (final a in amps) {
      if (a > maxAmp) maxAmp = a;
    }
    const slot = _kIosWaveBarWidth + _kIosWaveBarGap;
    final bars = (size.width / slot).floor().clamp(1, n);
    final step = n / bars;
    final paint = Paint();
    for (var i = 0; i < bars; i++) {
      final amp = amps[(i * step).floor().clamp(0, n - 1)];
      final h = amp <= 0
          ? 3.0
          : ((amp / maxAmp) * size.height).clamp(3.0, size.height);
      paint.color = ((i + 0.5) / bars) <= progress ? active : inactive;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * slot, baseline - h, _kIosWaveBarWidth, h),
          const Radius.circular(_kIosWaveBarWidth / 2),
        ),
        paint,
      );
    }
    _paintKnob(canvas, size, 0);
  }

  void _paintKnob(Canvas canvas, Size size, double center) {
    if (!knob) return;
    final x = (size.width * progress.clamp(0.0, 1.0)).clamp(
      1.5,
      size.width - 1.5,
    );
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
      old.iosBars != iosBars ||
      !identical(old.amps, amps);
}

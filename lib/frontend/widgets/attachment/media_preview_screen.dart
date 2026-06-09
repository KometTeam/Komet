import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/core/utils/image_utils.dart';
import 'package:komet/frontend/widgets/attachment/photo_draw_editor.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';

const Color _kAccent = Color(0xFF2F8FFF);
const Color _kBar = Color(0xFF1E1E1E);

class MediaPreviewScreen extends StatefulWidget {
  final GalleryItem item;
  final String? title;
  final ValueListenable<Set<String>> selectedIds;
  final VoidCallback onToggleSelection;
  final VoidCallback onSend;
  final File? editedFile;
  final void Function(File edited)? onEdited;
  final String initialCaption;
  final ValueChanged<String>? onCaptionChanged;

  const MediaPreviewScreen({
    super.key,
    required this.item,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onSend,
    this.title,
    this.editedFile,
    this.onEdited,
    this.initialCaption = '',
    this.onCaptionChanged,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _caption = TextEditingController(
    text: widget.initialCaption,
  );
  File? _workingFile;
  File? _rotationOriginal;
  int _appliedTurns = 0;
  int _queuedTurns = 0;
  bool _rotating = false;
  late final AnimationController _rotCtrl;
  Size? _boxSize;
  double _aspect = 1;
  double _rotFitScale = 1;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _caption.addListener(
      () => widget.onCaptionChanged?.call(_caption.text),
    );
    _resolveWorkingFile();
  }

  Future<void> _resolveWorkingFile() async {
    final initial = widget.editedFile ?? widget.item.localFile;
    if (initial != null) {
      _workingFile = initial;
      _rotationOriginal = initial;
      _updateAspect();
      return;
    }
    final file = await widget.item.originFile();
    if (!mounted) return;
    setState(() => _workingFile = file);
    _rotationOriginal = file;
    _updateAspect();
  }

  Future<void> _updateAspect() async {
    final file = _workingFile;
    if (file == null) return;
    final dims = await decodeImageFileDimensions(file);
    if (!mounted || dims == null || dims.$2 == 0) return;
    _aspect = dims.$1 / dims.$2;
  }

  @override
  void dispose() {
    _caption.dispose();
    _rotCtrl.dispose();
    super.dispose();
  }

  void _send() {
    Navigator.of(context).pop();
    widget.onSend();
  }

  // Each tap queues one more 90° step; taps are never dropped. Every step is
  // baked from the pristine original at the net angle, so repeated rotation
  // never stacks JPEG generations.
  Future<void> _rotate() async {
    if (_workingFile == null || _rotationOriginal == null) return;
    _queuedTurns++;
    if (_rotating) return;
    _rotating = true;
    while (_queuedTurns > 0 && mounted) {
      _queuedTurns--;
      await _rotateOneStep();
    }
    _rotating = false;
  }

  Future<void> _rotateOneStep() async {
    final original = _rotationOriginal;
    if (original == null) return;
    final box = _boxSize;
    _rotFitScale = box != null ? _rotatedFitScale(_aspect, box) : 1.0;
    final target = (_appliedTurns + 1) % 4;
    _rotCtrl.value = 0;
    final bakeFut = _rotateImageFile(original, target);
    await _rotCtrl.forward();
    final baked = await bakeFut;
    if (!mounted) return;
    if (baked != null) {
      try {
        await precacheImage(FileImage(baked), context);
      } catch (_) {}
      if (!mounted) return;
      _appliedTurns = target;
      _aspect = _aspect > 0 ? 1 / _aspect : 1;
      setState(() {
        _workingFile = baked;
        _rotCtrl.value = 0;
      });
      widget.onEdited?.call(baked);
    } else {
      setState(() => _rotCtrl.value = 0);
    }
  }

  double _rotatedFitScale(double a, Size box) {
    final bw = box.width;
    final bh = box.height;
    if (bw <= 0 || bh <= 0 || a <= 0) return 1;
    double dw;
    double dh;
    if (bw / bh > a) {
      dh = bh;
      dw = bh * a;
    } else {
      dw = bw;
      dh = bw / a;
    }
    final s = math.min(bw / dh, bh / dw);
    return s.isFinite && s > 0 ? s : 1;
  }

  Future<File?> _rotateImageFile(File src, int quarterTurnsCCW) async {
    final turns = ((quarterTurnsCCW % 4) + 4) % 4;
    if (turns == 0) return src;
    try {
      final bytes = await src.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width;
      final h = image.height;
      final swap = turns.isOdd;
      final outW = swap ? h : w;
      final outH = swap ? w : h;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.translate(outW / 2, outH / 2);
      canvas.rotate(-math.pi / 2 * turns);
      canvas.drawImage(image, Offset(-w / 2, -h / 2), Paint());
      final picture = recorder.endRecording();
      final rotated = await picture.toImage(outW, outH);
      picture.dispose();
      image.dispose();
      codec.dispose();
      final bd = await rotated.toByteData(format: ui.ImageByteFormat.rawRgba);
      rotated.dispose();
      if (bd == null) return null;
      final jpeg = await encodeRgbaToJpeg(bd.buffer.asUint8List(), outW, outH);
      if (jpeg == null) return null;
      final dir = await getTemporaryDirectory();
      final out = File(
        p.join(dir.path, 'komet_rot_${DateTime.now().microsecondsSinceEpoch}.jpg'),
      );
      await out.writeAsBytes(jpeg);
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openDraw() async {
    final file = _workingFile;
    if (file == null || _rotating) return;
    final dims = await decodeImageFileDimensions(file);
    if (!mounted) return;
    if (dims == null) {
      showCustomNotification(context, 'Не удалось открыть редактор');
      return;
    }
    final result = await Navigator.of(context).push<File>(
      PageRouteBuilder<File>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => PhotoDrawEditor(
          source: file,
          imageWidth: dims.$1,
          imageHeight: dims.$2,
        ),
      ),
    );
    if (result != null && mounted) {
      _rotationOriginal = result;
      _appliedTurns = 0;
      setState(() => _workingFile = result);
      _updateAspect();
      widget.onEdited?.call(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.title ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _SelectionToggle(
              selectedIds: widget.selectedIds,
              id: widget.item.id,
              onTap: widget.onToggleSelection,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _boxSize = constraints.biggest;
                  return Center(
                    child: AnimatedBuilder(
                      animation: _rotCtrl,
                      builder: (context, child) {
                        final t = _rotCtrl.value;
                        return Transform.rotate(
                          angle: -math.pi / 2 * t,
                          child: Transform.scale(
                            scale: 1 + (_rotFitScale - 1) * t,
                            child: child,
                          ),
                        );
                      },
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: _buildImage(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final file = _workingFile;
    if (file == null) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
      );
    }
    return Image.file(file, fit: BoxFit.contain, gaplessPlayback: true);
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCaptionField(),
            const SizedBox(height: 10),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionField() {
    return Container(
      decoration: BoxDecoration(
        color: _kBar,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _caption,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Добавить подпись...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<Set<String>>(
            valueListenable: widget.selectedIds,
            builder: (context, selected, _) {
              final count = selected.isEmpty ? 1 : selected.length;
              return _CountBadge(count: count);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: _kBar,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ToolIcon(icon: Symbols.crop_rotate, onTap: _rotate),
                _ToolIcon(icon: Symbols.brush, onTap: _openDraw),
                const _FileToggle(),
                _ToolIcon(icon: Symbols.tune, onTap: () {}),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _SendButton(onTap: _send),
      ],
    );
  }
}

class _SelectionToggle extends StatelessWidget {
  final ValueListenable<Set<String>> selectedIds;
  final String id;
  final VoidCallback onTap;

  const _SelectionToggle({
    required this.selectedIds,
    required this.id,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: selectedIds,
      builder: (context, selected, _) {
        final index = selected.toList().indexOf(id);
        final isSelected = index >= 0;
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? _kAccent : Colors.transparent,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: isSelected
                ? Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedCirclePainter(color: Colors.white),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: Text(
            '$count',
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
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;

  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    const dashes = 22;
    const sweep = (2 * math.pi) / dashes;
    const dashRatio = 0.55;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * dashRatio, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ToolIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _FileToggle extends StatefulWidget {
  const _FileToggle();

  @override
  State<_FileToggle> createState() => _FileToggleState();
}

class _FileToggleState extends State<_FileToggle> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => setState(() => _active = !_active),
      icon: TweenAnimationBuilder<double>(
        tween: Tween(end: _active ? 1 : 0),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, t, _) {
          final color = Color.lerp(
            Colors.white54,
            Color.lerp(Colors.white, _kAccent, 0.4),
            t,
          );
          return Icon(Symbols.description, color: color, size: 24);
        },
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kAccent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Symbols.send, color: Colors.white, size: 24, fill: 1),
        ),
      ),
    );
  }
}

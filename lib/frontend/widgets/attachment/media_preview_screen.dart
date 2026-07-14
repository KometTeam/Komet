import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/frontend/widgets/attachment/photo_editor.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';

import '../../../core/config/app_colors.dart';
import '../small_spinner.dart';

const Color _kBar = Color(0xFF1E1E1E);

class MediaPreviewScreen extends StatefulWidget {
  final GalleryItem item;
  final String? title;
  final ValueListenable<Set<String>> selectedIds;
  final VoidCallback onToggleSelection;
  final VoidCallback onSend;
  final PhotoEditState? editState;
  final ValueChanged<PhotoEditState>? onEditChanged;
  final String initialCaption;
  final ValueChanged<String>? onCaptionChanged;
  final Set<String> tempFiles;

  const MediaPreviewScreen({
    super.key,
    required this.item,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onSend,
    required this.tempFiles,
    this.title,
    this.editState,
    this.onEditChanged,
    this.initialCaption = '',
    this.onCaptionChanged,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late final TextEditingController _caption = TextEditingController(
    text: widget.initialCaption,
  );
  File? _workingFile;
  File? _cropSource;
  CropState? _cropState;

  @override
  void initState() {
    super.initState();
    _caption.addListener(() => widget.onCaptionChanged?.call(_caption.text));
    _cropState = widget.editState?.cropState;
    _cropSource = widget.editState?.cropSource;
    _resolveWorkingFile();
  }

  Future<void> _resolveWorkingFile() async {
    final initial = widget.editState?.working ?? widget.item.localFile;
    if (initial != null) {
      _workingFile = initial;
      return;
    }
    final file = await widget.item.originFile();
    if (!mounted) return;
    setState(() => _workingFile = file);
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _send() {
    Navigator.of(context).pop();
    widget.onSend();
  }

  Future<T?> _pushEditor<T>(Widget editor) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => editor,
      ),
    );
  }

  void _reportEdit() {
    widget.onEditChanged?.call(
      PhotoEditState(
        working: _workingFile,
        cropSource: _cropSource,
        cropState: _cropState,
      ),
    );
  }

  void _disposeTemp(File? file, Set<String> keep) {
    if (file == null || keep.contains(file.path)) return;
    if (!widget.tempFiles.remove(file.path)) return;
    file.delete().then((_) {}, onError: (_) {});
  }

  Future<void> _openCrop() async {
    if (_workingFile == null) return;
    final source = _cropSource ??=
        widget.item.localFile ?? await widget.item.originFile();
    if (source == null || !mounted) return;
    final result = await _pushEditor<CropResult>(
      PhotoCropEditor(source: source, initialState: _cropState),
    );
    if (result != null && mounted) {
      final old = _workingFile;
      _cropState = result.state;
      widget.tempFiles.add(result.file.path);
      setState(() => _workingFile = result.file);
      _reportEdit();
      _disposeTemp(old, {result.file.path, _cropSource?.path ?? ''});
    }
  }

  Future<void> _openDraw() async {
    final file = _workingFile;
    if (file == null) return;
    final dims = await imageFileDimensions(file);
    if (!mounted) return;
    if (dims == null) {
      showCustomNotification(context, 'Не удалось открыть редактор');
      return;
    }
    final result = await _pushEditor<File>(
      PhotoDrawEditor(source: file, imageWidth: dims.$1, imageHeight: dims.$2),
    );
    if (result != null && mounted) {
      final oldWorking = _workingFile;
      final oldCropSource = _cropSource;
      _cropSource = result;
      _cropState = null;
      widget.tempFiles.add(result.path);
      setState(() => _workingFile = result);
      _reportEdit();
      _disposeTemp(oldWorking, {result.path});
      _disposeTemp(oldCropSource, {result.path, oldWorking?.path ?? ''});
    }
  }

  Future<void> _openAdjust() async {
    final file = _workingFile;
    if (file == null) return;
    final result = await _pushEditor<File>(PhotoAdjustEditor(source: file));
    if (result != null && mounted) {
      final oldWorking = _workingFile;
      final oldCropSource = _cropSource;
      _cropSource = result;
      _cropState = null;
      widget.tempFiles.add(result.path);
      setState(() => _workingFile = result);
      _reportEdit();
      _disposeTemp(oldWorking, {result.path});
      _disposeTemp(oldCropSource, {result.path, oldWorking?.path ?? ''});
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
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: _buildImage(),
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
      return const SmallSpinner(size: 36, color: Colors.white24);
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
                _ToolIcon(icon: Symbols.crop_rotate, onTap: _openCrop),
                _ToolIcon(icon: Symbols.brush, onTap: _openDraw),
                const _FileToggle(),
                _ToolIcon(icon: Symbols.tune, onTap: _openAdjust),
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
              color: isSelected ? kEditorAccent : Colors.transparent,
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
            Color.lerp(Colors.white, kEditorAccent, 0.4),
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
      color: kEditorAccent,
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

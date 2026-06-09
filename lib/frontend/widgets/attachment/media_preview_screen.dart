import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/media/gallery_source.dart';

const Color _kAccent = Color(0xFF2F8FFF);
const Color _kBar = Color(0xFF1E1E1E);

class MediaPreviewScreen extends StatefulWidget {
  final GalleryItem item;
  final String? title;
  final ValueListenable<Set<String>> selectedIds;
  final VoidCallback onToggleSelection;
  final VoidCallback onSend;

  const MediaPreviewScreen({
    super.key,
    required this.item,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onSend,
    this.title,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final TextEditingController _caption = TextEditingController();
  Future<File?>? _fileFuture;

  @override
  void initState() {
    super.initState();
    if (widget.item.localFile == null) {
      _fileFuture = widget.item.originFile();
    }
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
    final local = widget.item.localFile;
    if (local != null) {
      return Image.file(local, fit: BoxFit.contain);
    }
    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          );
        }
        return Image.file(file, fit: BoxFit.contain);
      },
    );
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
                _ToolIcon(icon: Symbols.crop_rotate, onTap: () {}),
                _ToolIcon(icon: Symbols.brush, onTap: () {}),
                _QualityBadge(onTap: () {}),
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
        final isSelected = selected.contains(id);
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
                ? const Icon(
                    Symbols.check,
                    color: Colors.white,
                    size: 18,
                    weight: 700,
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

class _QualityBadge extends StatelessWidget {
  final VoidCallback onTap;

  const _QualityBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'SD',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
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

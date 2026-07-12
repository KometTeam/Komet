import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/utils/haptics.dart';
import 'lottie_image.dart';

class _PeekData {
  final String? url;
  final String? lottieUrl;
  final List<String> tags;

  const _PeekData(this.url, this.lottieUrl, this.tags);
}

class StickerPeekScope extends StatefulWidget {
  final Widget child;

  const StickerPeekScope({super.key, required this.child});

  static StickerPeekScopeState? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_StickerPeekInherited>()
        ?.state;
  }

  @override
  State<StickerPeekScope> createState() => StickerPeekScopeState();
}

class StickerPeekScopeState extends State<StickerPeekScope>
    with SingleTickerProviderStateMixin {
  final Set<StickerPeekableState> _cells = {};
  final ValueNotifier<_PeekData?> _current = ValueNotifier(null);
  late final AnimationController _anim;
  OverlayEntry? _entry;
  Object? _currentId;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _entry?.remove();
    _entry = null;
    _anim.dispose();
    _current.dispose();
    super.dispose();
  }

  void register(StickerPeekableState cell) => _cells.add(cell);
  void unregister(StickerPeekableState cell) => _cells.remove(cell);

  StickerPeekableState? _hitTest(Offset globalPos) {
    for (final cell in _cells) {
      final rect = cell.globalRect;
      if (rect != null && rect.contains(globalPos)) return cell;
    }
    return null;
  }

  void _start(Offset globalPos) {
    final cell = _hitTest(globalPos);
    if (cell == null) return;
    _currentId = cell.widget.peekId;
    _current.value = _PeekData(
      cell.widget.url,
      cell.widget.lottieUrl,
      cell.widget.tags,
    );
    _showEntry();
    _anim.forward(from: 0);
    Haptics.medium();
  }

  void _update(Offset globalPos) {
    if (_entry == null) return;
    final cell = _hitTest(globalPos);
    if (cell == null || cell.widget.peekId == _currentId) return;
    _currentId = cell.widget.peekId;
    _current.value = _PeekData(
      cell.widget.url,
      cell.widget.lottieUrl,
      cell.widget.tags,
    );
    Haptics.selection();
  }

  void _end() {
    if (_entry == null) return;
    _anim.reverse().whenComplete(_removeEntry);
  }

  void _showEntry() {
    if (_entry != null) return;
    final entry = OverlayEntry(
      builder: (_) => _PeekOverlay(anim: _anim, data: _current),
    );
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _removeEntry() {
    if (_disposed) return;
    _entry?.remove();
    _entry = null;
    _currentId = null;
    _current.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return _StickerPeekInherited(
      state: this,
      child: GestureDetector(
        onLongPressStart: (d) => _start(d.globalPosition),
        onLongPressMoveUpdate: (d) => _update(d.globalPosition),
        onLongPressEnd: (_) => _end(),
        onLongPressCancel: _end,
        child: widget.child,
      ),
    );
  }
}

class _StickerPeekInherited extends InheritedWidget {
  final StickerPeekScopeState state;

  const _StickerPeekInherited({required this.state, required super.child});

  @override
  bool updateShouldNotify(_StickerPeekInherited oldWidget) =>
      state != oldWidget.state;
}

class StickerPeekable extends StatefulWidget {
  final Object peekId;
  final String? url;
  final String? lottieUrl;
  final List<String> tags;
  final Widget child;

  const StickerPeekable({
    super.key,
    required this.peekId,
    this.url,
    this.lottieUrl,
    this.tags = const [],
    required this.child,
  });

  @override
  State<StickerPeekable> createState() => StickerPeekableState();
}

class StickerPeekableState extends State<StickerPeekable> {
  StickerPeekScopeState? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = StickerPeekScope.of(context);
    if (scope != _scope) {
      _scope?.unregister(this);
      _scope = scope;
      _scope?.register(this);
    }
  }

  @override
  void dispose() {
    _scope?.unregister(this);
    super.dispose();
  }

  Rect? get globalRect {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PeekOverlay extends StatelessWidget {
  final Animation<double> anim;
  final ValueListenable<_PeekData?> data;

  const _PeekOverlay({required this.anim, required this.data});

  @override
  Widget build(BuildContext context) {
    final previewSize = MediaQuery.sizeOf(context).shortestSide * 0.66;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) {
          final t = Curves.easeOut.transform(anim.value.clamp(0.0, 1.0));
          return Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20 * t, sigmaY: 20 * t),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.3 * t),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * t,
                    child: ValueListenableBuilder<_PeekData?>(
                      valueListenable: data,
                      builder: (context, d, _) {
                        if (d == null) return const SizedBox.shrink();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (d.tags.isNotEmpty) ...[
                              _PeekTags(tags: d.tags),
                              const SizedBox(height: 18),
                            ],
                            SizedBox(
                              width: previewSize,
                              height: previewSize,
                              child: LottieImage(
                                url: d.url,
                                lottieUrl: d.lottieUrl,
                                size: previewSize,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PeekTags extends StatelessWidget {
  final List<String> tags;

  const _PeekTags({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tag in tags)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(tag, style: const TextStyle(fontSize: 28)),
          ),
      ],
    );
  }
}

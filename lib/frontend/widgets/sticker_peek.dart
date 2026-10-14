import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/utils/haptics.dart';
import 'close_on_back.dart';
import 'lottie_image.dart';
import '../../core/config/app_frost.dart';

class StickerPeekAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const StickerPeekAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _PeekData {
  final String? url;
  final String? lottieUrl;
  final List<String> tags;
  final List<StickerPeekAction> actions;

  const _PeekData(this.url, this.lottieUrl, this.tags, this.actions);
}

class StickerPeekScope extends StatefulWidget {
  final Widget child;
  final List<StickerPeekAction> Function(Object peekId)? actionsFor;

  const StickerPeekScope({super.key, required this.child, this.actionsFor});

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
  final ValueNotifier<bool> _menuOpen = ValueNotifier(false);
  late final AnimationController _anim;
  OverlayEntry? _entry;
  Object? _currentId;
  CloseOnBack? _backEntry;
  ModalRoute<Object?>? _backRoute;
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
    _releaseBack();
    _entry?.remove();
    _entry = null;
    _anim.dispose();
    _current.dispose();
    _menuOpen.dispose();
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

  _PeekData _dataFor(StickerPeekableState cell) => _PeekData(
    cell.widget.url,
    cell.widget.lottieUrl,
    cell.widget.tags,
    widget.actionsFor?.call(cell.widget.peekId) ?? const [],
  );

  void _start(Offset globalPos) {
    final cell = _hitTest(globalPos);
    if (cell == null) return;
    _currentId = cell.widget.peekId;
    _current.value = _dataFor(cell);
    _menuOpen.value = false;
    _showEntry();
    _anim.forward(from: 0);
    Haptics.medium();
  }

  void _update(Offset globalPos) {
    if (_entry == null || _menuOpen.value) return;
    final cell = _hitTest(globalPos);
    if (cell == null || cell.widget.peekId == _currentId) return;
    _currentId = cell.widget.peekId;
    _current.value = _dataFor(cell);
    Haptics.selection();
  }

  void _end() {
    if (_entry == null) return;
    if (_current.value?.actions.isNotEmpty ?? false) {
      _openMenu();
    } else {
      _close();
    }
  }

  void _openMenu() {
    _menuOpen.value = true;
    final route = ModalRoute.of(context);
    if (route == null || _backEntry != null) return;
    final backEntry = CloseOnBack(_close);
    route.registerPopEntry(backEntry);
    _backEntry = backEntry;
    _backRoute = route;
  }

  void _releaseBack() {
    final backEntry = _backEntry;
    if (backEntry == null) return;
    _backRoute?.unregisterPopEntry(backEntry);
    backEntry.canPopNotifier.dispose();
    _backEntry = null;
    _backRoute = null;
  }

  void _close() {
    if (_entry == null) return;
    _menuOpen.value = false;
    _anim.reverse().whenComplete(_removeEntry);
  }

  void _runAction(StickerPeekAction action) {
    Haptics.tap();
    _close();
    action.onTap();
  }

  void _showEntry() {
    if (_entry != null) return;
    final entry = OverlayEntry(
      builder: (_) => _PeekOverlay(
        anim: _anim,
        data: _current,
        menuOpen: _menuOpen,
        onDismiss: _close,
        onAction: _runAction,
      ),
    );
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _removeEntry() {
    if (_disposed) return;
    _releaseBack();
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
  static const double _tagsSlot = 60;
  static const double _menuGap = 16;
  static const double _screenMargin = 32;
  static const double _minPreviewSize = 96;

  final Animation<double> anim;
  final ValueListenable<_PeekData?> data;
  final ValueListenable<bool> menuOpen;
  final VoidCallback onDismiss;
  final ValueChanged<StickerPeekAction> onAction;

  const _PeekOverlay({
    required this.anim,
    required this.data,
    required this.menuOpen,
    required this.onDismiss,
    required this.onAction,
  });

  double _previewSize(BuildContext context, int actionCount) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final menuSlot = actionCount == 0
        ? 0
        : _menuGap + _PeekMenu.heightFor(actionCount);
    final room =
        size.height - padding.vertical - _screenMargin - _tagsSlot - menuSlot;
    return math.max(_minPreviewSize, math.min(size.shortestSide * 0.66, room));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: menuOpen,
      builder: (context, open, child) => IgnorePointer(
        ignoring: !open,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) {
          final t = Curves.easeOut.transform(anim.value.clamp(0.0, 1.0));
          return Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: AppFrost.overlaySigma * t,
                    sigmaY: AppFrost.overlaySigma * t,
                  ),
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
                        final previewSize = _previewSize(
                          context,
                          d.actions.length,
                        );
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
                            if (d.actions.isNotEmpty) ...[
                              const SizedBox(height: _menuGap),
                              ValueListenableBuilder<bool>(
                                valueListenable: menuOpen,
                                builder: (context, open, _) => AnimatedOpacity(
                                  opacity: open ? 1 : 0,
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOutCubic,
                                  child: _PeekMenu(
                                    actions: d.actions,
                                    onAction: onAction,
                                  ),
                                ),
                              ),
                            ],
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

class _PeekMenu extends StatelessWidget {
  static const double _itemHeight = 42;
  static const double _verticalPadding = 6;
  static const double _width = 240;

  static double heightFor(int count) =>
      count * _itemHeight + 2 * _verticalPadding;

  final List<StickerPeekAction> actions;
  final ValueChanged<StickerPeekAction> onAction;

  const _PeekMenu({required this.actions, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions)
                SizedBox(
                  height: _itemHeight,
                  child: InkWell(
                    onTap: () => onAction(action),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Icon(action.icon, color: cs.onSurface, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              action.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeekTags extends StatefulWidget {
  final List<String> tags;

  const _PeekTags({required this.tags});

  @override
  State<_PeekTags> createState() => _PeekTagsState();
}

class _PeekTagsState extends State<_PeekTags>
    with SingleTickerProviderStateMixin {
  static const int _sweeps = 3;

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _sweep.repeat(count: _sweeps);
  }

  @override
  void didUpdateWidget(_PeekTags oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.tags, widget.tags)) {
      _sweep.repeat(count: _sweeps);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHigh;
    final glint = Color.lerp(base, cs.primary, 0.35)!;
    final maxWidth = MediaQuery.sizeOf(context).width - 32;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _sweep,
          builder: (context, child) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [base, base, glint, base, base],
                stops: const [0, 0.3, 0.5, 0.7, 1],
                transform: _SlidingGradient(_sweep.value),
              ),
            ),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: [
                for (final tag in widget.tags)
                  Text(tag, style: const TextStyle(fontSize: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlidingGradient extends GradientTransform {
  final double progress;

  const _SlidingGradient(this.progress);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
}

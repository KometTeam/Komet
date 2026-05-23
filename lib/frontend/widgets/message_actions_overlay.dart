import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/haptics.dart';
import 'custom_notification.dart';

class MessageActionsController extends ChangeNotifier {
  Offset? pointer;
  Offset? initialPointer;
  bool committed = false;
  bool movedSignificantly = false;
  bool _attached = false;

  void attach(Offset initial) {
    if (_attached) return;
    _attached = true;
    initialPointer = initial;
    pointer = initial;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
  }

  void updatePointer(Offset p) {
    if (committed) return;
    pointer = p;
    if (initialPointer != null &&
        !movedSignificantly &&
        (p - initialPointer!).distance > 18) {
      movedSignificantly = true;
    }
    notifyListeners();
  }

  void _onPointerEvent(PointerEvent event) {
    if (committed) return;
    if (event is PointerMoveEvent) {
      updatePointer(event.position);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      commit();
    }
  }

  void commit() {
    if (committed) return;
    committed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_attached) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
      _attached = false;
    }
    super.dispose();
  }
}

void showMessageActions({
  required BuildContext context,
  required ui.Image snapshot,
  required Rect originRect,
  required Offset tapPoint,
  required bool isMe,
  required String? messageText,
  required MessageActionsController controller,
  required VoidCallback onDispose,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _MessageActionsLayer(
      snapshot: snapshot,
      originRect: originRect,
      tapPoint: tapPoint,
      isMe: isMe,
      messageText: messageText,
      controller: controller,
      onDismiss: () {
        if (entry.mounted) entry.remove();
        onDispose();
      },
    ),
  );
  overlay.insert(entry);
}

class _MessageActionsLayer extends StatefulWidget {
  final ui.Image snapshot;
  final Rect originRect;
  final Offset tapPoint;
  final bool isMe;
  final String? messageText;
  final MessageActionsController controller;
  final VoidCallback onDismiss;

  const _MessageActionsLayer({
    required this.snapshot,
    required this.originRect,
    required this.tapPoint,
    required this.isMe,
    required this.messageText,
    required this.controller,
    required this.onDismiss,
  });

  @override
  State<_MessageActionsLayer> createState() => _MessageActionsLayerState();
}

class _MessageActionsLayerState extends State<_MessageActionsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _animation;
  bool _closing = false;
  static const double _radius = 92.0;
  static const double _arcSpan = math.pi * 0.62;
  static const double _btnSize = 52.0;
  static const double _hitRadius = 40.0;
  static const double _hMargin = 8.0;

  late List<_Action> _actions;
  bool _showBelow = true;
  Offset _anchor = Offset.zero;
  List<Offset> _buttonCenters = const [];
  bool _initialized = false;

  int _hoveredIndex = -1;
  bool _committedFired = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _animController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _actions = _buildActions();
    final screenSize = MediaQuery.sizeOf(context);
    _showBelow = widget.tapPoint.dy < screenSize.height * 0.55;
    _anchor = _showBelow
        ? Offset(widget.tapPoint.dx, widget.originRect.bottom + 16)
        : Offset(widget.tapPoint.dx, widget.originRect.top - 16);
    _buttonCenters = _computeButtonCenters(screenSize);
    widget.controller.addListener(_onControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onControllerUpdate();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    widget.controller.removeListener(_onControllerUpdate);
    widget.snapshot.dispose();
    super.dispose();
  }

  List<_Action> _buildActions() {
    final hasText = widget.messageText != null && widget.messageText!.isNotEmpty;
    return <_Action>[
      if (hasText) _Action(Symbols.content_copy, 'Копировать', _copy),
      _Action(Symbols.reply, 'Ответить', () => _stub('Ответ')),
      _Action(Symbols.forward, 'Переслать', () => _stub('Пересылка')),
      _Action(Symbols.delete, 'Удалить', () => _stub('Удаление')),
    ];
  }

  List<Offset> _computeButtonCenters(Size screenSize) {
    final n = _actions.length;
    if (n == 0) return const [];
    final base = _showBelow ? math.pi * 0.5 : -math.pi * 0.5;
    final start = base - _arcSpan / 2;
    final step = n == 1 ? 0.0 : _arcSpan / (n - 1);
    final minX = _hMargin + _btnSize / 2;
    final maxX = screenSize.width - _hMargin - _btnSize / 2;
    return [
      for (int i = 0; i < n; i++)
        () {
          final angle = start + step * i;
          var p = _anchor + Offset(math.cos(angle), math.sin(angle)) * _radius;
          if (p.dx < minX) p = Offset(minX, p.dy);
          if (p.dx > maxX) p = Offset(maxX, p.dy);
          return p;
        }(),
    ];
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final p = widget.controller.pointer;
    if (p != null) {
      final newHovered = _findButtonAt(p);
      if (newHovered != _hoveredIndex) {
        if (newHovered != -1) Haptics.selection();
        setState(() => _hoveredIndex = newHovered);
      }
    }

    if (widget.controller.committed && !_committedFired) {
      _committedFired = true;
      _onCommit();
    }
  }

  int _findButtonAt(Offset p) {
    for (int i = 0; i < _buttonCenters.length; i++) {
      if ((_buttonCenters[i] - p).distance <= _hitRadius) {
        return i;
      }
    }
    return -1;
  }

  void _onCommit() {
    if (_hoveredIndex != -1 && widget.controller.movedSignificantly) {
      Haptics.medium();
      _actions[_hoveredIndex].onTap();
    } else if (widget.controller.movedSignificantly) {
      _close();
    }
  }

  Future<void> _close() async {
    if (!mounted || _closing) return;
    _closing = true;
    try {
      await _animController.reverse();
    } catch (_) {}
    if (!mounted) return;
    widget.onDismiss();
  }

  Future<void> _copy() async {
    final text = widget.messageText;
    if (text != null && text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      showCustomNotification(context, 'Скопировано');
    }
    await _close();
  }

  Future<void> _stub(String name) async {
    if (!mounted) return;
    showCustomNotification(context, '$name — пока в разработке');
    await _close();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (ctx, _) {
        final t = _animation.value.clamp(0.0, 1.0);
        final blurSigma = 14.0 * t;
        final bubbleScale = 1.0 + 0.05 * t;

        return GestureDetector(
          onTap: _close,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.22 * t),
                  ),
                ),
              ),
              Positioned(
                left: widget.originRect.left,
                top: widget.originRect.top,
                width: widget.originRect.width,
                height: widget.originRect.height,
                child: Transform.scale(
                  scale: bubbleScale,
                  child: RawImage(
                    image: widget.snapshot,
                    width: widget.originRect.width,
                    height: widget.originRect.height,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              ..._buildButtons(t),
              _buildLabelBanner(size, t),
              _buildDebugOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebugOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _DebugPainter(
            pointerPosition: widget.controller.pointer,
            initialPointer: widget.controller.initialPointer,
            buttonCenters: _buttonCenters,
            hoveredIndex: _hoveredIndex,
            committed: widget.controller.committed,
            moved: widget.controller.movedSignificantly,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildButtons(double t) {
    final n = _actions.length;
    return [
      for (int i = 0; i < n; i++)
        Builder(
          builder: (_) {
            final delay = (i / n) * 0.25;
            final localT = ((t - delay) / (1.0 - delay)).clamp(0.0, 1.0);
            final eased = Curves.easeOutBack.transform(localT);
            final isHovered = _hoveredIndex == i;
            final hoverScale = isHovered ? 1.18 : 1.0;
            final entryScale = 0.4 + 0.6 * eased;
            final centerAtFull = _buttonCenters[i];
            final centerAtT = _anchor +
                (centerAtFull - _anchor) * eased;

            return Positioned(
              left: centerAtT.dx - _btnSize / 2,
              top: centerAtT.dy - _btnSize / 2,
              width: _btnSize,
              height: _btnSize,
              child: Opacity(
                opacity: localT,
                child: Transform.scale(
                  scale: entryScale,
                  child: AnimatedScale(
                    scale: hoverScale,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    child: _ActionButton(
                      action: _actions[i],
                      highlighted: isHovered,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ];
  }

  Widget _buildLabelBanner(Size size, double t) {
    final label =
        _hoveredIndex == -1 ? null : _actions[_hoveredIndex].label;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset + 36,
      child: IgnorePointer(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: label == null
                ? const SizedBox(key: ValueKey('empty'), height: 0)
                : Container(
                    key: ValueKey('label_$label'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72 * t),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DebugPainter extends CustomPainter {
  final Offset? pointerPosition;
  final Offset? initialPointer;
  final List<Offset> buttonCenters;
  final int hoveredIndex;
  final bool committed;
  final bool moved;

  _DebugPainter({
    required this.pointerPosition,
    required this.initialPointer,
    required this.buttonCenters,
    required this.hoveredIndex,
    required this.committed,
    required this.moved,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerPaint = Paint()..color = const Color(0xFFFFFFFF);
    final centerBorder = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < buttonCenters.length; i++) {
      canvas.drawCircle(buttonCenters[i], 5, centerPaint);
      canvas.drawCircle(buttonCenters[i], 5, centerBorder);
    }

    final initial = initialPointer;
    if (initial != null) {
      final paint = Paint()..color = const Color(0xFFFFEB3B);
      canvas.drawCircle(initial, 8, paint);
    }

    final p = pointerPosition;
    if (p != null) {
      final paint = Paint()..color = const Color(0xFFFF1744);
      canvas.drawCircle(p, 14, paint);
      final border = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(p, 14, border);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text:
            'h=$hoveredIndex c=$committed mov=$moved\n'
            'p=${pointerPosition?.dx.toStringAsFixed(0)},${pointerPosition?.dy.toStringAsFixed(0)}',
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          backgroundColor: Color(0xCC000000),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(12, 60));
  }

  @override
  bool shouldRepaint(covariant _DebugPainter old) {
    return old.pointerPosition != pointerPosition ||
        old.hoveredIndex != hoveredIndex ||
        old.committed != committed ||
        old.moved != moved;
  }
}

class _Action {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action(this.icon, this.label, this.onTap);
}

class _ActionButton extends StatelessWidget {
  final _Action action;
  final bool highlighted;
  const _ActionButton({
    required this.action,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = highlighted ? cs.primary : cs.surfaceContainerHighest;
    final iconColor = highlighted ? cs.onPrimary : cs.onSurface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: highlighted ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Haptics.tap();
            action.onTap();
          },
          child: Center(
            child: Icon(action.icon, color: iconColor, size: 24),
          ),
        ),
      ),
    );
  }
}

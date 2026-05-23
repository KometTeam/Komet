import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/haptics.dart';
import 'custom_notification.dart';

class MessageActionsRoute extends PageRouteBuilder<void> {
  MessageActionsRoute({
    required ui.Image snapshot,
    required Rect originRect,
    required Offset tapPoint,
    required bool isMe,
    required String? messageText,
  }) : super(
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (ctx, anim, secondaryAnim) {
            return _MessageActionsLayer(
              snapshot: snapshot,
              originRect: originRect,
              tapPoint: tapPoint,
              isMe: isMe,
              messageText: messageText,
              animation: CurvedAnimation(
                parent: anim,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            );
          },
          transitionsBuilder: (_, __, ___, child) => child,
        );
}

class _MessageActionsLayer extends StatefulWidget {
  final ui.Image snapshot;
  final Rect originRect;
  final Offset tapPoint;
  final bool isMe;
  final String? messageText;
  final Animation<double> animation;

  const _MessageActionsLayer({
    required this.snapshot,
    required this.originRect,
    required this.tapPoint,
    required this.isMe,
    required this.messageText,
    required this.animation,
  });

  @override
  State<_MessageActionsLayer> createState() => _MessageActionsLayerState();
}

class _MessageActionsLayerState extends State<_MessageActionsLayer> {
  @override
  void dispose() {
    widget.snapshot.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (!mounted) return;
    Navigator.of(context).maybePop();
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

  List<_Action> _buildActions() {
    final hasText = widget.messageText != null && widget.messageText!.isNotEmpty;
    return <_Action>[
      if (hasText) _Action(Symbols.content_copy, 'Копировать', _copy),
      _Action(Symbols.reply, 'Ответить', () => _stub('Ответ')),
      _Action(Symbols.forward, 'Переслать', () => _stub('Пересылка')),
      _Action(Symbols.delete, 'Удалить', () => _stub('Удаление')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions();
    final size = MediaQuery.sizeOf(context);
    final showBelow = widget.tapPoint.dy < size.height * 0.55;
    final anchor = showBelow
        ? Offset(widget.tapPoint.dx, widget.originRect.bottom + 16)
        : Offset(widget.tapPoint.dx, widget.originRect.top - 16);

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (ctx, _) {
        final t = widget.animation.value.clamp(0.0, 1.0);
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
              ..._buildRadialMenu(actions, anchor, showBelow, t, size),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildRadialMenu(
    List<_Action> actions,
    Offset anchor,
    bool below,
    double t,
    Size screenSize,
  ) {
    final n = actions.length;
    if (n == 0) return const [];
    const radius = 92.0;
    const arcSpan = math.pi * 0.62;
    final baseAngle = below ? math.pi * 0.5 : -math.pi * 0.5;
    final startAngle = baseAngle - arcSpan / 2;
    final step = n == 1 ? 0.0 : arcSpan / (n - 1);
    const btnSize = 52.0;
    const margin = 8.0;

    return [
      for (int i = 0; i < n; i++)
        Builder(
          builder: (_) {
            final delay = (i / n) * 0.25;
            final localT =
                ((t - delay) / (1.0 - delay)).clamp(0.0, 1.0);
            final eased = Curves.easeOutBack.transform(localT);
            final angle = startAngle + step * i;
            final rOffset =
                Offset(math.cos(angle), math.sin(angle)) * radius * eased;
            var pos = anchor + rOffset;
            final minX = margin + btnSize / 2;
            final maxX = screenSize.width - margin - btnSize / 2;
            if (pos.dx < minX) pos = Offset(minX, pos.dy);
            if (pos.dx > maxX) pos = Offset(maxX, pos.dy);
            return Positioned(
              left: pos.dx - btnSize / 2,
              top: pos.dy - btnSize / 2,
              width: btnSize,
              height: btnSize,
              child: Opacity(
                opacity: localT,
                child: Transform.scale(
                  scale: 0.4 + 0.6 * eased,
                  child: _ActionButton(action: actions[i]),
                ),
              ),
            );
          },
        ),
    ];
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
  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          Haptics.tap();
          action.onTap();
        },
        child: Tooltip(
          message: action.label,
          child: Center(
            child: Icon(action.icon, color: cs.onSurface, size: 24),
          ),
        ),
      ),
    );
  }
}

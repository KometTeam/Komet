import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

const Duration _defaultUndoWindow = Duration(seconds: 5);
const Duration _appearDuration = Duration(milliseconds: 220);

PendingUndo showUndoNotification(
  BuildContext context,
  String message, {
  required FutureOr<void> Function() onCommit,
  required VoidCallback onUndo,
  Duration duration = _defaultUndoWindow,
}) {
  return PendingUndo._show(
    Overlay.of(context, rootOverlay: true),
    message: message,
    undoLabel: AppLocalizations.of(context)!.undoAction,
    duration: duration,
    onCommit: onCommit,
    onUndo: onUndo,
  );
}

class PendingUndo {
  PendingUndo._({
    required this.message,
    required this.undoLabel,
    required this.duration,
    required this.onCommit,
    required this.onUndo,
  }) {
    _lifecycle = AppLifecycleListener(onPause: commit, onDetach: commit);
  }

  static PendingUndo? _current;

  final String message;
  final String undoLabel;
  final Duration duration;
  final FutureOr<void> Function() onCommit;
  final VoidCallback onUndo;
  final GlobalKey<_UndoToastState> _toastKey = GlobalKey();
  late final OverlayEntry _entry = OverlayEntry(builder: _buildToast);
  late final AppLifecycleListener _lifecycle;
  bool _settled = false;

  static PendingUndo _show(
    OverlayState overlay, {
    required String message,
    required String undoLabel,
    required Duration duration,
    required FutureOr<void> Function() onCommit,
    required VoidCallback onUndo,
  }) {
    _current?.commit(animate: false);
    final pending = PendingUndo._(
      message: message,
      undoLabel: undoLabel,
      duration: duration,
      onCommit: onCommit,
      onUndo: onUndo,
    );
    _current = pending;
    overlay.insert(pending._entry);
    return pending;
  }

  Widget _buildToast(BuildContext context) => _UndoToast(
    key: _toastKey,
    message: message,
    undoLabel: undoLabel,
    duration: duration,
    onExpired: commit,
    onUndo: undo,
    onSwiped: () => commit(animate: false),
  );

  void commit({bool animate = true}) {
    if (!_settle()) return;
    unawaited(Future.sync(onCommit));
    unawaited(_dismiss(animate: animate));
  }

  void undo() {
    if (!_settle()) return;
    onUndo();
    unawaited(_dismiss(animate: true));
  }

  void discard() {
    if (!_settle()) return;
    unawaited(_dismiss(animate: true));
  }

  bool _settle() {
    if (_settled) return false;
    _settled = true;
    _lifecycle.dispose();
    if (identical(_current, this)) _current = null;
    return true;
  }

  Future<void> _dismiss({required bool animate}) async {
    final toast = _toastKey.currentState;
    if (animate && toast != null) await toast.hide();
    if (_entry.mounted) _entry.remove();
    _entry.dispose();
  }
}

class _UndoToast extends StatefulWidget {
  final String message;
  final String undoLabel;
  final Duration duration;
  final VoidCallback onExpired;
  final VoidCallback onUndo;
  final VoidCallback onSwiped;

  const _UndoToast({
    required this.message,
    required this.undoLabel,
    required this.duration,
    required this.onExpired,
    required this.onUndo,
    required this.onSwiped,
    super.key,
  });

  @override
  State<_UndoToast> createState() => _UndoToastState();
}

class _UndoToastState extends State<_UndoToast> with TickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: _appearDuration,
  )..forward();
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curvedAppear = CurvedAnimation(
    parent: _appear,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    _countdown
      ..addStatusListener(_onCountdownStatus)
      ..forward();
  }

  void _onCountdownStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onExpired();
  }

  Future<void> hide() async {
    _countdown.stop();
    if (!mounted) return;
    await _appear.reverse().orCancel.catchError((_) {});
  }

  @override
  void dispose() {
    _countdown.dispose();
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom + media.viewPadding.bottom + 72;
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottom,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FadeTransition(
            opacity: _curvedAppear,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(_curvedAppear),
              child: Dismissible(
                key: const ValueKey('undo-toast'),
                onDismissed: (_) => widget.onSwiped(),
                child: Material(
                  color: cs.surfaceContainerHighest,
                  elevation: 3,
                  shadowColor: Colors.black54,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                    child: Row(
                      children: [
                        _CountdownRing(
                          progress: _countdown,
                          duration: widget.duration,
                          color: cs.onSurface,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: widget.onUndo,
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                          child: Text(
                            widget.undoLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final Animation<double> progress;
  final Duration duration;
  final Color color;

  const _CountdownRing({
    required this.progress,
    required this.duration,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final remaining = 1 - progress.value;
          final seconds = (remaining * duration.inMilliseconds / 1000).ceil();
          return CustomPaint(
            painter: _RingPainter(remaining: remaining, color: color),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Text(
                  '${math.max(seconds, 1)}',
                  key: ValueKey(math.max(seconds, 1)),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double remaining;
  final Color color;

  const _RingPainter({required this.remaining, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.2;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, -2 * math.pi * remaining, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.remaining != remaining || old.color != color;
}

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_fonts.dart';
import '../../../core/security/archive_lock.dart';
import '../../../l10n/app_localizations.dart';
import 'lock_glyph.dart';
import 'passcode_prompt.dart';

void pushPastArchiveLock(
  BuildContext anchor, {
  required Offset? tapPosition,
  required Route<void> Function() destination,
}) {
  final navigator = Navigator.of(anchor);
  final lock = ArchiveLock.instance..expireIfDue();
  if (!lock.locked.value) {
    unawaited(navigator.push(destination()));
    return;
  }
  final scrim = Theme.of(
    anchor,
  ).colorScheme.surface.withValues(alpha: _GateBackdrop.scrimAlpha);
  unawaited(
    navigator.push(
      _ArchiveGateRoute(
        origin: _originIn(navigator, anchor, tapPosition),
        backdrop: _GateBackdrop.capture(navigator, scrim),
        destination: destination,
      ),
    ),
  );
}

Offset _originIn(NavigatorState navigator, BuildContext anchor, Offset? tap) {
  final space = navigator.context.findRenderObject();
  if (space is! RenderBox || !space.hasSize) return Offset.zero;
  final box = anchor.findRenderObject();
  final global =
      tap ??
      (box is RenderBox && box.hasSize
          ? box.localToGlobal(box.size.center(Offset.zero))
          : null);
  if (global == null) return space.size.center(Offset.zero);
  return space.globalToLocal(global);
}

class _GateBackdrop {
  static const double scrimAlpha = 0.35;
  static const double _scale = 0.5;
  static const double _blurSigma = 8;

  final ui.Image _image;
  final ui.ImageShader _shader;
  final Paint paint;

  _GateBackdrop._(this._image, this._shader)
    : paint = Paint()..shader = _shader;

  static _GateBackdrop? capture(NavigatorState navigator, Color scrim) {
    final space = navigator.context.findRenderObject();
    final boundary = navigator.context
        .findAncestorRenderObjectOfType<RenderRepaintBoundary>();
    if (space is! RenderBox || boundary == null || !boundary.hasSize) {
      return null;
    }
    final ui.Image snapshot;
    try {
      snapshot = boundary.toImageSync(pixelRatio: _scale);
    } catch (_) {
      return null;
    }
    final blurred = _blur(snapshot, scrim);
    snapshot.dispose();
    final origin = space.globalToLocal(boundary.localToGlobal(Offset.zero));
    final sx = boundary.size.width / blurred.width;
    final sy = boundary.size.height / blurred.height;
    final shader = ui.ImageShader(
      blurred,
      TileMode.clamp,
      TileMode.clamp,
      Float64List.fromList([
        sx, 0, 0, 0, //
        0, sy, 0, 0, //
        0, 0, 1, 0, //
        origin.dx, origin.dy, 0, 1,
      ]),
      filterQuality: FilterQuality.low,
    );
    return _GateBackdrop._(blurred, shader);
  }

  static ui.Image _blur(ui.Image source, Color scrim) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const sigma = _blurSigma * _scale;
    canvas.drawImage(
      source,
      Offset.zero,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
    );
    canvas.drawPaint(Paint()..color = scrim);
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(source.width, source.height);
    } finally {
      picture.dispose();
    }
  }

  void dispose() {
    _shader.dispose();
    _image.dispose();
  }
}

class _ArchiveGateRoute extends PageRoute<void> {
  _ArchiveGateRoute({
    required this.origin,
    required this.destination,
    _GateBackdrop? backdrop,
  }) : _backdrop = backdrop;

  static const Duration revealDuration = Duration(milliseconds: 560);
  static const Duration panelDuration = Duration(milliseconds: 400);
  static final double revealShare =
      revealDuration.inMicroseconds /
      (revealDuration + panelDuration).inMicroseconds;

  final Offset origin;
  final Route<void> Function() destination;
  final _GateBackdrop? _backdrop;

  @override
  Duration get transitionDuration => revealDuration + panelDuration;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 480);

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => false;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _ArchiveGate(route: this);

  void enter() {
    final navigator = this.navigator;
    if (navigator == null || !isCurrent) return;
    unawaited(navigator.pushReplacement(destination()));
  }

  @override
  void dispose() {
    _backdrop?.dispose();
    super.dispose();
  }
}

class _ArchiveGate extends StatefulWidget {
  final _ArchiveGateRoute route;

  const _ArchiveGate({required this.route});

  @override
  State<_ArchiveGate> createState() => _ArchiveGateState();
}

class _ArchiveGateState extends State<_ArchiveGate>
    with SingleTickerProviderStateMixin {
  static const double _glyphSize = 72;
  static const double _panelInteractiveFrom = 0.3;

  final ArchiveLock _lock = ArchiveLock.instance;
  late final AnimationController _opening = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final CurvedAnimation _reveal = CurvedAnimation(
    parent: widget.route.animation!,
    curve: Interval(
      0,
      _ArchiveGateRoute.revealShare,
      curve: Curves.easeInOutCubic,
    ),
  );
  late final CurvedAnimation _panel = CurvedAnimation(
    parent: widget.route.animation!,
    curve: Interval(_ArchiveGateRoute.revealShare, 1, curve: Curves.easeOut),
  );
  Paint? _solidFill;

  @override
  void initState() {
    super.initState();
    _lock.retain();
  }

  @override
  void dispose() {
    _opening.dispose();
    _reveal.dispose();
    _panel.dispose();
    _lock.release();
    super.dispose();
  }

  Future<bool> _submit(String pin) async {
    final ok = await _lock.unlock(pin);
    if (ok) unawaited(_enter());
    return ok;
  }

  Future<void> _enter() async {
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      await _opening.forward();
    }
    if (mounted) widget.route.enter();
  }

  Paint _fill(ColorScheme cs) {
    final backdrop = widget.route._backdrop;
    if (backdrop != null) return backdrop.paint;
    final solid = _solidFill;
    if (solid != null && solid.color == cs.surface) return solid;
    return _solidFill = Paint()..color = cs.surface;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _RevealPainter(
                origin: widget.route.origin,
                progress: _reveal,
                fill: _fill(cs),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _panel,
            builder: (context, child) => IgnorePointer(
              ignoring: _panel.value < _panelInteractiveFrom,
              child: child,
            ),
            child: FadeTransition(
              opacity: _panel,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(_panel),
                child: SafeArea(child: _buildPanel(cs)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: IconButton(
              icon: Icon(Symbols.arrow_back, color: cs.onSurface),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        Expanded(
          child: PasscodePrompt(
            credential: _lock.credential,
            onSubmit: _submit,
            header: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _opening,
                  builder: (context, _) => LockGlyph(
                    closed: 1 - _opening.value,
                    size: _glyphSize,
                    color: cs.primary,
                    holeColor: cs.surface,
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    l10n.archiveLockPrompt,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: displayFontOf(context),
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RevealPainter extends CustomPainter {
  final Offset origin;
  final Animation<double> progress;
  final Paint fill;

  _RevealPainter({
    required this.origin,
    required this.progress,
    required this.fill,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0) return;
    if (t >= 1) {
      canvas.drawRect(Offset.zero & size, fill);
      return;
    }
    canvas.drawCircle(origin, _reach(size) * t, fill);
  }

  double _reach(Size size) {
    final dx = math.max(origin.dx, size.width - origin.dx);
    final dy = math.max(origin.dy, size.height - origin.dy);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.origin != origin || old.progress != progress || old.fill != fill;
}

class ArchiveSessionScope extends StatefulWidget {
  final Widget child;

  const ArchiveSessionScope({super.key, required this.child});

  @override
  State<ArchiveSessionScope> createState() => _ArchiveSessionScopeState();
}

class _ArchiveSessionScopeState extends State<ArchiveSessionScope> {
  final ArchiveLock _lock = ArchiveLock.instance;
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    _lock.retain();
    _lock.locked.addListener(_leaveIfLocked);
    WidgetsBinding.instance.addPostFrameCallback((_) => _leaveIfLocked());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _lock.locked.removeListener(_leaveIfLocked);
    _lock.release();
    super.dispose();
  }

  void _leaveIfLocked() {
    if (!mounted || !_lock.locked.value) return;
    final route = _route;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    navigator.popUntil((candidate) => candidate == route);
    if (route.isCurrent) navigator.pop();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ArchiveLockBadge extends StatelessWidget {
  final Color color;

  const ArchiveLockBadge({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final lock = ArchiveLock.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: lock.enabled,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return ValueListenableBuilder<bool>(
          valueListenable: lock.locked,
          builder: (context, locked, _) => Padding(
            padding: const EdgeInsetsDirectional.only(start: 6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Icon(
                locked ? Symbols.lock : Symbols.lock_open_right,
                key: ValueKey(locked),
                size: 16,
                weight: 500,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

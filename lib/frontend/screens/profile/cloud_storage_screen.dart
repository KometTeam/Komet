import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class CloudStorageScreen extends StatefulWidget {
  const CloudStorageScreen({super.key});

  @override
  State<CloudStorageScreen> createState() => _CloudStorageScreenState();
}

class _CloudStorageScreenState extends State<CloudStorageScreen>
    with SingleTickerProviderStateMixin {
  static const _translateFactor = 0.7;
  static const _horizontalPadding = 32.0;
  static const _hintSidePadding = 35.0;
  static const _cornerSidePadding = 16.0;
  static const _cornerBottomPadding = 24.0;
  static const _cornerSlideAmount = 28.0;

  late final _UploadModeController _mode;

  @override
  void initState() {
    super.initState();
    _mode = _UploadModeController(this);
  }

  @override
  void dispose() {
    _mode.dispose();
    super.dispose();
  }

  void _onBack() {
    if (_mode.isOpen) {
      _mode.close();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: _onBack,
        ),
        title: Text(
          'Облачное хранилище',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => _mode.handleDragUpdate(d, h),
            onVerticalDragEnd: _mode.handleDragEnd,
            child: AnimatedBuilder(
              animation: _mode.anim,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_mode.anim.value);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildHint(cs, t),
                    _buildUploadingCenterHint(cs, t),
                    _buildEmptyState(cs, t, h),
                    ..._buildCornerActions(cs, t),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHint(ColorScheme cs, double t) {
    return Positioned(
      top: 0,
      left: _hintSidePadding,
      right: _hintSidePadding,
      child: IgnorePointer(
        child: Opacity(
          opacity: t,
          child: _DragDownHint(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildUploadingCenterHint(ColorScheme cs, double t) {
    return Center(
      child: Opacity(
        opacity: t,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          child: Text(
            'Начните загрузку для прогресс-бара',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, double t, double availableHeight) {
    return Transform.translate(
      offset: Offset(0, -t * availableHeight * _translateFactor),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Облачных файлов пока нет...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Добавите?',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _mode.open,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Загрузить',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCornerActions(ColorScheme cs, double t) {
    final slide = (1 - t) * _cornerSlideAmount;
    return [
      Positioned(
        bottom: _cornerBottomPadding,
        left: _cornerSidePadding - slide,
        child: Opacity(
          opacity: t,
          child: _CornerAction(
            icon: Symbols.upload_file,
            label: 'С файла',
            onTap: () {},
          ),
        ),
      ),
      Positioned(
        bottom: _cornerBottomPadding,
        right: _cornerSidePadding - slide,
        child: Opacity(
          opacity: t,
          child: _CornerAction(
            icon: Symbols.tag,
            label: 'По ID',
            onTap: () {},
          ),
        ),
      ),
    ];
  }
}

class _UploadModeController {
  static const _openDuration = Duration(milliseconds: 480);
  static const _closeDuration = Duration(milliseconds: 320);
  static const _dragRangeFactor = 0.55;
  static const _flingVelocityThreshold = 280.0;
  static const _snapMidpoint = 0.5;

  final AnimationController anim;

  _UploadModeController(TickerProvider vsync)
      : anim = AnimationController(
          vsync: vsync,
          duration: _openDuration,
          reverseDuration: _closeDuration,
        );

  bool get isOpen => anim.value > 0;

  void open() => anim.forward();
  void close() => anim.reverse();

  void handleDragUpdate(DragUpdateDetails d, double availableHeight) {
    if (anim.value == 0) return;
    final delta = d.primaryDelta ?? 0;
    final next = anim.value - delta / (availableHeight * _dragRangeFactor);
    anim.value = next.clamp(0.0, 1.0);
  }

  void handleDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() > _flingVelocityThreshold) {
      v > 0 ? close() : open();
      return;
    }
    anim.value < _snapMidpoint ? close() : open();
  }

  void dispose() => anim.dispose();
}

class _CornerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CornerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: cs.onSurface, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragDownHint extends StatefulWidget {
  final Color color;

  const _DragDownHint({required this.color});

  @override
  State<_DragDownHint> createState() => _DragDownHintState();
}

class _DragDownHintState extends State<_DragDownHint>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 2800);
  static const _activeFraction = 0.4;
  static const _height = 3.0;
  static const _slotHeight = 28.0;
  static const _startY = -6.0;
  static const _travel = 16.0;
  static const _peakOpacity = 0.32;

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _slotHeight,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ghost = _ghostFor(_c.value);
          if (ghost.opacity <= 0) return const SizedBox.shrink();
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: ghost.dy,
                height: _height,
                child: Opacity(
                  opacity: ghost.opacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
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

  ({double dy, double opacity}) _ghostFor(double phase) {
    if (phase > _activeFraction) return (dy: 0, opacity: 0);
    final local = phase / _activeFraction;
    final eased = Curves.easeOutCubic.transform(local);
    return (
      dy: _startY + eased * _travel,
      opacity: (1 - local) * _peakOpacity,
    );
  }
}

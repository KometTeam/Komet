import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class WebQrScanScreen extends StatefulWidget {
  const WebQrScanScreen({super.key});

  @override
  State<WebQrScanScreen> createState() => _WebQrScanScreenState();
}

class _WebQrScanScreenState extends State<WebQrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  static const _settleAfterDetect = Duration(milliseconds: 720);

  bool _handled = false;
  String? _armedRaw;
  Timer? _completeTimer;

  @override
  void dispose() {
    _completeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _completeScan() {
    if (!mounted || _handled) return;
    final value = _armedRaw;
    if (value == null || value.isEmpty) return;
    _handled = true;
    _completeTimer?.cancel();
    _completeTimer = null;
    unawaited(_controller.stop());
    if (mounted) Navigator.of(context).pop<String>(value);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    if (_armedRaw != raw) {
      _armedRaw = raw;
      _completeTimer?.cancel();
      _completeTimer = Timer(_settleAfterDetect, _completeScan);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.chevron_left, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'QR для веба и ПК',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) {
                final on = state.torchState == TorchState.on;
                return Icon(
                  on ? Symbols.flash_on : Symbols.flash_off,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layoutSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                fit: BoxFit.cover,
                errorBuilder: (context, error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        error.errorDetails?.message ?? 'Камера недоступна',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                },
              ),
              _TelegramStyleFinderOverlay(
                layoutSize: layoutSize,
                controller: _controller,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Наведите камеру на QR-код на экране компьютера',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black54,
                        ),
                      ],
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

class _TelegramStyleFinderOverlay extends StatefulWidget {
  const _TelegramStyleFinderOverlay({
    required this.layoutSize,
    required this.controller,
  });

  final Size layoutSize;
  final MobileScannerController controller;

  @override
  State<_TelegramStyleFinderOverlay> createState() =>
      _TelegramStyleFinderOverlayState();
}

class _TelegramStyleFinderOverlayState extends State<_TelegramStyleFinderOverlay>
    with SingleTickerProviderStateMixin {
  static const _animDuration = Duration(milliseconds: 320);
  static const _snapPx = 14.0;
  static const _frameCornerRadius = 16.0;
  static const _qrBoundsPadding = 14.0;

  late AnimationController _ac;
  late CurvedAnimation _curved;
  Rect _fromR = Rect.zero;
  Rect _toR = Rect.zero;
  StreamSubscription<BarcodeCapture>? _barcodeSub;
  bool _qrInView = false;

  @override
  void initState() {
    super.initState();
    final d = _defaultFinderRect(widget.layoutSize);
    _fromR = d;
    _toR = d;
    _ac = AnimationController(vsync: this, duration: _animDuration);
    _curved = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _ac.addListener(() => setState(() {}));
    _barcodeSub = widget.controller.barcodes.listen(_onBarcodeFrame);
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(covariant _TelegramStyleFinderOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutSize != widget.layoutSize) {
      final d = _defaultFinderRect(widget.layoutSize);
      _fromR = d;
      _toR = d;
      _ac.value = 1.0;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    unawaited(_barcodeSub?.cancel());
    _curved.dispose();
    _ac.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    final v = widget.controller.value;
    if (!v.isInitialized || !v.isRunning || v.error != null) {
      if (mounted) setState(() {});
    }
  }

  void _onBarcodeFrame(BarcodeCapture cap) {
    if (!mounted) return;
    final v = widget.controller.value;
    if (!v.isInitialized || !v.isRunning || v.error != null) return;

    final defaultRect = _defaultFinderRect(widget.layoutSize);
    final mapped = _targetFinderRectFromCapture(cap, v);
    final inView = mapped != null;
    if (inView != _qrInView) {
      setState(() => _qrInView = inView);
    }
    final next = mapped ?? defaultRect;
    if (_rectClose(_toR, next) && _ac.isCompleted) {
      return;
    }
    _animateTo(next);
  }

  Rect _defaultFinderRect(Size s) {
    final side = math.min(s.width, s.height) * 0.68;
    final left = (s.width - side) / 2;
    final top = (s.height - side) / 2 - s.height * 0.06;
    return Rect.fromLTWH(left, top, side, side);
  }

  bool _rectClose(Rect a, Rect b) {
    return (a.left - b.left).abs() < _snapPx &&
        (a.top - b.top).abs() < _snapPx &&
        (a.width - b.width).abs() < _snapPx &&
        (a.height - b.height).abs() < _snapPx;
  }

  Rect _interpolatedFinderRect() {
    if (_fromR.isEmpty || _toR.isEmpty) {
      return _defaultFinderRect(widget.layoutSize);
    }
    return Rect.lerp(_fromR, _toR, _curved.value)!;
  }

  void _animateTo(Rect target) {
    if (_rectClose(_toR, target) && _ac.isCompleted) {
      return;
    }
    double t;
    if (_ac.status == AnimationStatus.completed) {
      t = 1.0;
    } else if (_ac.status == AnimationStatus.dismissed) {
      t = 0.0;
    } else {
      t = _curved.value;
    }
    _fromR = Rect.lerp(_fromR, _toR, t)!;
    _toR = target;
    _ac.forward(from: 0);
  }

  Rect? _targetFinderRectFromCapture(
    BarcodeCapture? cap,
    MobileScannerState scannerState,
  ) {
    if (cap == null || cap.barcodes.isEmpty || widget.layoutSize.isEmpty) {
      return null;
    }
    final b = cap.barcodes.first;
    if (b.corners.length < 4) return null;

    final refSize = !cap.size.isEmpty
        ? cap.size
        : (!scannerState.size.isEmpty ? scannerState.size : Size.zero);
    if (refSize.isEmpty) return null;

    final mapped = _mapBarcodeCornersToLayout(
      b.corners.take(4).toList(),
      refSize,
      widget.layoutSize,
      scannerState.deviceOrientation,
    );
    if (mapped.length < 4) return null;
    return _axisSquareAroundCorners(
      mapped,
      widget.layoutSize,
      padding: _qrBoundsPadding,
    );
  }

  static Rect _axisSquareAroundCorners(
    List<Offset> corners,
    Size layout, {
    required double padding,
  }) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final o in corners) {
      minX = math.min(minX, o.dx);
      maxX = math.max(maxX, o.dx);
      minY = math.min(minY, o.dy);
      maxY = math.max(maxY, o.dy);
    }
    final bw = maxX - minX + 2 * padding;
    final bh = maxY - minY + 2 * padding;
    final side = math.max(bw, bh);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    var r = Rect.fromCenter(center: Offset(cx, cy), width: side, height: side);
    r = r.intersect(Rect.fromLTWH(0, 0, layout.width, layout.height));
    if (r.isEmpty) {
      return Rect.fromLTWH(0, 0, layout.shortestSide * 0.5, layout.shortestSide * 0.5);
    }
    return r;
  }

  static RRect _finderRRect(Rect rect, double maxRadius) {
    final r = math.min(
      maxRadius,
      math.min(rect.width, rect.height) * 0.14,
    );
    return RRect.fromRectAndRadius(rect, Radius.circular(r));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        if (!state.isInitialized || !state.isRunning || state.error != null) {
          return const SizedBox.expand();
        }

        final finderRect = _interpolatedFinderRect();
        final rrect = _finderRRect(finderRect, _frameCornerRadius);
        final frameColor =
            _qrInView ? const Color(0xFF4ADE80) : Colors.white;
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                size: widget.layoutSize,
                painter: _ScannerDimOutsideRRectPainter(
                  hole: rrect,
                  dimColor: Colors.black.withValues(alpha: 0.58),
                ),
              ),
              CustomPaint(
                size: widget.layoutSize,
                painter: _FinderRoundedSquareStrokePainter(
                  rrect: rrect,
                  color: frameColor,
                  strokeWidth: 3.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScannerDimOutsideRRectPainter extends CustomPainter {
  _ScannerDimOutsideRRectPainter({
    required this.hole,
    required this.dimColor,
  });

  final RRect hole;
  final Color dimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()..addRRect(hole);
    final mask = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(mask, Paint()..color = dimColor);
  }

  @override
  bool shouldRepaint(covariant _ScannerDimOutsideRRectPainter oldDelegate) {
    if (oldDelegate.dimColor != dimColor) return true;
    return oldDelegate.hole != hole;
  }
}

class _FinderRoundedSquareStrokePainter extends CustomPainter {
  _FinderRoundedSquareStrokePainter({
    required this.rrect,
    required this.color,
    required this.strokeWidth,
  });

  final RRect rrect;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(rrect, shadowPaint);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _FinderRoundedSquareStrokePainter oldDelegate) {
    return oldDelegate.rrect != rrect ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

List<Offset> _mapBarcodeCornersToLayout(
  List<Offset> barcodeCorners,
  Size cameraPreviewSize,
  Size layoutSize,
  DeviceOrientation deviceOrientation,
) {
  if (barcodeCorners.length < 4 || cameraPreviewSize.isEmpty) {
    return [];
  }

  final isLandscape = deviceOrientation == DeviceOrientation.landscapeLeft ||
      deviceOrientation == DeviceOrientation.landscapeRight;
  final cam = isLandscape ? cameraPreviewSize.flipped : cameraPreviewSize;

  final wr = layoutSize.width / cam.width;
  final hr = layoutSize.height / cam.height;
  final ratio = math.max(wr, hr);
  final hPad = (cam.width * ratio - layoutSize.width) / 2;
  final vPad = (cam.height * ratio - layoutSize.height) / 2;

  return [
    for (final o in barcodeCorners)
      Offset(
        o.dx * ratio - hPad,
        o.dy * ratio - vPad,
      ),
  ];
}


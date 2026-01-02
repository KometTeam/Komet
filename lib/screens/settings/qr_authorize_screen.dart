import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gwid/api/api_service.dart';

class QrAuthorizeScreen extends StatefulWidget {
  const QrAuthorizeScreen({super.key});

  @override
  State<QrAuthorizeScreen> createState() => _QrAuthorizeScreenState();
}

class _QrAuthorizeScreenState extends State<QrAuthorizeScreen>
  with TickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isSheetOpen = false;
  bool _isFinishing = false;
  String? _candidateCode;
  DateTime? _lastSeenAt;
  Timer? _stabilityTimer;
  Alignment _frameAlignment = Alignment.center;
  double _frameSide = 260;

  Alignment _targetFrameAlignment = Alignment.center;
  double _targetFrameSide = 260;
  Ticker? _frameTicker;
  Duration? _lastTick;
  double _screenWidth = 0;

  @override
  void dispose() {
    _stabilityTimer?.cancel();
    _frameTicker?.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _frameTicker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.of(context).size.width;
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;

    final dtSeconds = (elapsed - last).inMicroseconds / 1e6;
    if (dtSeconds <= 0) return;

    // Exponential smoothing (time-based) for stable motion regardless of FPS.
    const double timeConstant = 0.12; // seconds; smaller = snappier
    final t = 1 - exp(-dtSeconds / timeConstant);

    final nextAlignment = Alignment.lerp(_frameAlignment, _targetFrameAlignment, t) ??
        _targetFrameAlignment;
    final nextSide =
        lerpDouble(_frameSide, _targetFrameSide, t) ?? _targetFrameSide;

    final dx = (nextAlignment.x - _frameAlignment.x).abs();
    final dy = (nextAlignment.y - _frameAlignment.y).abs();
    final ds = (nextSide - _frameSide).abs();

    // Avoid rebuilding for tiny jitter.
    if (dx < 0.0025 && dy < 0.0025 && ds < 0.6) return;

    if (!mounted) return;
    setState(() {
      _frameAlignment = nextAlignment;
      _frameSide = nextSide;
    });
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    _updateTracking(capture);

    if (_isSheetOpen || _isFinishing) return;

    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        code = value;
        break;
      }
    }

    if (code == null) return;

    final now = DateTime.now();
    _lastSeenAt = now;

    if (code != _candidateCode) {
      _candidateCode = code;
      _stabilityTimer?.cancel();
      _stabilityTimer = Timer(
        const Duration(milliseconds: 1300),
        _tryConfirmCandidate,
      );
    }

    // If the same QR stays in view, the timer will trigger confirmation.
  }

  Future<bool?> _showConfirmSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.verified_user, color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Вы хотите авторизоваться?',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Подтвердите действие, если доверяете устройству, которое сгенерировало этот QR-код.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Нет'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Да'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateTracking(BarcodeCapture capture) {
    final dynamic captureDyn = capture;
    final Size? imageSize = captureDyn.size as Size?;
    if (imageSize == null) return;

    for (final barcode in capture.barcodes) {
      final bounds = _extractBounds(barcode);
      if (bounds == null) continue;

      final center = bounds.center;
      final cx = (center.dx / imageSize.width) * 2 - 1;
      final cy = (center.dy / imageSize.height) * 2 - 1;

      final targetSide =
          (bounds.width / imageSize.width) * (_screenWidth == 0 ? MediaQuery.of(context).size.width : _screenWidth) * 1.1;

      _targetFrameAlignment = Alignment(
        cx.clamp(-1.0, 1.0),
        cy.clamp(-1.0, 1.0),
      );
      _targetFrameSide = targetSide.clamp(160, 340);
      break;
    }
  }

  Rect? _extractBounds(Barcode barcode) {
    final dynamic b = barcode;
    final List<dynamic>? corners = (b.corners ?? b.cornerPoints) as List<dynamic>?;
    if (corners == null || corners.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final c in corners) {
      final offset = _asOffset(c);
      if (offset == null) continue;
      if (offset.dx < minX) minX = offset.dx;
      if (offset.dy < minY) minY = offset.dy;
      if (offset.dx > maxX) maxX = offset.dx;
      if (offset.dy > maxY) maxY = offset.dy;
    }

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return null;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset? _asOffset(dynamic value) {
    if (value is Offset) return value;
    if (value is Point) return Offset(value.x.toDouble(), value.y.toDouble());

    final dynamic dxDynamic = (value as dynamic).dx ?? (value as dynamic).x;
    final dynamic dyDynamic = (value as dynamic).dy ?? (value as dynamic).y;

    if (dxDynamic is num && dyDynamic is num) {
      return Offset(dxDynamic.toDouble(), dyDynamic.toDouble());
    }

    return null;
  }

  Future<void> _tryConfirmCandidate() async {
    final code = _candidateCode;
    final lastSeen = _lastSeenAt;

    if (code == null || lastSeen == null || _isSheetOpen || _isFinishing) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(lastSeen) > const Duration(milliseconds: 320)) {
      // QR ушёл из кадра, не подтверждаем.
      _candidateCode = null;
      return;
    }

    setState(() => _isSheetOpen = true);
    await _scannerController.stop();

    final shouldAuthorize = await _showConfirmSheet();

    if (!mounted) return;

    setState(() => _isSheetOpen = false);

    if (shouldAuthorize == true) {
      _isFinishing = true;
      final success = await _sendAuthorization(code);
      if (mounted && success) {
        Navigator.of(context).pop(code);
      } else {
        _isFinishing = false;
        await _scannerController.start();
      }
      return;
    }

    _candidateCode = null;
    _stabilityTimer?.cancel();
    _stabilityTimer = null;
    await _scannerController.start();
  }

  bool _validateQrLink(String qrLink) {
    try {
      // Parse the QR link as JSON
      final decoded = jsonDecode(qrLink) as Map<String, dynamic>;

      // Validate type field
      if (decoded['type'] != 'komet_auth_v1') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Неверный тип QR-кода. Используйте только коды, сгенерированные приложением Komet.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Validate token field
      final token = decoded['token'];
      if (token == null || (token is String && token.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR-код не содержит токен авторизации. Пожалуйста, сгенерируйте новый код.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Validate timestamp field
      final timestamp = decoded['timestamp'];
      if (timestamp == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR-код не содержит временную метку. Пожалуйста, сгенерируйте новый код.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Parse and validate timestamp freshness (within 60 seconds)
      int qrTimestamp;
      if (timestamp is int) {
        qrTimestamp = timestamp;
      } else if (timestamp is String) {
        final parsed = int.tryParse(timestamp);
        if (parsed == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Неверный формат временной метки в QR-коде.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
        qrTimestamp = parsed;
      } else if (timestamp is double) {
        qrTimestamp = timestamp.toInt();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Неверный формат временной метки в QR-коде.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      final int now = DateTime.now().millisecondsSinceEpoch;
      const int oneMinuteInMillis = 60 * 1000;

      if ((now - qrTimestamp) > oneMinuteInMillis) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR-код устарел. Пожалуйста, сгенерируйте новый на авторизуемом устройстве.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('QR link validation failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка проверки QR-кода. Убедитесь, что код был сгенерирован правильно.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _sendAuthorization(String qrLink) async {
    // Validate QR link before sending to API
    if (!_validateQrLink(qrLink)) {
      return false;
    }

    try {
      final api = ApiService.instance;

      await api.sendRawRequest(1, {"interactive": true});
      await api.sendRawRequest(96, {});
      await api.sendRawRequest(290, {"qrLink": qrLink});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запрос авторизации отправлен')),
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('Failed to send authorization request: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось отправить запрос. Попробуйте ещё раз.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Авторизовать QR-код'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleDetection,
          ),
          _ScannerOverlay(
            colors: colors,
            frameAlignment: _frameAlignment,
            frameSide: _frameSide,
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Наведите камеру на QR-код, чтобы подтвердить авторизацию.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.info_outline, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'QR не будет принят без подтверждения',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final ColorScheme colors;
  final Alignment frameAlignment;
  final double frameSide;

  const _ScannerOverlay({
    required this.colors,
    required this.frameAlignment,
    required this.frameSide,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double borderRadius = 18;
        final double maxSide =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight
                ? (constraints.biggest.shortestSide * 0.9)
                : frameSide;
        final double frameSize = frameSide.clamp(160.0, maxSide);

        return Stack(
          children: [
            Container(
              color: Colors.black.withOpacity(0.35),
            ),
            AnimatedAlign(
              alignment: frameAlignment,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                width: frameSize,
                height: frameSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: CustomPaint(
                  painter: _CornerPainter(colors.primary),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;

  _CornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const double cornerLength = 26;
    const double strokeWidth = 4;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(
      Offset(0, strokeWidth / 2),
      Offset(cornerLength, strokeWidth / 2),
      paint,
    );
    canvas.drawLine(
      Offset(strokeWidth / 2, 0),
      Offset(strokeWidth / 2, cornerLength),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - cornerLength, strokeWidth / 2),
      Offset(size.width, strokeWidth / 2),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - strokeWidth / 2, 0),
      Offset(size.width - strokeWidth / 2, cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height - strokeWidth / 2),
      Offset(cornerLength, size.height - strokeWidth / 2),
      paint,
    );
    canvas.drawLine(
      Offset(strokeWidth / 2, size.height - cornerLength),
      Offset(strokeWidth / 2, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - cornerLength, size.height - strokeWidth / 2),
      Offset(size.width, size.height - strokeWidth / 2),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - strokeWidth / 2, size.height - cornerLength),
      Offset(size.width - strokeWidth / 2, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

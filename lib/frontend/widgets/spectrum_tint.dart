import 'package:flutter/material.dart';

import '../../core/config/app_spectrum_background.dart';
import '../../core/media/dominant_color.dart';

class SpectrumTintSample {
  const SpectrumTintSample({
    required this.center,
    required this.color,
    required this.weight,
  });

  final Offset center;
  final Color color;
  final double weight;
}

abstract class SpectrumTintSource {
  BuildContext? get tintContext;

  String? get tintImageUrl;

  Color get tintFallbackColor;

  double get tintWeight;
}

class SpectrumTintRegistry {
  SpectrumTintRegistry._();

  static final SpectrumTintRegistry instance = SpectrumTintRegistry._();

  static const double _referenceWeight = 48;

  final Set<SpectrumTintSource> _sources = <SpectrumTintSource>{};
  VoidCallback? _resolutionListener;

  void register(SpectrumTintSource source) => _sources.add(source);

  void unregister(SpectrumTintSource source) => _sources.remove(source);

  void listenForResolvedColors(VoidCallback? listener) =>
      _resolutionListener = listener;

  void collect(List<SpectrumTintSample> out, Rect viewport) {
    out.clear();
    for (final source in _sources) {
      final sourceContext = source.tintContext;
      if (sourceContext == null) continue;

      final box = sourceContext.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;

      final center = box.localToGlobal(box.size.center(Offset.zero));
      if (!viewport.contains(center)) continue;

      out.add(
        SpectrumTintSample(
          center: center,
          color: _colorFor(source),
          weight: source.tintWeight / _referenceWeight,
        ),
      );
    }
  }

  Color _colorFor(SpectrumTintSource source) {
    final url = source.tintImageUrl;
    if (url == null || url.isEmpty) return source.tintFallbackColor;

    final resolved = DominantColorCache.instance.lookup(url);
    if (resolved != null) return resolved;

    final listener = _resolutionListener;
    if (listener != null) DominantColorCache.instance.request(url, listener);
    return source.tintFallbackColor;
  }
}

mixin SpectrumSurface<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    AppSpectrumBackground.current.addListener(_onSpectrumBackgroundChanged);
  }

  @override
  void dispose() {
    AppSpectrumBackground.current.removeListener(_onSpectrumBackgroundChanged);
    super.dispose();
  }

  void _onSpectrumBackgroundChanged() {
    if (mounted) setState(() {});
  }

  Color spectrumSurfaceColor(ColorScheme cs) =>
      AppSpectrumBackground.isEnabled ? Colors.transparent : cs.surface;
}

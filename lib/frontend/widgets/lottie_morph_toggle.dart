import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieMorphToggle extends StatefulWidget {
  const LottieMorphToggle({
    super.key,
    required this.value,
    required this.offIcon,
    required this.onIcon,
    required this.toOnAsset,
    required this.toOffAsset,
    this.color,
    this.size,
    this.fill = 1,
    this.duration = const Duration(milliseconds: 400),
  });

  final bool value;
  final IconData offIcon;
  final IconData onIcon;
  final String toOnAsset;
  final String toOffAsset;
  final Color? color;
  final double? size;
  final double fill;
  final Duration duration;

  @override
  State<LottieMorphToggle> createState() => _LottieMorphToggleState();
}

class _LottieMorphToggleState extends State<LottieMorphToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  String? _playing;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
    AssetLottie(widget.toOnAsset).load();
    AssetLottie(widget.toOffAsset).load();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _playing == null) return;
    if (mounted) setState(() => _playing = null);
  }

  @override
  void didUpdateWidget(LottieMorphToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.value == oldWidget.value) return;
    _controller.stop();
    _controller.value = 0;
    setState(
      () => _playing = widget.value ? widget.toOnAsset : widget.toOffAsset,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final color = widget.color ?? theme.color ?? Colors.white;
    final size = widget.size ?? theme.size ?? 24;
    final asset = _playing;
    if (asset == null) {
      return Icon(
        widget.value ? widget.onIcon : widget.offIcon,
        color: color,
        size: size,
        fill: widget.fill,
      );
    }
    return SizedBox.square(
      dimension: size,
      child: Lottie.asset(
        asset,
        controller: _controller,
        fit: BoxFit.contain,
        delegates: LottieDelegates(
          values: [
            ValueDelegate.color(const ['**'], value: color),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/animoji.dart';
import '../../models/informer_banner.dart';
import 'lottie_image.dart';

typedef InformerAnimojiLoader = Future<Animoji?> Function(int id);

class InformerBannerTile extends StatefulWidget {
  final InformerBanner banner;
  final InformerAnimojiLoader? animojiLoader;
  final ValueChanged<InformerBanner>? onPresented;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const InformerBannerTile({
    super.key,
    required this.banner,
    this.animojiLoader,
    this.onPresented,
    this.onTap,
    this.onClose,
  });

  @override
  State<InformerBannerTile> createState() => _InformerBannerTileState();
}

class _InformerBannerTileState extends State<InformerBannerTile>
    with SingleTickerProviderStateMixin {
  Future<Animoji?>? _animoji;
  late final AnimationController _textController;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textOffset;

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.banner.animatesText ? 0 : 1,
    );
    final curve = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    );
    _textOpacity = curve;
    _textOffset = Tween<Offset>(
      begin: const Offset(0.035, 0),
      end: Offset.zero,
    ).animate(curve);
    _loadAnimoji();
    _present();
    if (widget.banner.animatesText) _textController.forward();
  }

  @override
  void didUpdateWidget(InformerBannerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banner.id == widget.banner.id) return;
    _loadAnimoji();
    _textController.value = widget.banner.animatesText ? 0 : 1;
    _present();
    if (widget.banner.animatesText) _textController.forward();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _loadAnimoji() {
    final id = widget.banner.animojiId;
    final loader = widget.animojiLoader;
    _animoji = id == null || loader == null ? null : loader(id);
  }

  void _present() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPresented?.call(widget.banner);
    });
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.banner;
    final cs = Theme.of(context).colorScheme;
    final background = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.12),
      cs.surfaceContainerLow,
    );
    final content = Semantics(
      button: widget.onTap != null,
      label: [
        banner.title,
        banner.description,
      ].where((text) => text.isNotEmpty).join('. '),
      child: InkWell(
        key: ValueKey('informer-banner-${banner.id}'),
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 8, 9),
            child: Row(
              children: [
                _InformerBannerIcon(
                  future: _animoji,
                  tintWithTheme: banner.tintsIconWithTheme,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: SlideTransition(
                      position: _textOffset,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (banner.title.isNotEmpty)
                            Text(
                              banner.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          if (banner.title.isNotEmpty &&
                              banner.description.isNotEmpty)
                            const SizedBox(height: 3),
                          if (banner.description.isNotEmpty)
                            Text(
                              banner.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!banner.hidesCloseButton)
                  IconButton(
                    key: ValueKey('informer-banner-close-${banner.id}'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: widget.onClose,
                    visualDensity: VisualDensity.compact,
                    iconSize: 19,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                    icon: const Icon(Symbols.cancel, fill: 0, weight: 450),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Material(color: background, child: content);
  }
}

class _InformerBannerIcon extends StatelessWidget {
  final Future<Animoji?>? future;
  final bool tintWithTheme;

  const _InformerBannerIcon({
    required this.future,
    required this.tintWithTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (future == null) return const _InformerBannerFallbackIcon();
    return FutureBuilder<Animoji?>(
      future: future,
      builder: (context, snapshot) {
        final animoji = snapshot.data;
        if (animoji == null) return const _InformerBannerFallbackIcon();
        Widget icon = LottieImage(
          url: animoji.iconUrl,
          lottieUrl: animoji.lottieUrl,
          size: 44,
          memCacheWidth: 96,
          shimmer: false,
          eager: true,
        );
        if (tintWithTheme) {
          icon = ColorFiltered(
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.primary,
              BlendMode.srcIn,
            ),
            child: icon,
          );
        }
        return SizedBox(
          key: const ValueKey('informer-banner-animoji'),
          width: 44,
          height: 44,
          child: icon,
        );
      },
    );
  }
}

class _InformerBannerFallbackIcon extends StatelessWidget {
  const _InformerBannerFallbackIcon();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('informer-banner-fallback-icon'),
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        Symbols.chat_bubble,
        color: cs.onPrimary,
        size: 23,
        fill: 0,
        weight: 500,
      ),
    );
  }
}

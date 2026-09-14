import 'package:flutter/material.dart';

import '../../../../../core/config/app_fonts.dart';
import '../../../../../core/storage/app_database.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../main.dart' show stickersModule;
import '../../../../../models/sticker.dart';
import '../../../../widgets/lottie_image.dart';

class GreetingStickerCard extends StatefulWidget {
  final int accountId;
  final bool visible;
  final ValueChanged<StickerItem> onSend;

  const GreetingStickerCard({
    super.key,
    required this.accountId,
    required this.visible,
    required this.onSend,
  });

  @override
  State<GreetingStickerCard> createState() => _GreetingStickerCardState();
}

class _GreetingStickerCardState extends State<GreetingStickerCard> {
  static const double _stickerSize = 140;
  static const Duration _fade = Duration(milliseconds: 260);

  late final Future<StickerItem?> _sticker = _loadSticker(widget.accountId);
  bool _entered = false;
  bool _sent = false;

  static Future<StickerItem?> _loadSticker(int accountId) async {
    try {
      final welcomeIds = await AppDatabase.getWelcomeStickerIds(accountId);
      return await stickersModule.randomGreetingSticker(welcomeIds);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  void didUpdateWidget(GreetingStickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) _sent = false;
  }

  void _send(StickerItem sticker) {
    if (_sent || !widget.visible) return;
    _sent = true;
    widget.onSend(sticker);
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.visible && _entered;
    return IgnorePointer(
      ignoring: !shown,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: _fade,
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: shown ? 1 : 0.94,
          duration: _fade,
          curve: Curves.easeOutCubic,
          child: Center(
            child: FutureBuilder<StickerItem?>(
              future: _sticker,
              builder: (context, snapshot) => _GreetingCardBody(
                loading: snapshot.connectionState != ConnectionState.done,
                sticker: snapshot.data,
                stickerSize: _stickerSize,
                onSend: _send,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GreetingCardBody extends StatelessWidget {
  final bool loading;
  final StickerItem? sticker;
  final double stickerSize;
  final ValueChanged<StickerItem> onSend;

  const _GreetingCardBody({
    required this.loading,
    required this.sticker,
    required this.stickerSize,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final offersSticker = loading || sticker != null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.chatEmptyTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
            ),
          ),
          if (offersSticker) ...[
            const SizedBox(height: 6),
            Text(
              l10n.chatGreetingHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox.square(dimension: stickerSize, child: _sticker()),
          ],
        ],
      ),
    );
  }

  Widget _sticker() {
    final item = sticker;
    if (item == null) return LottieShimmer(size: stickerSize);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSend(item),
      child: LottieImage(
        url: item.url,
        lottieUrl: item.lottieUrl,
        size: stickerSize,
        memCacheWidth: (stickerSize * 2).round(),
        eager: true,
      ),
    );
  }
}

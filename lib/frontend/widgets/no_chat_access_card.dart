import 'package:flutter/material.dart';

import '../../core/config/app_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart' show animojiModule;
import '../../models/animoji.dart';
import '../screens/contacts/contact_sheet_common.dart';
import 'lottie_image.dart';

const String _stopSign = '🛑';
const double _emojiSize = 112;

Future<void> showNoChatAccessCard(BuildContext context) =>
    showBlurredCard<void>(context, (_) => const _NoChatAccessCard());

Future<Animoji?> _resolveStopSign() async {
  final known = animojiModule.findByEmoji(_stopSign);
  if (known != null) return known;
  try {
    await animojiModule.ensureLoaded();
  } catch (_) {
    return null;
  }
  return animojiModule.findByEmoji(_stopSign);
}

class _NoChatAccessCard extends StatefulWidget {
  const _NoChatAccessCard();

  @override
  State<_NoChatAccessCard> createState() => _NoChatAccessCardState();
}

class _NoChatAccessCardState extends State<_NoChatAccessCard> {
  late final Future<Animoji?> _animoji = _resolveStopSign();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width > 420 ? 340 : double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: _emojiSize,
                  child: FutureBuilder<Animoji?>(
                    future: _animoji,
                    builder: (context, snapshot) =>
                        _StopSignEmoji(animoji: snapshot.data),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.chatNoAccessMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    fontFamily: displayFontOf(context),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.chatNoAccessOk),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StopSignEmoji extends StatelessWidget {
  final Animoji? animoji;

  const _StopSignEmoji({required this.animoji});

  static const Widget _glyph = Center(
    child: Text(_stopSign, style: TextStyle(fontSize: _emojiSize * 0.72)),
  );

  @override
  Widget build(BuildContext context) {
    final source = animoji;
    if (source == null) return _glyph;
    return LottieImage(
      url: source.iconUrl,
      lottieUrl: source.lottieUrl,
      size: _emojiSize,
      memCacheWidth: (_emojiSize * 2).round(),
      placeholder: _glyph,
      shimmer: false,
      eager: true,
    );
  }
}

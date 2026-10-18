import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/lottie_morph_toggle.dart';
import '../../widgets/lottie_slash_icon.dart';

class CallSlashGlyph extends StatelessWidget {
  final String asset;
  final bool slashed;

  const CallSlashGlyph({super.key, required this.asset, required this.slashed});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    return LottieSlashIcon(
      asset: asset,
      slashed: slashed,
      color: theme.color ?? Colors.white,
      size: theme.size ?? 24,
    );
  }
}

class CallScreenGlyph extends StatelessWidget {
  final bool sharing;

  const CallScreenGlyph({super.key, required this.sharing});

  @override
  Widget build(BuildContext context) {
    return LottieMorphToggle(
      value: sharing,
      offIcon: Symbols.screen_share,
      onIcon: Symbols.stop_screen_share,
      toOnAsset: 'assets/lottie/ic_screen_share_to_stop.json',
      toOffAsset: 'assets/lottie/ic_stop_to_screen_share.json',
    );
  }
}

class CallRecordGlyph extends StatelessWidget {
  final bool recording;

  const CallRecordGlyph({super.key, required this.recording});

  @override
  Widget build(BuildContext context) {
    return LottieMorphToggle(
      value: recording,
      offIcon: Symbols.radio_button_checked,
      onIcon: Symbols.stop_circle,
      toOnAsset: 'assets/lottie/ic_record_to_stop.json',
      toOffAsset: 'assets/lottie/ic_stop_to_record.json',
    );
  }
}

class CallSpeakerGlyph extends StatelessWidget {
  final bool loud;

  const CallSpeakerGlyph({super.key, required this.loud});

  @override
  Widget build(BuildContext context) {
    return LottieMorphToggle(
      value: loud,
      offIcon: Symbols.volume_down,
      onIcon: Symbols.volume_up,
      toOnAsset: 'assets/lottie/ic_volume_down_to_up.json',
      toOffAsset: 'assets/lottie/ic_volume_up_to_down.json',
    );
  }
}

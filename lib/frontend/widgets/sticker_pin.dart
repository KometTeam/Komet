import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/protocol/packet.dart';
import '../../core/utils/logger.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart' show stickersModule;
import 'custom_notification.dart';
import 'sticker_peek.dart';

StickerPeekAction stickerPinPeekAction(BuildContext context, int stickerId) {
  final l10n = AppLocalizations.of(context)!;
  final pinned = stickersModule.isFavoriteSticker(stickerId);
  return StickerPeekAction(
    icon: pinned ? Symbols.keep_off : Symbols.push_pin,
    label: pinned ? l10n.msgActionsUnpin : l10n.msgActionsPin,
    onTap: () => toggleStickerPin(context, stickerId),
  );
}

Future<void> toggleStickerPin(BuildContext context, int stickerId) async {
  final l10n = AppLocalizations.of(context)!;
  final pinned = stickersModule.isFavoriteSticker(stickerId);
  String message;
  try {
    final ok = pinned
        ? await stickersModule.unfavoriteSticker(stickerId)
        : await stickersModule.favoriteSticker(stickerId);
    message = !ok
        ? l10n.stickerPackSheetActionFailed
        : pinned
        ? l10n.stickerUnpinned
        : l10n.stickerPinned;
  } catch (e) {
    logger.w('Стикер $stickerId: не удалось сменить закреп: $e');
    message = stickerActionError(e) ?? l10n.stickerPackSheetActionFailed;
  }
  if (!context.mounted) return;
  showCustomNotification(context, message);
}

String? stickerActionError(Object error) =>
    error is PacketError ? error.serverText : null;

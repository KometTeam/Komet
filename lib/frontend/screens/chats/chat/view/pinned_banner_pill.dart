import 'package:flutter/material.dart';
import 'package:komet/backend/modules/chats.dart' show CachedChat;
import 'package:komet/core/media/media_playback.dart';
import 'package:komet/frontend/widgets/media_playback_pill.dart';

import 'message_row_widgets.dart';

Widget? buildPinnedMessageBanner({
  required CachedChat? chat,
  required bool floating,
  BorderRadius? borderRadius,
  required bool frosted,
  required bool liquidChrome,
  required BackdropKey? backdropKey,
  required VoidCallback onTap,
  required int myId,
  required VoidCallback onUnpinRequested,
}) {
  final pinned = chat;
  if (pinned == null || !pinned.hasPinnedMessage) return null;
  return PinnedMessageBanner(
    text: pinned.pinnedMsgText,
    isPreview: pinned.pinnedMsgIsPreview,
    floating: floating,
    borderRadius: borderRadius,
    frosted: frosted,
    liquid: liquidChrome,
    backdropKey: backdropKey,
    onTap: onTap,
    onUnpin: pinned.canPinMessages(myId) ? onUnpinRequested : null,
  );
}

Widget buildPinnedAndPill({
  required CachedChat? chat,
  required bool frosted,
  required bool liquidChrome,
  required BackdropKey? backdropKey,
  required VoidCallback onTap,
  required int myId,
  required VoidCallback onUnpinRequested,
}) {
  return ValueListenableBuilder<PlaybackKind?>(
    valueListenable: MediaPlayback.instance.primary,
    builder: (context, kind, _) {
      final merged = kind != null;
      final banner = buildPinnedMessageBanner(
        chat: chat,
        floating: true,
        borderRadius: merged
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : null,
        frosted: frosted,
        liquidChrome: liquidChrome,
        backdropKey: backdropKey,
        onTap: onTap,
        myId: myId,
        onUnpinRequested: onUnpinRequested,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?banner,
          MediaPlaybackPill(
            borderRadius: banner == null
                ? BorderRadius.circular(16)
                : const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
        ],
      );
    },
  );
}

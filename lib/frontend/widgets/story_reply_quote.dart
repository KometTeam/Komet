import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../backend/modules/messages.dart' show ContactCache;
import '../../l10n/app_localizations.dart';
import '../../main.dart' show storiesModule;
import '../../models/attachment.dart';
import '../../models/story.dart';
import '../screens/stories/story_viewer_screen.dart';
import 'custom_notification.dart';

Future<void> openStoryReply(
  BuildContext context,
  StoryReplyAttachment reply,
) async {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (reply.goneAt(now)) {
    showCustomNotification(context, l10n.storyReplyUnavailable);
    return;
  }
  final owner = StoryOwner.fromMap({
    'ownerId': reply.ownerId,
    'type': reply.ownerType,
  });
  final story = owner == null
      ? null
      : await storiesModule.storyById(owner, reply.storyId);
  if (!context.mounted) return;
  if (owner == null || story == null || story.expiredAt(now)) {
    showCustomNotification(context, l10n.storyReplyUnavailable);
    return;
  }
  await openStoryViewer(
    context,
    previews: [StoryPreview(owner: owner, totalCount: 1, readCount: 1)],
    initialStories: {
      owner.ownerId: [story],
    },
  );
}

class StoryReplyQuote extends StatelessWidget {
  const StoryReplyQuote({
    super.key,
    required this.reply,
    required this.myId,
    required this.accent,
    required this.textColor,
    this.tappable = true,
  });

  final StoryReplyAttachment reply;
  final int myId;
  final Color accent;
  final Color textColor;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gone = reply.goneAt(DateTime.now().millisecondsSinceEpoch);
    final owner = reply.ownerId == myId
        ? l10n.callParticipantYou
        : (ContactCache.get(reply.ownerId) ?? l10n.storyReplyLabel);
    final preview = reply.previewUrl;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tappable ? () => openStoryReply(context, reply) : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: accent.withValues(alpha: 0.10),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 30,
                height: 40,
                child: gone || preview == null
                    ? ColoredBox(
                        color: accent.withValues(alpha: 0.18),
                        child: Icon(
                          Symbols.history_toggle_off,
                          size: 18,
                          color: accent,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: preview,
                        fit: BoxFit.cover,
                        memCacheWidth: 90,
                        errorWidget: (_, _, _) =>
                            ColoredBox(color: accent.withValues(alpha: 0.18)),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owner,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    gone ? l10n.storyReplyGone : l10n.storyReplyLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

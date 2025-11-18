import 'package:flutter/material.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/widgets/group_avatars.dart';
import 'package:gwid/widgets/group_management_panel.dart';

class GroupHeader extends StatelessWidget {
  final Chat chat;
  final Map<int, Contact> contacts;
  final int myId;
  final VoidCallback? onParticipantsChanged;

  const GroupHeader({
    super.key,
    required this.chat,
    required this.contacts,
    required this.myId,
    this.onParticipantsChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!chat.isGroup) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    final onlineCount = chat.onlineParticipantsCount;
    final totalCount = chat.participantsCount ?? chat.participantIds.length;

    return GestureDetector(
      onTap: () => _showGroupManagementPanel(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            GroupAvatars(
              chat: chat,
              contacts: contacts,
              maxAvatars: 4,
              avatarSize: 20.0,
              overlap: 6.0,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.displayTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (onlineCount > 0) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$onlineCount онлайн',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      Text(
                        '$totalCount участников',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupManagementPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupManagementPanel(
        chat: chat,
        contacts: contacts,
        myId: myId,
        onParticipantsChanged: onParticipantsChanged,
      ),
    );
  }
}

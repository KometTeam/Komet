import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/services/avatar_cache_service.dart';

class GroupAvatars extends StatelessWidget {
  final Chat chat;
  final Map<int, Contact> contacts;
  final int maxAvatars;
  final double avatarSize;
  final double overlap;

  const GroupAvatars({
    super.key,
    required this.chat,
    required this.contacts,
    this.maxAvatars = 3,
    this.avatarSize = 16.0,
    this.overlap = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!chat.isGroup) {
      return const SizedBox.shrink();
    }

    final participantIds = chat.groupParticipantIds;

    if (participantIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleParticipants = participantIds.take(maxAvatars).toList();
    final remainingCount = participantIds.length - maxAvatars;

    final totalParticipants = participantIds.length;
    double adaptiveAvatarSize;
    if (totalParticipants <= 2) {
      adaptiveAvatarSize = avatarSize * 1.5;
    } else if (totalParticipants <= 4) {
      adaptiveAvatarSize = avatarSize * 1.2;
    } else {
      adaptiveAvatarSize = avatarSize * 0.8;
    }

    return SizedBox(
      height: adaptiveAvatarSize * 2.5,
      width: adaptiveAvatarSize * 2.5,
      child: Stack(
        children: [
          ...visibleParticipants.asMap().entries.map((entry) {
            final index = entry.key;
            final participantId = entry.value;
            final contact = contacts[participantId];

            double x, y;
            if (visibleParticipants.length == 1) {
              x = adaptiveAvatarSize * 1.25;
              y = adaptiveAvatarSize * 1.25;
            } else if (visibleParticipants.length == 2) {
              x = adaptiveAvatarSize * (0.5 + index * 1.5);
              y = adaptiveAvatarSize * 1.25;
            } else {
              final angle = (index * 2 * pi) / visibleParticipants.length;
              final radius = adaptiveAvatarSize * 0.6;
              final center = adaptiveAvatarSize * 1.25;
              x = center + radius * cos(angle);
              y = center + radius * sin(angle);
            }

            return Positioned(
              left: x - adaptiveAvatarSize / 2,
              top: y - adaptiveAvatarSize / 2,
              child: _buildAvatar(
                context,
                contact,
                participantId,
                adaptiveAvatarSize,
              ),
            );
          }),

          if (remainingCount > 0)
            Positioned(
              left: adaptiveAvatarSize * 0.75,
              top: adaptiveAvatarSize * 0.75,
              child: _buildMoreIndicator(
                context,
                remainingCount,
                adaptiveAvatarSize,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    Contact? contact,
    int participantId,
    double size,
  ) {
    final colors = Theme.of(context).colorScheme;

    if (contact == null ||
        contact.photoBaseUrl == null ||
        contact.photoBaseUrl!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.surface, width: 2),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: contact != null
              ? colors.primaryContainer
              : colors.secondaryContainer,
          child: Text(
            contact?.name.isNotEmpty == true
                ? contact!.name[0].toUpperCase()
                : participantId.toString().substring(
                    participantId.toString().length - 1,
                  ),
            style: TextStyle(
              color: contact != null
                  ? colors.onPrimaryContainer
                  : colors.onSecondaryContainer,
              fontSize: size * 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return FutureBuilder<ImageProvider?>(
      future: AvatarCacheService().getAvatar(
        contact.photoBaseUrl,
        userId: participantId,
      ),
      builder: (context, snapshot) {
        ImageProvider? imageProvider;
        if (snapshot.hasData && snapshot.data != null) {
          imageProvider = snapshot.data;
        } else {
          imageProvider = NetworkImage(contact.photoBaseUrl!);
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.surface, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: size / 2,
            backgroundColor: colors.primaryContainer,
            backgroundImage: imageProvider,
            onBackgroundImageError: (exception, stackTrace) {},
            child: imageProvider == null
                ? Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : participantId.toString().substring(
                            participantId.toString().length - 1,
                          ),
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontSize: size * 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildMoreIndicator(BuildContext context, int count, double size) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.secondaryContainer,
        border: Border.all(color: colors.surface, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '+$count',
          style: TextStyle(
            color: colors.onSecondaryContainer,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

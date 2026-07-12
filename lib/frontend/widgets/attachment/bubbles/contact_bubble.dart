import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../models/attachment.dart';
import 'bubble_context.dart';

Widget buildContactCard(
  BubbleContext ctx, {
  String? firstName,
  String? lastName,
  String? name,
  String? photoUrl,
  String? phoneNumber,
}) {
  final isMe = ctx.isMe;

  final first = firstName ?? '';
  final last = lastName ?? '';
  final hasFirstName = first.isNotEmpty;
  final hasLastName = last.isNotEmpty;

  final resolvedName = (hasFirstName || hasLastName)
      ? '${hasFirstName ? first : ''}${hasLastName ? ' $last' : ''}'.trim()
      : (name ?? 'Contact');

  final bgColor = isMe ? ctx.systemTint : ctx.cs.surfaceContainerHighest;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: photoUrl != null && photoUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: kAvatarThumbSize,
                    memCacheHeight: kAvatarThumbSize,
                    fadeInDuration: const Duration(milliseconds: 120),
                    errorWidget: (_, _, _) => Icon(
                      Symbols.person,
                      color: isMe ? ctx.cs.onPrimaryContainer : ctx.cs.primary,
                      size: 24,
                    ),
                  ),
                )
              : Icon(
                  Symbols.person,
                  color: isMe ? ctx.cs.onPrimaryContainer : ctx.cs.primary,
                  size: 24,
                ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                resolvedName.isNotEmpty ? resolvedName : 'Contact',
                style: TextStyle(
                  color: ctx.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (phoneNumber != null) ...[
                const SizedBox(height: 2),
                Text(
                  phoneNumber,
                  style: TextStyle(color: ctx.dim, fontSize: 12, height: 1.2),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class ContactBubble extends StatelessWidget {
  final BubbleContext ctx;
  final ContactAttachment contact;

  const ContactBubble({super.key, required this.ctx, required this.contact});

  @override
  Widget build(BuildContext context) {
    return buildContactCard(
      ctx,
      firstName: contact.firstName,
      lastName: contact.lastName,
      name: contact.name,
      photoUrl: contact.photoUrl ?? contact.baseUrl,
      phoneNumber: contact.phoneNumber,
    );
  }
}

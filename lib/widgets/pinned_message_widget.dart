import 'package:flutter/material.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/app_sizes.dart';

class PinnedMessageWidget extends StatelessWidget {
  final Message pinnedMessage;
  final Map<int, Contact> contacts;
  final int myId;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const PinnedMessageWidget({
    super.key,
    required this.pinnedMessage,
    required this.contacts,
    required this.myId,
    this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final senderName =
        contacts[pinnedMessage.senderId]?.name ??
        (pinnedMessage.senderId == myId
            ? 'Вы'
            : 'ID ${pinnedMessage.senderId}');

    return Container(
      margin: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.6),
        border: Border(
          bottom: BorderSide(color: colors.outline.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.push_pin,
            size: 14,
            color: colors.primary.withOpacity(0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$senderName: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface.withOpacity(0.7),
                        ),
                      ),
                      TextSpan(
                        text: pinnedMessage.text.isNotEmpty
                            ? pinnedMessage.text
                            : 'Вложение',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onClose != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: colors.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

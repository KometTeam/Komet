import 'package:flutter/material.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/screens/group_settings_screen.dart';

class GroupManagementPanel extends StatefulWidget {
  final Chat chat;
  final Map<int, Contact> contacts;
  final int myId;
  final VoidCallback? onParticipantsChanged;

  const GroupManagementPanel({
    super.key,
    required this.chat,
    required this.contacts,
    required this.myId,
    this.onParticipantsChanged,
  });

  @override
  State<GroupManagementPanel> createState() => _GroupManagementPanelState();
}

class _GroupManagementPanelState extends State<GroupManagementPanel> {
  final ApiService _apiService = ApiService.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return _buildContent(context, scrollController);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final colors = Theme.of(context).colorScheme;
    final participantIds = widget.chat.groupParticipantIds;
    final participants = participantIds
        .map((id) => widget.contacts[id])
        .where((contact) => contact != null)
        .cast<Contact>()
        .toList();
    final totalParticipantsCount =
        widget.chat.participantsCount ?? participantIds.length;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.group, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chat.displayTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        '$totalParticipantsCount участников',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GroupSettingsScreen(
                          chatId: widget.chat.id,
                          initialContact:
                              widget.contacts[widget.chat.ownerId] ??
                              Contact(
                                id: 0,
                                name: widget.chat.displayTitle,
                                firstName: '',
                                lastName: '',
                              ),
                          myId: widget.myId,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.settings, color: colors.primary),
                  tooltip: 'Настройки группы',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _showAddParticipantDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Добавить участника'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                final isOwner = participant.id == widget.chat.ownerId;
                final isMe = participant.id == widget.myId;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: participant.photoBaseUrl != null
                        ? NetworkImage(participant.photoBaseUrl!)
                        : null,
                    child: participant.photoBaseUrl == null
                        ? Text(
                            participant.name.isNotEmpty
                                ? participant.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(color: colors.onPrimaryContainer),
                          )
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(
                        participant.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Создатель',
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Вы',
                            style: TextStyle(
                              color: colors.onSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'ID: ${participant.id}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isOwner || isMe
                      ? null
                      : PopupMenuButton<String>(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (value) =>
                              _handleParticipantAction(participant, value),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Удалить из группы'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove_with_messages',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_forever, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Удалить с сообщениями'),
                                ],
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddParticipantDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить участника'),
        content: const Text('Введите ID пользователя для добавления в группу'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Функция добавления участника в разработке'),
                ),
              );
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleParticipantAction(
    Contact participant,
    String action,
  ) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (action == 'remove') {
        await _removeParticipant(participant.id, cleanMessages: false);
      } else if (action == 'remove_with_messages') {
        await _removeParticipant(participant.id, cleanMessages: true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'remove'
                  ? '${participant.name} удален из группы'
                  : '${participant.name} удален с сообщениями',
            ),
          ),
        );
        widget.onParticipantsChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeParticipant(
    int userId, {
    required bool cleanMessages,
  }) async {
    print('Удаляем участника $userId, очистка сообщений: $cleanMessages');

    _apiService.sendMessage(widget.chat.id, '', replyToMessageId: null);
  }
}

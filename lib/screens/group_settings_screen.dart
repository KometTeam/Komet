import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:flutter/services.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/services/avatar_cache_service.dart';
import 'package:gwid/widgets/user_profile_panel.dart';

class GroupSettingsScreen extends StatefulWidget {
  final int chatId;
  final Contact initialContact;
  final int myId;
  final VoidCallback? onChatUpdated;

  const GroupSettingsScreen({
    super.key,
    required this.chatId,
    required this.initialContact,
    required this.myId,
    this.onChatUpdated,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late Contact _currentContact;
  StreamSubscription? _contactSubscription;
  StreamSubscription? _membersSubscription;

  final List<Map<String, dynamic>> _loadedMembers = [];
  final Set<int> _loadedMemberIds = {};
  final ScrollController _scrollController = ScrollController();
  int? _lastMarker;
  bool _isLoadingMembers = false;
  bool _hasMoreMembers = true;

  @override
  void initState() {
    super.initState();
    _currentContact = widget.initialContact;

    _contactSubscription = ApiService.instance.contactUpdates.listen((contact) {
      if (contact.id == _currentContact.id && mounted) {
        ApiService.instance.updateCachedContact(contact);
        setState(() {
          _currentContact = contact;
        });
      }
    });

    _membersSubscription = ApiService.instance.messages.listen((message) {
      if (message['type'] == 'group_members' && mounted) {
        _handleGroupMembersResponse(message['payload']);
      }
    });

    _loadMembersFromCache();

    if (_loadedMembers.length < 50) {
      _loadedMembers.clear();
      _loadedMemberIds.clear();
      _lastMarker = null;
      _hasMoreMembers = true;
      ApiService.instance.getGroupMembers(widget.chatId, marker: 0, count: 50);
      _isLoadingMembers = true;
    } else {
      _lastMarker = _loadedMembers.isNotEmpty
          ? _loadedMembers.last['id'] as int?
          : null;
      _hasMoreMembers = _loadedMembers.length >= 50;
      _isLoadingMembers = false;
      print(
        'DEBUG: Участники загружены из кэша, marker: $_lastMarker, hasMore: $_hasMoreMembers',
      );
    }

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final viewportHeight = _scrollController.position.viewportDimension;

    print(
      'DEBUG: Scroll - current: $currentScroll, max: $maxScroll, viewport: $viewportHeight, threshold: ${maxScroll - 100}',
    );

    if (currentScroll >= maxScroll - 100 && maxScroll > 0) {
      print('DEBUG: Достигнут порог скролла, вызываем _loadMoreMembers()');
      _loadMoreMembers();
    }
  }

  void _loadMembersFromCache() {
    final currentChat = _getCurrentGroupChat();
    if (currentChat == null) {
      print('DEBUG: Чат не найден в кэше');
      return;
    }

    List<dynamic> membersRaw = [];
    if (currentChat['members'] is List) {
      membersRaw = currentChat['members'] as List<dynamic>;
    } else if (currentChat['participants'] is List) {
      membersRaw = currentChat['participants'] as List<dynamic>;
    }

    print('DEBUG: Найдено ${membersRaw.length} участников в кэше чата');

    final members = <Map<String, dynamic>>[];
    for (final memberRaw in membersRaw) {
      final memberData = memberRaw as Map<String, dynamic>;
      final contact = memberData['contact'] as Map<String, dynamic>?;
      if (contact != null) {
        final memberId = contact['id'] as int;
        if (!_loadedMemberIds.contains(memberId)) {
          members.add({
            'id': memberId,
            'contact': contact,
            'presence': memberData['presence'] as Map<String, dynamic>?,
            'dialogChatId': null,
          });
          _loadedMemberIds.add(memberId);
        }
      }
    }

    _loadedMembers.addAll(members);
    print(
      'DEBUG: Загружено ${members.length} участников из кэша (всего: ${_loadedMembers.length})',
    );
  }

  void _loadMoreMembers() {
    print('DEBUG: _loadMoreMembers() вызван');
    if (_isLoadingMembers || !_hasMoreMembers || _lastMarker == null) {
      print(
        'DEBUG: Пропуск загрузки - isLoading: $_isLoadingMembers, hasMore: $_hasMoreMembers, marker: $_lastMarker',
      );
      return;
    }

    print('DEBUG: Загружаем больше участников с маркером: $_lastMarker');
    _isLoadingMembers = true;
    setState(() {});

    ApiService.instance.getGroupMembers(
      widget.chatId,
      marker: _lastMarker!,
      count: 50,
    );
  }

  void _handleGroupMembersResponse(Map<String, dynamic> payload) {
    print(
      'DEBUG: _handleGroupMembersResponse вызван с payload: ${payload.keys}',
    );
    if (!mounted) return;

    List<dynamic> membersRaw = [];
    if (payload['members'] is List) {
      membersRaw = payload['members'] as List<dynamic>;
    } else if (payload['participants'] is List) {
      membersRaw = payload['participants'] as List<dynamic>;
    }

    final members = <Map<String, dynamic>>[];
    int skippedCount = 0;
    int addedCount = 0;

    for (final memberRaw in membersRaw) {
      final memberData = memberRaw as Map<String, dynamic>;
      final contact = memberData['contact'] as Map<String, dynamic>?;
      if (contact != null) {
        final memberId = contact['id'] as int;
        if (!_loadedMemberIds.contains(memberId)) {
          members.add({
            'id': memberId,
            'contact': contact,
            'presence': memberData['presence'] as Map<String, dynamic>?,
            'dialogChatId': null,
          });
          _loadedMemberIds.add(memberId);
          addedCount++;
        } else {
          skippedCount++;
        }
      } else {
        print('WARNING: Участник без contact поля: $memberData');
      }
    }

    print(
      'DEBUG: Обработано ${membersRaw.length} участников из ответа: добавлено $addedCount, пропущено $skippedCount (дубликаты)',
    );

    final markerFromPayload = payload['marker'] as int?;
    int? nextMarker;

    if (markerFromPayload != null && markerFromPayload > 0) {
      nextMarker = markerFromPayload;
    } else if (members.isNotEmpty) {
      final lastMember = members.last;
      nextMarker = lastMember['id'] as int?;
    }

    setState(() {
      _loadedMembers.addAll(members);
      _lastMarker = nextMarker;
      _hasMoreMembers = nextMarker != null && nextMarker > 0;
      _isLoadingMembers = false;
    });

    print(
      'DEBUG: Загружено ${members.length} новых участников (всего: ${_loadedMembers.length}), маркер: $nextMarker, есть еще: $_hasMoreMembers',
    );
    print('DEBUG: _handleGroupMembersResponse завершен');
  }

  @override
  void dispose() {
    _contactSubscription?.cancel();
    _membersSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _getCurrentGroupChat() {
    final chatData = ApiService.instance.lastChatsPayload;
    if (chatData == null || chatData['chats'] == null) return null;

    final chats = chatData['chats'] as List<dynamic>;
    try {
      return chats.firstWhere(
        (chat) => chat['id'] == widget.chatId,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  void _showEditGroupNameDialog() {
    final nameController = TextEditingController(text: _currentContact.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить название группы'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Введите новое название группы',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != _currentContact.name) {
                ApiService.instance.renameGroup(widget.chatId, newName);

                setState(() {
                  _currentContact = Contact(
                    id: _currentContact.id,
                    name: newName,
                    firstName: _currentContact.firstName,
                    lastName: _currentContact.lastName,
                    description: _currentContact.description,
                    photoBaseUrl: _currentContact.photoBaseUrl,
                    isBlocked: _currentContact.isBlocked,
                    isBlockedByMe: _currentContact.isBlockedByMe,
                    accountStatus: _currentContact.accountStatus,
                    status: _currentContact.status,
                  );
                });

                widget.onChatUpdated?.call();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Название группы изменено')),
                );
              }
            },
            child: const Text('Изменить'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() {
    final chatData = ApiService.instance.lastChatsPayload;
    if (chatData == null || chatData['contacts'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить контакты')),
      );
      return;
    }

    final contacts = chatData['contacts'] as List<dynamic>;
    final availableContacts = <Map<String, dynamic>>[];

    final currentChat = _getCurrentGroupChat();
    if (currentChat != null) {
      final participants =
          currentChat['participants'] as Map<String, dynamic>? ?? {};
      final participantIds = participants.keys
          .map((id) => int.parse(id))
          .toSet();

      for (final contact in contacts) {
        final contactId = contact['id'] as int;
        if (!participantIds.contains(contactId)) {
          availableContacts.add(contact);
        }
      }
    } else {
      availableContacts.addAll(contacts.cast<Map<String, dynamic>>());
    }

    if (availableContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных контактов для добавления')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(
        contacts: availableContacts,
        onAddMembers: (selectedContacts) {
          if (selectedContacts.isNotEmpty) {
            ApiService.instance.addGroupMember(widget.chatId, selectedContacts);
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Добавлено ${selectedContacts.length} участников',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showRemoveMemberDialog() {
    final currentChat = _getCurrentGroupChat();
    if (currentChat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить данные группы')),
      );
      return;
    }

    final participants =
        currentChat['participants'] as Map<String, dynamic>? ?? {};
    final admins = currentChat['admins'] as List<dynamic>? ?? [];

    final chatData = ApiService.instance.lastChatsPayload;
    if (chatData == null || chatData['contacts'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить контакты')),
      );
      return;
    }

    final contacts = chatData['contacts'] as List<dynamic>;
    final contactMap = <int, Map<String, dynamic>>{};
    for (final contact in contacts) {
      contactMap[contact['id']] = contact;
    }

    final removableMembers = <Map<String, dynamic>>[];

    for (final participantId in participants.keys) {
      final id = int.parse(participantId);
      if (id != widget.myId && !admins.contains(id)) {
        final contact = contactMap[id];
        if (contact != null) {
          removableMembers.add({
            'id': id,
            'name': contact['names']?[0]?['name'] ?? 'ID $id',
            'contact': contact,
          });
        }
      }
    }

    if (removableMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет участников для удаления')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _RemoveMemberDialog(
        members: removableMembers,
        onRemoveMembers: (selectedMembers) {
          if (selectedMembers.isNotEmpty) {
            ApiService.instance.removeGroupMember(
              widget.chatId,
              selectedMembers,
            );
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Удалено ${selectedMembers.length} участников'),
              ),
            );
          }
        },
      ),
    );
  }

  void _showPromoteToAdminDialog() {
    final currentChat = _getCurrentGroupChat();
    if (currentChat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить данные группы')),
      );
      return;
    }

    final participants =
        currentChat['participants'] as Map<String, dynamic>? ?? {};
    final admins = currentChat['admins'] as List<dynamic>? ?? [];

    final chatData = ApiService.instance.lastChatsPayload;
    if (chatData == null || chatData['contacts'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить контакты')),
      );
      return;
    }

    final contacts = chatData['contacts'] as List<dynamic>;
    final contactMap = <int, Map<String, dynamic>>{};
    for (final contact in contacts) {
      contactMap[contact['id']] = contact;
    }

    final promotableMembers = <Map<String, dynamic>>[];

    for (final participantId in participants.keys) {
      final id = int.parse(participantId);
      if (id != widget.myId && !admins.contains(id)) {
        final contact = contactMap[id];
        if (contact != null) {
          promotableMembers.add({
            'id': id,
            'name': contact['names']?[0]?['name'] ?? 'ID $id',
            'contact': contact,
          });
        }
      }
    }

    if (promotableMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет участников для назначения администратором'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _PromoteAdminDialog(
        members: promotableMembers,
        onPromoteToAdmin: (memberId) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Функция назначения администратора будет добавлена',
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выйти из группы'),
        content: Text(
          'Вы уверены, что хотите выйти из группы "${_currentContact.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              try {
                ApiService.instance.leaveGroup(widget.chatId);

                if (mounted) {
                  Navigator.of(context)
                    ..pop()
                    ..pop();
                  widget.onChatUpdated?.call();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Вы вышли из группы'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка при выходе из группы: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  Future<void> _createInviteLink() async {
    try {
      final currentChat = _getCurrentGroupChat();
      String? cachedLink;

      if (currentChat != null) {
        cachedLink = currentChat['link'] as String?;
        if (cachedLink != null && cachedLink.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: cachedLink));

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ссылка скопирована: $cachedLink'),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
          return;
        }
      }

      final link = await ApiService.instance.createGroupInviteLink(
        widget.chatId,
        revokePrivateLink: true,
      );

      if (!mounted) return;

      if (link == null || link.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось получить пригласительную ссылку'),
          ),
        );
        return;
      }

      await Clipboard.setData(ClipboardData(text: link));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ссылка скопирована: $link'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при создании ссылки: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildGroupManagementButtons(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Участники',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildGroupMembersList(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    const double appBarHeight = 250.0;

    return SliverAppBar(
      expandedHeight: appBarHeight,
      pinned: true,
      floating: false,
      stretch: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _currentContact.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsetsDirectional.only(
          start: 56.0,
          bottom: 16.0,
          end: 16.0,
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'contact_avatar_${widget.initialContact.id}',
              child: Material(
                type: MaterialType.transparency,
                child: (_currentContact.photoBaseUrl != null)
                    ? Image.network(
                        _currentContact.photoBaseUrl!,
                        fit: BoxFit.cover,
                        height: appBarHeight,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: appBarHeight,
                          width: double.infinity,
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          child: Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                              size: 48,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: appBarHeight,
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Center(
                          child: Text(
                            _currentContact.name.isNotEmpty
                                ? _currentContact.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 96,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.5),
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupManagementButtons() {
    final colorScheme = Theme.of(context).colorScheme;

    bool amIAdmin = false;
    bool canSeeLink = false;
    final currentChat = _getCurrentGroupChat();
    if (currentChat != null) {
      final admins = currentChat['admins'] as List<dynamic>? ?? [];
      amIAdmin = admins.contains(widget.myId);

      final options = currentChat['options'] as Map<String, dynamic>?;
      final membersCanSeeLink =
          options?['MEMBERS_CAN_SEE_PRIVATE_LINK'] as bool? ?? false;
      canSeeLink = amIAdmin || membersCanSeeLink;
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate.fixed([
          if (canSeeLink) ...[
            Builder(
              builder: (context) {
                final currentChat = _getCurrentGroupChat();
                final existingLink = currentChat?['link'] as String?;

                if (existingLink != null && existingLink.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Текущая ссылка:',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              existingLink,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _createInviteLink,
                          icon: const Icon(Icons.copy),
                          label: const Text('Скопировать ссылку'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _createInviteLink,
                      icon: const Icon(Icons.link),
                      label: const Text('Пригласить по ссылке'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
          ],

          if (amIAdmin) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showEditGroupNameDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Изменить название группы'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _showAddMemberDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Добавить'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showRemoveMemberDialog,
                    icon: const Icon(Icons.person_remove),
                    label: const Text('Удалить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showPromoteToAdminDialog,
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Назначить администратором'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _showLeaveGroupDialog,
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Выйти из группы'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGroupMembersList() {
    final chatData = ApiService.instance.lastChatsPayload;
    final contacts = chatData?['contacts'] as List<dynamic>? ?? [];
    final contactMap = <int, Map<String, dynamic>>{};
    for (final contact in contacts) {
      contactMap[contact['id']] = contact;
    }

    final currentChat = _getCurrentGroupChat();
    final admins = currentChat?['admins'] as List<dynamic>? ?? [];
    final owner = currentChat?['owner'] as int?;

    print('DEBUG: owner=$owner, admins=$admins, myId=${widget.myId}');

    final members = <Map<String, dynamic>>[];

    print(
      'DEBUG: Строим список из ${_loadedMembers.length} загруженных участников',
    );

    for (final memberData in _loadedMembers) {
      final id = memberData['id'] as int?;
      if (id == null) continue;

      final contactData = memberData['contact'] as Map<String, dynamic>?;
      final contact = contactData ?? contactMap[id];
      final isAdmin = admins.contains(id);
      final isOwner = owner != null && id == owner;

      String? name;
      String? avatarUrl;
      if (contact?['names'] is List) {
        final namesList = contact?['names'] as List;
        if (namesList.isNotEmpty) {
          final nameData = namesList[0] as Map<String, dynamic>?;
          if (nameData != null) {
            final firstName = nameData['firstName'] as String? ?? '';
            final lastName = nameData['lastName'] as String? ?? '';
            final fullName = '$firstName $lastName'.trim();
            name = fullName.isNotEmpty
                ? fullName
                : (nameData['name'] as String? ?? 'ID $id');
          }
        }
      }
      if (name == null || name.isEmpty) {
        name = 'ID $id';
      }
      avatarUrl =
          contact?['baseUrl'] as String? ?? contact?['baseRawUrl'] as String?;

      String role;
      if (isOwner) {
        role = 'Владелец';
      } else if (isAdmin) {
        role = 'Администратор';
      } else {
        role = 'Участник';
      }

      final dialogChatId = memberData['dialogChatId'] as int?;

      members.add({
        'id': id,
        'name': name,
        'role': role,
        'isAdmin': isAdmin,
        'isOwner': isOwner,
        'contact': contact,
        'avatarUrl': avatarUrl,
        'dialogChatId': dialogChatId,
      });
    }

    members.sort((a, b) {
      final aId = a['id'] as int;
      final bId = b['id'] as int;
      final aIsMe = aId == widget.myId;
      final bIsMe = bId == widget.myId;
      final aIsOwner = a['isOwner'] as bool;
      final bIsOwner = b['isOwner'] as bool;
      final aIsAdmin = a['isAdmin'] as bool;
      final bIsAdmin = b['isAdmin'] as bool;

      if (aIsMe && !bIsMe) return -1;
      if (!aIsMe && bIsMe) return 1;
      if (aIsOwner && !bIsOwner) return -1;
      if (!aIsOwner && bIsOwner) return 1;
      if (aIsAdmin && !bIsAdmin) return -1;
      if (!aIsAdmin && bIsAdmin) return 1;
      return 0;
    });

    print('DEBUG: Итого участников для отображения: ${members.length}');

    if (_loadedMembers.isEmpty && _isLoadingMembers) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_loadedMembers.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Участники не загружены'),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == members.length) {
          if (_isLoadingMembers) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (!_hasMoreMembers) {
            return const SizedBox.shrink();
          }
          return const SizedBox.shrink();
        }

        final member = members[index];
        final isMe = member['id'] == widget.myId;
        final isAdmin = member['isAdmin'] as bool;
        final isOwner = member['isOwner'] as bool;
        final avatarUrl = member['avatarUrl'] as String?;
        final memberName = member['name'] as String;

        final contact = member['contact'] as Map<String, dynamic>?;
        final contactNames = contact?['names'] as List<dynamic>?;
        String? firstName;
        String? lastName;
        if (contactNames != null && contactNames.isNotEmpty) {
          final nameData = contactNames[0] as Map<String, dynamic>?;
          firstName = nameData?['firstName'] as String?;
          lastName = nameData?['lastName'] as String?;
        }
        final dialogChatId = member['dialogChatId'] as int?;

        return ListTile(
          onTap: isMe
              ? null
              : () {
                  final userId = member['id'] as int;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => UserProfilePanel(
                      userId: userId,
                      name: memberName,
                      firstName: firstName,
                      lastName: lastName,
                      avatarUrl: avatarUrl,
                      description: contact?['description'] as String?,
                      myId: widget.myId,
                      currentChatId: widget.chatId,
                      contactData: contact,
                      dialogChatId: dialogChatId,
                    ),
                  );
                },
          leading: AvatarCacheService().getAvatarWidget(
            avatarUrl,
            userId: member['id'] as int,
            size: 40,
            fallbackText: memberName,
            backgroundColor: isMe
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondaryContainer,
            textColor: isMe
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '$memberName ${isMe ? '(Вы)' : ''}',
                  style: TextStyle(
                    fontWeight: isMe || isOwner
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isMe || isOwner
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            member['role'].toString(),
            style: TextStyle(
              color: isOwner
                  ? Colors.amber[700]
                  : isAdmin
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          trailing: isOwner
              ? Icon(Icons.star, color: Colors.amber, size: 20)
              : isAdmin
              ? Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                )
              : null,
        );
      }, childCount: members.length + (_isLoadingMembers ? 1 : 0)),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final List<Map<String, dynamic>> contacts;
  final Function(List<int>) onAddMembers;

  const _AddMemberDialog({required this.contacts, required this.onAddMembers});

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final Set<int> _selectedContacts = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить участников'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: widget.contacts.length,
          itemBuilder: (context, index) {
            final contact = widget.contacts[index];
            final contactId = contact['id'] as int;
            final contactName =
                contact['names']?[0]?['name'] ?? 'ID $contactId';
            final isSelected = _selectedContacts.contains(contactId);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedContacts.add(contactId);
                  } else {
                    _selectedContacts.remove(contactId);
                  }
                });
              },
              title: Text(contactName),
              subtitle: Text('ID: $contactId'),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _selectedContacts.isEmpty
              ? null
              : () => widget.onAddMembers(_selectedContacts.toList()),
          child: Text('Добавить (${_selectedContacts.length})'),
        ),
      ],
    );
  }
}

class _RemoveMemberDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final Function(List<int>) onRemoveMembers;

  const _RemoveMemberDialog({
    required this.members,
    required this.onRemoveMembers,
  });

  @override
  State<_RemoveMemberDialog> createState() => _RemoveMemberDialogState();
}

class _RemoveMemberDialogState extends State<_RemoveMemberDialog> {
  final Set<int> _selectedMembers = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Удалить участников'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: widget.members.length,
          itemBuilder: (context, index) {
            final member = widget.members[index];
            final memberId = member['id'] as int;
            final memberName = member['name'] as String;
            final isSelected = _selectedMembers.contains(memberId);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedMembers.add(memberId);
                  } else {
                    _selectedMembers.remove(memberId);
                  }
                });
              },
              title: Text(memberName),
              subtitle: Text('ID: $memberId'),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _selectedMembers.isEmpty
              ? null
              : () => widget.onRemoveMembers(_selectedMembers.toList()),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: Text('Удалить (${_selectedMembers.length})'),
        ),
      ],
    );
  }
}

class _PromoteAdminDialog extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final Function(int) onPromoteToAdmin;

  const _PromoteAdminDialog({
    required this.members,
    required this.onPromoteToAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Назначить администратором'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final memberId = member['id'] as int;
            final memberName = member['name'] as String;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  memberName[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              title: Text(memberName),
              subtitle: Text('ID: $memberId'),
              trailing: const Icon(Icons.admin_panel_settings),
              onTap: () => onPromoteToAdmin(memberId),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}

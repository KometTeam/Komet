import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/main.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/contacts.dart';
import 'package:komet/backend/modules/messages.dart' show ContactCache;
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/core/storage/token_storage.dart';
import 'package:komet/frontend/screens/contacts/contact_sheet_common.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/komet_avatar.dart';
import 'package:komet/l10n/app_localizations.dart';

class _Candidate {
  final int id;
  final String name;
  final String? avatarUrl;

  const _Candidate({required this.id, required this.name, this.avatarUrl});
}

Future<bool?> showAddMembersSheet(
  BuildContext context, {
  required int chatId,
  required Set<int> excludeIds,
}) {
  return showBlurredCard<bool>(
    context,
    (host) => _AddMembersCard(
      chatId: chatId,
      excludeIds: excludeIds,
      hostContext: host,
    ),
  );
}

class _AddMembersCard extends StatefulWidget {
  final int chatId;
  final Set<int> excludeIds;
  final BuildContext hostContext;

  const _AddMembersCard({
    required this.chatId,
    required this.excludeIds,
    required this.hostContext,
  });

  @override
  State<_AddMembersCard> createState() => _AddMembersCardState();
}

class _AddMembersCardState extends State<_AddMembersCard> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<int> _selected = {};
  List<_Candidate> _all = [];
  String _query = '';
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final byId = <int, _Candidate>{};

    final contacts = await ContactsModule.getContacts(accountId);
    for (final c in contacts) {
      if (c.id == accountId || widget.excludeIds.contains(c.id)) continue;
      final name = [
        c.firstName,
        c.lastName,
      ].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();
      byId[c.id] = _Candidate(
        id: c.id,
        name: name.isEmpty ? '${c.id}' : name,
        avatarUrl: c.baseUrl,
      );
    }

    final dialogs = await AppDatabase.loadDialogChats(accountId);
    for (final row in dialogs) {
      final chat = CachedChat.fromDbRow(row);
      for (final pid in chat.participants.keys) {
        if (pid == accountId ||
            widget.excludeIds.contains(pid) ||
            byId.containsKey(pid)) {
          continue;
        }
        final name = chat.title ?? ContactCache.get(pid) ?? '$pid';
        byId[pid] = _Candidate(
          id: pid,
          name: name,
          avatarUrl: chat.iconUrl ?? ContactCache.getAvatar(pid),
        );
      }
    }

    final list = byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) {
      setState(() {
        _all = list;
        _loading = false;
      });
    }
  }

  List<_Candidate> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _submit() async {
    if (_selected.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final ok = await chats.addMembers(
      api,
      chatId: widget.chatId,
      userIds: _selected.toList(),
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (ok) {
      Navigator.of(context).pop(true);
      if (widget.hostContext.mounted) {
        showCustomNotification(widget.hostContext, l10n.chatInfoMembersAdded);
      }
    } else {
      setState(() => _submitting = false);
      showCustomNotification(context, l10n.chatInfoAddMembersError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.5;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width > 420 ? 380 : double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.chatInfoAddMember,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                          style: TextStyle(color: cs.onSurface, fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            constraints: const BoxConstraints(maxWidth: 150),
                            prefixIcon: Icon(
                              Symbols.search,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 34,
                            ),
                            border: InputBorder.none,
                            hintText: l10n.chatInfoMembersSearchHint,
                            hintStyle: TextStyle(
                              color: cs.outline,
                              fontSize: 14,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 0.5, color: cs.outlineVariant),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxListHeight),
                  child: _buildList(cs, l10n),
                ),
                Divider(height: 1, thickness: 0.5, color: cs.outlineVariant),
                _buildAddButton(cs, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(ColorScheme cs, AppLocalizations l10n) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            l10n.chatInfoAddMembersEmpty,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (_, i) => _candidateRow(cs, items[i]),
    );
  }

  Widget _candidateRow(ColorScheme cs, _Candidate c) {
    final selected = _selected.contains(c.id);
    return InkWell(
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(c.id);
        } else {
          _selected.add(c.id);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            KometAvatar(name: c.name, imageUrl: c.avatarUrl, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              selected
                  ? Symbols.check_circle
                  : Symbols.radio_button_unchecked,
              fill: selected ? 1 : 0,
              color: selected ? cs.primary : cs.outline,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(ColorScheme cs, AppLocalizations l10n) {
    final enabled = _selected.isNotEmpty && !_submitting;
    return InkWell(
      onTap: enabled ? _submit : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_submitting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                _selected.isEmpty
                    ? l10n.chatInfoAddMembersAction
                    : '${l10n.chatInfoAddMembersAction} · ${_selected.length}',
                style: TextStyle(
                  color: enabled ? cs.primary : cs.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showInviteLinkSheet(
  BuildContext context, {
  required String link,
  required String title,
  String? avatarUrl,
}) {
  return showBlurredCard<void>(
    context,
    (host) => _InviteLinkCard(
      link: link,
      title: title,
      avatarUrl: avatarUrl,
      hostContext: host,
    ),
  );
}

class _InviteLinkCard extends StatelessWidget {
  final String link;
  final String title;
  final String? avatarUrl;
  final BuildContext hostContext;

  const _InviteLinkCard({
    required this.link,
    required this.title,
    this.avatarUrl,
    required this.hostContext,
  });

  String get _shortLink => link.replaceFirst(RegExp(r'^https?://'), '');

  Future<void> _copy(BuildContext context) async {
    final message = AppLocalizations.of(context)!.sharedLinkCopied;
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (hostContext.mounted) showCustomNotification(hostContext, message);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width > 420 ? 380 : double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.chatInfoInviteLink.toUpperCase(),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    child: Row(
                      children: [
                        KometAvatar(name: title, imageUrl: avatarUrl, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _shortLink,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Symbols.content_copy, color: cs.primary),
                          onPressed: () => _copy(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.chatInfoInviteLinkHint,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _copy(context),
                      icon: const Icon(Symbols.content_copy, size: 20),
                      label: Text(l10n.sharedCopyLink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

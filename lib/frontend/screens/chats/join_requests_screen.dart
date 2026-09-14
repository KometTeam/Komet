import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/chats.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/config/app_shape.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/reload_on_reconnect.dart';
import '../../widgets/small_spinner.dart';

// #***! входящие заявки на вступление, видно админам группы/канала
class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key, required this.chatId});

  final int chatId;

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen>
    with ReloadOnReconnect {
  List<ChatMemberEntry> _requests = const [];
  bool _isLoading = true;
  final Set<int> _pending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void reloadAfterReconnect() => _load();

  Future<void> _load() async {
    final page = await chats.getJoinRequests(api, widget.chatId);
    if (!mounted) return;
    if (page == null) {
      setState(() => _isLoading = false);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.joinRequestsLoadError,
      );
      return;
    }
    setState(() {
      _requests = page.members;
      _isLoading = false;
    });
  }

  String _nameOf(ChatMemberEntry m) =>
      m.name ?? m.fullName ?? 'ID ${m.id}';

  Future<void> _resolve(ChatMemberEntry m, {required bool approve}) async {
    if (_pending.contains(m.id)) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pending.add(m.id));
    final ok = approve
        ? await chats.approveJoinRequests(
            api,
            chatId: widget.chatId,
            userIds: [m.id],
          )
        : await chats.declineJoinRequests(
            api,
            chatId: widget.chatId,
            userIds: [m.id],
          );
    if (!mounted) return;
    setState(() {
      _pending.remove(m.id);
      if (ok) _requests = _requests.where((r) => r.id != m.id).toList();
    });
    showCustomNotification(
      context,
      ok
          ? (approve ? l10n.joinRequestsApproved : l10n.joinRequestsDeclined)
          : l10n.joinRequestsActionFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(cs),
            Expanded(child: _buildBody(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Symbols.arrow_back,
              color: cs.onSurface,
              size: 24,
              weight: 400,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          ConnectionTitleText(
            AppLocalizations.of(context)!.joinRequestsTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_isLoading) return const Center(child: SmallSpinner(size: 36));
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.how_to_reg, size: 48, color: cs.outline, weight: 400),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.joinRequestsEmpty,
              style: TextStyle(color: cs.outline, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: _requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _buildTile(cs, _requests[index]),
    );
  }

  Widget _buildTile(ColorScheme cs, ChatMemberEntry m) {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameOf(m);
    final busy = _pending.contains(m.id);
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: AppShape.cardRadius,
      depth: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            KometAvatar(name: name, size: 44, imageUrl: m.avatarUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              SmallSpinner(size: 20, color: cs.primary)
            else ...[
              IconButton(
                icon: Icon(Symbols.check_circle, color: cs.primary, size: 26),
                tooltip: l10n.joinRequestsApprove,
                onPressed: () => _resolve(m, approve: true),
              ),
              IconButton(
                icon: Icon(Symbols.cancel, color: cs.error, size: 26),
                tooltip: l10n.joinRequestsDecline,
                onPressed: () => _resolve(m, approve: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

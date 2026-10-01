import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../models/animoji.dart';
import '../../../../models/chat_reaction_settings.dart';
import '../../../widgets/custom_notification.dart';
import '../../../widgets/lottie_image.dart';
import '../../../widgets/settings_card.dart';
import '../../../widgets/small_spinner.dart';
import 'chat_admin_state.dart';
import 'chat_admin_widgets.dart';

class ReactionSettingsScreen extends StatefulWidget {
  final ChatAdminState state;

  const ReactionSettingsScreen({super.key, required this.state});

  @override
  State<ReactionSettingsScreen> createState() => _ReactionSettingsScreenState();
}

class _ReactionSettingsScreenState extends State<ReactionSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool? _draftActive;
  int? _draftCount;
  Set<String>? _draftAllowed;
  List<Animoji> _catalog = const [];
  List<String> _catalogEmojis = const [];
  ChatReactionSettings? _allowedSource;
  Set<String> _serverAllowedCache = const {};

  ChatAdminState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Future.wait([
        if (_state.reactions == null) _state.loadReactions(),
        animojiModule.ensureLoaded(),
      ]);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loading = false;
      _catalog = animojiModule.animojis;
      _catalogEmojis = [for (final animoji in _catalog) animoji.emoji];
      _allowedSource = null;
    });
  }

  Set<String> _serverAllowed(ChatReactionSettings server) {
    if (!identical(_allowedSource, server)) {
      _allowedSource = server;
      _serverAllowedCache = server.allowedOf(_catalogEmojis);
    }
    return _serverAllowedCache;
  }

  bool _active(ChatReactionSettings server) => _draftActive ?? server.isActive;

  int _count(ChatReactionSettings server) => _draftCount ?? server.count;

  Set<String> _allowed(ChatReactionSettings server) =>
      _draftAllowed ?? _serverAllowed(server);

  bool _restricted(ChatReactionSettings server) => _draftAllowed == null
      ? server.restricted
      : _draftAllowed!.length < _catalogEmojis.length;

  bool _dirty(ChatReactionSettings server) =>
      _active(server) != server.isActive ||
      _count(server) != server.count ||
      (_draftAllowed != null &&
          !setEquals(_draftAllowed, _serverAllowed(server)));

  List<String> _forbidden(ChatReactionSettings server) {
    final draft = _draftAllowed;
    if (draft != null) {
      return ChatReactionSettings.forbiddenOf(_catalogEmojis, draft);
    }
    if (!server.included) return server.reactionIds;
    return ChatReactionSettings.forbiddenOf(
      _catalogEmojis,
      _serverAllowed(server),
    );
  }

  Future<void> _save(ChatReactionSettings server) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final active = _active(server);
    if (active && _draftAllowed != null && _draftAllowed!.isEmpty) {
      showCustomNotification(context, l10n.reactionsNoneAllowed);
      return;
    }
    final count = _count(server);
    final forbidden = _forbidden(server);
    setState(() => _saving = true);
    final ok = await runAdminAction(
      context,
      () => active
          ? _state.setReactions(count: count, forbidden: forbidden)
          : _state.disableReactions(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) return;
      _editing = false;
      _draftActive = null;
      _draftCount = null;
      _draftAllowed = null;
    });
    if (ok) showCustomNotification(context, l10n.groupSettingsSaved);
  }

  void _toggleEditing(ChatReactionSettings server) {
    setState(() {
      _draftAllowed ??= {..._serverAllowed(server)};
      _editing = !_editing;
    });
  }

  void _toggleReaction(ChatReactionSettings server, String emoji) {
    setState(() {
      final draft = _draftAllowed ??= {..._serverAllowed(server)};
      if (!draft.remove(emoji)) draft.add(emoji);
    });
  }

  void _reset() {
    setState(() {
      _draftAllowed = _catalogEmojis.toSet();
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final server = _state.reactions;
        return AdminScaffold(
          title: l10n.reactionsTitle,
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(child: SmallSpinner(size: 22)),
              )
            else if (server != null)
              IconButton(
                tooltip: l10n.adminSave,
                icon: const Icon(Symbols.check),
                onPressed: _dirty(server) ? () => _save(server) : null,
              ),
          ],
          body: server == null
              ? MembersListFooter(
                  loading: _loading,
                  message: l10n.reactionsLoadFailed,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                )
              : _body(l10n, server),
        );
      },
    );
  }

  Widget _body(AppLocalizations l10n, ChatReactionSettings server) {
    final cs = Theme.of(context).colorScheme;
    final active = _active(server);
    final count = _count(server);
    final allowed = _allowed(server);
    final catalog = _catalog;
    final shown = _editing
        ? catalog
        : catalog.where((animoji) => allowed.contains(animoji.emoji)).toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        SettingsCard(
          children: [
            SettingsToggleTile(
              icon: Symbols.add_reaction,
              label: l10n.reactionsEnable,
              value: active,
              enabled: !_saving,
              onChanged: (value) => setState(() => _draftActive = value),
            ),
          ],
        ),
        if (active) ...[
          const SizedBox(height: 20),
          AdminSectionCaption(l10n.reactionsCountHeader),
          SettingsPanel(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('1', style: TextStyle(color: cs.onSurfaceVariant)),
                    Expanded(
                      child: Text(
                        l10n.reactionsCountValue(count),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurface, fontSize: 15),
                      ),
                    ),
                    Text(
                      '${ChatReactionSettings.maxCount}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                Slider(
                  value: count.toDouble(),
                  min: 1,
                  max: ChatReactionSettings.maxCount.toDouble(),
                  divisions: ChatReactionSettings.maxCount - 1,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _draftCount = value.round()),
                ),
              ],
            ),
          ),
          if (catalog.isNotEmpty) ...[
            const SizedBox(height: 20),
            AdminSectionCaption(
              l10n.reactionsAllowedHeader,
              trailing: TextButton(
                onPressed: _saving ? null : () => _toggleEditing(server),
                child: Text(_editing ? l10n.reactionsDone : l10n.reactionsEdit),
              ),
            ),
            SettingsPanel(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final animoji in shown)
                    _ReactionCell(
                      key: ValueKey(animoji.id),
                      animoji: animoji,
                      dimmed: !allowed.contains(animoji.emoji),
                      onTap: _editing
                          ? () => _toggleReaction(server, animoji.emoji)
                          : null,
                    ),
                ],
              ),
            ),
          ],
          if (_restricted(server) && !_editing) ...[
            const SizedBox(height: 16),
            SettingsCard(
              children: [
                AdminActionTile(
                  icon: Symbols.refresh,
                  label: l10n.reactionsReset,
                  color: cs.error,
                  onTap: _saving || catalog.isEmpty ? null : _reset,
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _ReactionCell extends StatelessWidget {
  final Animoji animoji;
  final bool dimmed;
  final VoidCallback? onTap;

  const _ReactionCell({
    super.key,
    required this.animoji,
    required this.dimmed,
    this.onTap,
  });

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final icon = animoji.iconUrl;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: dimmed ? 0.25 : 1,
        child: SizedBox.square(
          dimension: _size,
          child: Center(
            child: icon == null || icon.isEmpty
                ? Text(animoji.emoji, style: const TextStyle(fontSize: 28))
                : LottieImage(url: icon, size: 32, memCacheWidth: 96),
          ),
        ),
      ),
    );
  }
}

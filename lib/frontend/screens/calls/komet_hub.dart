import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/call_session.dart';
import '../../../core/games/checkers.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/sheet_helpers.dart';

Future<void> showKometHub(
  BuildContext context, {
  required CallSession session,
  required ColorScheme scheme,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: _KometHub(session: session),
    ),
  );
}

enum _HubPage { menu, chat, games, checkers }

class _KometHub extends StatefulWidget {
  final CallSession session;

  const _KometHub({required this.session});

  @override
  State<_KometHub> createState() => _KometHubState();
}

class _KometHubState extends State<_KometHub> {
  _HubPage _page = _HubPage.menu;

  void _go(_HubPage page) => setState(() => _page = page);

  void _back() {
    switch (_page) {
      case _HubPage.menu:
        Navigator.of(context).maybePop();
        break;
      case _HubPage.checkers:
        _go(_HubPage.games);
        break;
      case _HubPage.chat:
      case _HubPage.games:
        _go(_HubPage.menu);
        break;
    }
  }

  String get _title {
    final l10n = AppLocalizations.of(context)!;
    switch (_page) {
      case _HubPage.menu:
        return l10n.hubTitleMenu;
      case _HubPage.chat:
        return l10n.hubChatPageTitle;
      case _HubPage.games:
        return l10n.hubGamesTitle;
      case _HubPage.checkers:
        return l10n.hubCheckersTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(cs),
              Flexible(child: _body(cs)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _back,
            icon: Icon(
              _page == _HubPage.menu ? Symbols.close : Symbols.arrow_back,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _title,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    switch (_page) {
      case _HubPage.menu:
        return _menu(cs);
      case _HubPage.games:
        return _games(cs);
      case _HubPage.chat:
        return _KometChatView(session: widget.session);
      case _HubPage.checkers:
        return _CheckersView(session: widget.session);
    }
  }

  Widget _menu(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tile(
          cs,
          Symbols.forum,
          l10n.hubChatTileTitle,
          l10n.hubChatTileSubtitle,
          () => _go(_HubPage.chat),
        ),
        _tile(
          cs,
          Symbols.stadia_controller,
          l10n.hubGamesTitle,
          l10n.hubGamesTileSubtitle,
          () => _go(_HubPage.games),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _games(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tile(
          cs,
          Symbols.grid_on,
          l10n.hubCheckersTitle,
          l10n.hubCheckersTileSubtitle,
          () => _go(_HubPage.checkers),
        ),
        _tile(
          cs,
          Symbols.more_horiz,
          l10n.hubMoreSoonTitle,
          l10n.hubMoreSoonSubtitle,
          null,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _tile(
    ColorScheme cs,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap,
  ) {
    final enabled = onTap != null;
    return ListTile(
      onTap: onTap,
      enabled: enabled,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: enabled ? cs.primary : cs.onSurfaceVariant),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? cs.onSurface : cs.onSurfaceVariant,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      ),
      trailing: enabled
          ? Icon(Symbols.chevron_right, color: cs.onSurfaceVariant)
          : null,
    );
  }
}

class _KometChatView extends StatefulWidget {
  final CallSession session;

  const _KometChatView({required this.session});

  @override
  State<_KometChatView> createState() => _KometChatViewState();
}

class _KometChatViewState extends State<_KometChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<CallChatMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.session.chatMessages.listen((_) {
      if (mounted) setState(() {});
      _scrollToBottom();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.session.sendChatMessage(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final messages = widget.session.chatLog;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Row(
            children: [
              Icon(Symbols.lock, size: 16, color: cs.primary, fill: 1),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.hubChatPrivacyNote,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: messages.isEmpty
              ? _empty(cs)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _bubble(cs, messages[i]),
                ),
        ),
        _input(cs),
      ],
    );
  }

  Widget _empty(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          AppLocalizations.of(context)!.hubChatEmpty,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
      ),
    );
  }

  Widget _bubble(ColorScheme cs, CallChatMessage message) {
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: message.mine ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.mine ? cs.onPrimary : cs.onSurface,
            fontSize: 15,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  Widget _input(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: TextStyle(color: cs.onSurface, fontSize: 15),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.hubChatInputHint,
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _send,
            icon: const Icon(Symbols.send, fill: 1),
          ),
        ],
      ),
    );
  }
}

class _CheckersView extends StatefulWidget {
  final CallSession session;

  const _CheckersView({required this.session});

  @override
  State<_CheckersView> createState() => _CheckersViewState();
}

class _CheckersViewState extends State<_CheckersView> {
  List<int> _board = Checkers.initial();
  CheckersSide _turn = CheckersSide.white;
  List<int> _path = const [];
  List<List<int>> _legal = const [];
  CheckersSide? _result;
  late final CheckersSide _me;
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    final self = widget.session.selfUserId;
    final peer = widget.session.peerUserId ?? (self + 1);
    _me = self <= peer ? CheckersSide.white : CheckersSide.black;
    _recompute();
    _sub = widget.session.gameMessages.listen(_onGame);
  }

  void _recompute() {
    _legal = Checkers.legalMoves(_board, _turn);
    _result = _legal.isEmpty ? Checkers.opponent(_turn) : null;
  }

  void _restart() {
    _board = Checkers.initial();
    _turn = CheckersSide.white;
    _path = const [];
    _recompute();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onGame(Map<String, dynamic> data) {
    if (data['g'] != 'checkers') return;
    if (data['a'] == 'reset') {
      setState(_restart);
      return;
    }
    if (data['a'] == 'move') {
      final raw = data['path'];
      if (raw is! List) return;
      _applyMove(raw.map((e) => e as int).toList(), fromRemote: true);
    }
  }

  void _applyMove(List<int> path, {required bool fromRemote}) {
    if (!_legal.any((p) => _listEq(p, path))) return;
    setState(() {
      _board = Checkers.applyMove(_board, path);
      _turn = Checkers.opponent(_turn);
      _path = const [];
      _recompute();
    });
    if (!fromRemote) {
      widget.session.sendGame({'g': 'checkers', 'a': 'move', 'path': path});
    }
  }

  void _reset() {
    setState(_restart);
    widget.session.sendGame({'g': 'checkers', 'a': 'reset'});
  }

  void _onTap(int square) {
    if (_turn != _me || _result != null) return;

    if (_path.isEmpty) {
      if (_legal.any((p) => p.first == square)) {
        setState(() => _path = [square]);
      }
      return;
    }

    final prefix = [..._path, square];
    final matching = _legal.where((p) => _startsWith(p, prefix)).toList();
    if (matching.isEmpty) {
      setState(
        () =>
            _path = _legal.any((p) => p.first == square) ? [square] : const [],
      );
      return;
    }
    if (matching.any((p) => p.length == prefix.length)) {
      _applyMove(prefix, fromRemote: false);
    } else {
      setState(() => _path = prefix);
    }
  }

  Set<int> _options() {
    if (_turn != _me || _result != null) return const {};
    if (_path.isEmpty) return {for (final p in _legal) p.first};
    final next = <int>{};
    for (final p in _legal) {
      if (_startsWith(p, _path) && p.length > _path.length) {
        next.add(p[_path.length]);
      }
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _status(),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Symbols.refresh, size: 20),
                label: Text(l10n.hubCheckersRestart),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _boardWidget(cs),
          const SizedBox(height: 10),
          Text(
            _me == CheckersSide.white
                ? l10n.hubCheckersYouWhite
                : l10n.hubCheckersYouBlack,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _status() {
    final l10n = AppLocalizations.of(context)!;
    final w = _result;
    if (w != null) return w == _me ? l10n.hubCheckersWon : l10n.hubCheckersLost;
    return _turn == _me ? l10n.hubCheckersYourMove : l10n.hubCheckersOpponentMove;
  }

  Widget _boardWidget(ColorScheme cs) {
    final flip = _me == CheckersSide.black;
    final options = _options();
    final selected = _path.isNotEmpty ? _path.last : -1;

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Checkers.size,
          ),
          itemCount: Checkers.size * Checkers.size,
          itemBuilder: (_, i) {
            final square = flip ? (Checkers.size * Checkers.size - 1 - i) : i;
            final rb = square ~/ Checkers.size;
            final cb = square % Checkers.size;
            final dark = (rb + cb) % 2 == 1;
            return GestureDetector(
              onTap: dark ? () => _onTap(square) : null,
              child: _cell(
                cs,
                dark: dark,
                piece: _board[square],
                option: options.contains(square),
                selected: square == selected,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cell(
    ColorScheme cs, {
    required bool dark,
    required int piece,
    required bool option,
    required bool selected,
  }) {
    final base = dark ? cs.surfaceContainerHighest : cs.surfaceContainerLow;
    return Container(
      color: selected ? cs.primary.withValues(alpha: 0.45) : base,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (option && piece == Checkers.empty)
            FractionallySizedBox(
              widthFactor: 0.34,
              heightFactor: 0.34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.55),
                ),
              ),
            ),
          if (piece != Checkers.empty) _piece(cs, piece, option),
        ],
      ),
    );
  }

  Widget _piece(ColorScheme cs, int piece, bool option) {
    final white = Checkers.sideOf(piece) == CheckersSide.white;
    final king = Checkers.isKing(piece);
    return FractionallySizedBox(
      widthFactor: 0.76,
      heightFactor: 0.76,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: white ? const Color(0xFFEDEDED) : const Color(0xFF262626),
          border: Border.all(
            color: option
                ? cs.primary
                : (white ? const Color(0xFFB8B8B8) : const Color(0xFF050505)),
            width: option ? 2.5 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: king
            ? Icon(
                Symbols.star,
                fill: 1,
                size: 16,
                color: white
                    ? const Color(0xFF8A6D00)
                    : const Color(0xFFE7C200),
              )
            : null,
      ),
    );
  }

  bool _startsWith(List<int> path, List<int> prefix) {
    if (path.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (path[i] != prefix[i]) return false;
    }
    return true;
  }

  bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

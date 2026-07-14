import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart' show api, accountModule;
import '../../../backend/modules/account.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../core/calls/call_controller.dart';
import '../../../backend/modules/calls.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/chat_menu_overlay.dart';
import '../../widgets/small_spinner.dart';
import 'call_screen.dart';

class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  List<CallLogEntry> _calls = [];
  final Set<String> _removing = {};
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0 for 'Все', 1 for 'Пропущенные'
  StreamSubscription<LoginStatus>? _loginSub;

  @override
  void initState() {
    super.initState();
    if (accountModule.isLoggedIn) {
      _loadHistory();
    } else {
      _loginSub = accountModule.loginStatusStream.listen((status) {
        if (status == LoginStatus.success) {
          _loginSub?.cancel();
          _loginSub = null;
          _loadHistory();
        }
      });
    }
  }

  @override
  void dispose() {
    _loginSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final p = await AppDatabase.loadActiveProfile();
    if (p == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final callsModule = CallsModule(api);
    List<CallLogEntry> calls;
    try {
      calls = await callsModule.fetchHistory(p.id, p.id);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final List<CallLogEntry> grouped = [];
    for (final call in calls) {
      if (grouped.isNotEmpty &&
          grouped.last.peerId == call.peerId &&
          grouped.last.status == call.status &&
          _isSameDay(grouped.last.time, call.time)) {
        final last = grouped.removeLast();
        grouped.add(
          CallLogEntry(
            id: last.id,
            accountId: last.accountId,
            peerId: last.peerId,
            name: last.name,
            avatarUrl: last.avatarUrl,
            status: last.status,
            time: last.time,
            count: last.count + 1,
            isGroup: last.isGroup,
          ),
        );
      } else {
        grouped.add(call);
      }
    }

    if (mounted) {
      setState(() {
        _calls = grouped;
        _isLoading = false;
      });
    }
  }

  bool _isSameDay(int time1, int time2) {
    if (time1 == 0 || time2 == 0) return false;
    final d1 = DateTime.fromMillisecondsSinceEpoch(time1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(time2);
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatDate(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.day} ${kRuMonthsShort[dt.month - 1]}';
  }

  Widget _buildCallItem(
    BuildContext context,
    ColorScheme cs,
    CallLogEntry call,
  ) {
    final bool isMissed = call.status == CallStatus.missed;

    String statusText;
    IconData statusIcon;
    switch (call.status) {
      case CallStatus.missed:
        statusText = 'Пропущенный';
        statusIcon = Symbols.phone_missed;
        break;
      case CallStatus.canceled:
        statusText = 'Отменённый';
        statusIcon = Symbols.phone_disabled;
        break;
      case CallStatus.outgoing:
        statusText = 'Исходящий';
        statusIcon = Symbols.call_made;
        break;
      case CallStatus.incoming:
        statusText = 'Входящий';
        statusIcon = Symbols.call_received;
        break;
    }

    final String displayName = call.count > 1
        ? '${call.name} (${call.count})'
        : call.name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: call.isGroup ? cs.primaryContainer : null,
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: call.isGroup
                    ? Icon(
                        Symbols.groups,
                        color: cs.onPrimaryContainer,
                        size: 26,
                      )
                    : KometAvatar(
                        name: call.name,
                        imageUrl: call.avatarUrl,
                        size: 48,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: isMissed ? cs.error : cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(call.time),
                style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Builder(
                builder: (btnContext) => IconButton(
                  icon: Icon(
                    Symbols.more_vert,
                    color: cs.onSurfaceVariant,
                    size: 20,
                    weight: 400,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () => _showCallMenu(btnContext, call),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCallMenu(BuildContext anchorContext, CallLogEntry call) {
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final anchorRect = box.localToGlobal(Offset.zero) & box.size;
    showChatMenu(
      context: context,
      anchorRect: anchorRect,
      items: [
        ChatMenuItem(
          icon: Symbols.delete,
          label: 'Удалить',
          destructive: true,
          onTap: () => _deleteCall(call),
        ),
        if (!call.isGroup)
          ChatMenuItem(
            icon: Symbols.call,
            label: 'Перезвонить',
            onTap: () => _callBack(call),
          ),
      ],
    );
  }

  void _deleteCall(CallLogEntry call) {
    if (_removing.contains(call.id)) return;
    setState(() => _removing.add(call.id));
    final historyId = int.tryParse(call.id);
    if (historyId != null) {
      unawaited(CallsModule(api).deleteHistory([historyId]));
    }
  }

  void _onRemovalComplete(String id) {
    if (!mounted) return;
    setState(() {
      _calls.removeWhere((c) => c.id == id);
      _removing.remove(id);
    });
  }

  Future<void> _callBack(CallLogEntry call) async {
    if (call.peerId <= 0) {
      showCustomNotification(context, 'Не удалось определить собеседника');
      return;
    }
    final navigator = Navigator.of(context);
    final avatarUrl = (call.avatarUrl?.isNotEmpty ?? false)
        ? call.avatarUrl
        : null;
    final active = CallController.instance.activeSession;
    if (active != null) {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            name: call.name,
            avatarUrl: avatarUrl,
            session: active,
          ),
        ),
      );
      return;
    }
    try {
      final session = await CallController.instance.startOutgoing(call.peerId);
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            name: call.name,
            avatarUrl: avatarUrl,
            session: session,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showCustomNotification(context, 'Не удалось начать звонок');
    }
  }

  Widget _buildTabItem(String label, int index, ColorScheme cs) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? cs.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? cs.primary : cs.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final filteredCalls = _selectedTabIndex == 1
        ? _calls.where((c) => c.status == CallStatus.missed).toList()
        : _calls;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Звонки',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const ConnectionStatusLine(),
                ],
              ),
            ),
            InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Symbols.link, color: cs.primary, size: 24),
                    const SizedBox(width: 16),
                    Text(
                      'Создать групповой звонок',
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  _buildTabItem('Все', 0, cs),
                  const SizedBox(width: 8),
                  _buildTabItem('Пропущенные', 1, cs),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: SmallSpinner(size: 36))
                  : filteredCalls.isEmpty
                  ? Center(
                      child: Text(
                        'Нет звонков',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: filteredCalls.length,
                      itemBuilder: (context, index) {
                        final call = filteredCalls[index];
                        return _RemovableCallEntry(
                          key: ValueKey(call.id),
                          removing: _removing.contains(call.id),
                          onDismissed: () => _onRemovalComplete(call.id),
                          child: _buildCallItem(context, cs, call),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemovableCallEntry extends StatefulWidget {
  final bool removing;
  final VoidCallback onDismissed;
  final Widget child;

  const _RemovableCallEntry({
    required Key key,
    required this.removing,
    required this.onDismissed,
    required this.child,
  }) : super(key: key);

  @override
  State<_RemovableCallEntry> createState() => _RemovableCallEntryState();
}

class _RemovableCallEntryState extends State<_RemovableCallEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1.0,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) widget.onDismissed();
  }

  @override
  void didUpdateWidget(covariant _RemovableCallEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.removing && !oldWidget.removing) _controller.reverse();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: _animation, child: widget.child),
    );
  }
}

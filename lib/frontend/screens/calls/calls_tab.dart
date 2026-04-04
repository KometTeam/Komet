import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart' show api;
import '../../../core/storage/app_database.dart';
import '../../../backend/modules/calls.dart';

class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  List<CallLogEntry> _calls = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0 for 'Все', 1 for 'Пропущенные'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final p = await AppDatabase.loadActiveProfile();
    if (p == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final callsModule = CallsModule(api);
    final calls = await callsModule.fetchHistory(p.id, p.id);

    print('DEBUG UI: Received ${calls.length} calls');
    for (final call in calls.take(3)) {
      print('DEBUG UI: Call name="${call.name}", peerId=${call.peerId}');
    }

    // Группируем подряд идущие звонки одному и тому же абоненту в один день с одним и тем же статусом
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
    final months = [
      'янв.',
      'фев.',
      'мар.',
      'апр.',
      'мая',
      'июн.',
      'июл.',
      'авг.',
      'сен.',
      'окт.',
      'ноя.',
      'дек.',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  Widget _buildPlaceholderAvatar(ColorScheme cs, String name) {
    return Container(
      color: cs.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
        onTap: () {
          // Open call details or initiate call
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: call.avatarUrl != null && call.avatarUrl!.isNotEmpty
                      ? Image.network(
                          call.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, ___) =>
                              _buildPlaceholderAvatar(cs, call.name),
                        )
                      : _buildPlaceholderAvatar(cs, call.name),
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
            ],
          ),
        ),
      ),
    );
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
              child: Text(
                'Звонки',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Outfit',
                ),
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
                  ? const Center(child: CircularProgressIndicator())
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
                        return _buildCallItem(
                          context,
                          cs,
                          filteredCalls[index],
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

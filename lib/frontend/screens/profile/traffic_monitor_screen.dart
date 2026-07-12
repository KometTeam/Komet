import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/transport/traffic_monitor.dart';
import '../../../core/utils/format.dart';
import '../../widgets/custom_notification.dart';

class TrafficMonitorScreen extends StatefulWidget {
  const TrafficMonitorScreen({super.key});

  @override
  State<TrafficMonitorScreen> createState() => _TrafficMonitorScreenState();
}

class _TrafficMonitorScreenState extends State<TrafficMonitorScreen> {
  final _monitor = TrafficMonitor.instance;
  final _scrollController = ScrollController();
  final Set<TrafficEntry> _expanded = Set.identity();
  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    _stickToBottom = pos.pixels >= pos.maxScrollExtent - 80;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.userScrollDirection != ScrollDirection.idle) return;
    if (pos.pixels >= pos.maxScrollExtent) return;
    _scrollController.jumpTo(pos.maxScrollExtent);
  }

  void _clear() {
    _expanded.clear();
    _monitor.clear();
  }

  Future<void> _share() async {
    if (_monitor.entries.isEmpty) return;
    final box = context.findRenderObject() as RenderBox?;
    try {
      final json = _monitor.buildExport();
      final dir = await getTemporaryDirectory();
      final stamp = formatFileStamp(DateTime.now());
      final file = File('${dir.path}/komet_traffic_$stamp.json');
      await file.writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Komet traffic capture',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось поделиться: $e');
      }
    }
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
            _topBar(cs),
            _controlBar(cs),
            Expanded(
              child: AnimatedBuilder(
                animation: _monitor,
                builder: (context, _) {
                  final entries = _monitor.entries;
                  if (_stickToBottom && _expanded.isEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom(),
                    );
                  }
                  if (entries.isEmpty) return _emptyState(cs);
                  return ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      return _TrafficRow(
                        key: ValueKey(entry),
                        entry: entry,
                        expanded: _expanded.contains(entry),
                        onToggle: () => setState(() {
                          if (!_expanded.remove(entry)) _expanded.add(entry);
                        }),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(ColorScheme cs) {
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
          Expanded(
            child: Text(
              'Монитор трафика',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _monitor,
            builder: (context, _) {
              final empty = _monitor.entries.isEmpty;
              final activeColor = empty
                  ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                  : cs.onSurface;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Поделиться (без чувствительных данных)',
                    icon: Icon(
                      Symbols.ios_share,
                      color: activeColor,
                      size: 22,
                      weight: 400,
                    ),
                    onPressed: empty ? null : _share,
                  ),
                  IconButton(
                    tooltip: 'Очистить',
                    icon: Icon(
                      Symbols.delete_sweep,
                      color: activeColor,
                      size: 24,
                      weight: 400,
                    ),
                    onPressed: empty ? null : _clear,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _controlBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: _monitor,
        builder: (context, _) {
          final on = _monitor.enabled;
          final endpoint = _monitor.activeEndpoint;
          return Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? kOnlineGreen : cs.outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      endpoint ?? 'Нет соединения',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      on
                          ? 'Захват включён · ${_monitor.entries.length}'
                          : 'Захват остановлен · ${_monitor.entries.length}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: on, onChanged: (v) => _monitor.setEnabled(v)),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.cell_tower, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            _monitor.enabled ? 'Ожидание трафика…' : 'Захват выключен',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _TrafficRow extends StatelessWidget {
  final TrafficEntry entry;
  final bool expanded;
  final VoidCallback onToggle;

  const _TrafficRow({
    super.key,
    required this.entry,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = entry;
    final accent = _accentColor(cs, e.direction);
    final hasPayload = e.payload != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasPayload ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatTime(e.time),
                      style: TextStyle(
                        color: cs.outline,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(_directionIcon(e.direction), color: accent, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if (e.byteSize != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        formatBytes(e.byteSize!),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    if (hasPayload)
                      Icon(
                        expanded ? Symbols.expand_less : Symbols.expand_more,
                        color: cs.onSurfaceVariant,
                        size: 18,
                      ),
                  ],
                ),
                if (_meta(e).isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(left: 49),
                    child: Text(
                      _meta(e),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                if (expanded && hasPayload) ...[
                  const SizedBox(height: 8),
                  _payloadBox(context, cs, e),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _meta(TrafficEntry e) {
    if (e.detail != null) return e.detail!;
    final parts = <String>[];
    if (e.opcode != null) parts.add('op ${e.opcode}');
    if (e.seq != null) parts.add('seq ${e.seq}');
    if (e.cmd != null) parts.add(_cmdLabel(e.cmd!, e.direction));
    return parts.join('  ·  ');
  }

  Widget _payloadBox(BuildContext context, ColorScheme cs, TrafficEntry e) {
    final text = e.prettyPayload;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Скопировать',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Symbols.content_copy,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                showCustomNotification(context, 'Payload скопирован');
              }
            },
          ),
        ],
      ),
    );
  }

  Color _accentColor(ColorScheme cs, TrafficDirection d) {
    switch (d) {
      case TrafficDirection.outgoing:
        return cs.primary;
      case TrafficDirection.incoming:
        return cs.tertiary;
      case TrafficDirection.event:
        return cs.onSurfaceVariant;
    }
  }

  IconData _directionIcon(TrafficDirection d) {
    switch (d) {
      case TrafficDirection.outgoing:
        return Symbols.north_east;
      case TrafficDirection.incoming:
        return Symbols.south_west;
      case TrafficDirection.event:
        return Symbols.lan;
    }
  }

  String _cmdLabel(int cmd, TrafficDirection direction) {
    switch (cmd) {
      case CmdType.ok:
        return 'OK';
      case CmdType.notFound:
        return 'NOT_FOUND';
      case CmdType.error:
        return 'ERROR';
      default:
        return direction == TrafficDirection.incoming ? 'PUSH' : 'REQ';
    }
  }

  String _formatTime(DateTime t) {
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '${pad2(t.hour)}:${pad2(t.minute)}:${pad2(t.second)}.$ms';
  }
}

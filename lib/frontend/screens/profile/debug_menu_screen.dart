import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../backend/modules/chats.dart';
import '../../../core/calls/call_controller.dart';
import '../../../core/config/app_media_cache.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/media_cache.dart';
import '../../../main.dart';
import '../../debug/cache_section.dart';
import '../../debug/feature_toggles_section.dart';
import '../../debug/header_section.dart';
import '../../debug/id_search_section.dart';
import '../../debug/log_export.dart';
import '../../debug/network_section.dart';
import '../../debug/previews_section.dart';
import '../../debug/quick_actions_section.dart';
import '../../debug/sync_probe_section.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/sheet_helpers.dart';

class DebugMenuScreen extends StatefulWidget {
  const DebugMenuScreen({super.key});

  @override
  State<DebugMenuScreen> createState() => _DebugMenuScreenState();
}

class _DebugMenuScreenState extends State<DebugMenuScreen> {
  final _idController = TextEditingController();
  bool _isSearching = false;
  bool _hasSearched = false;
  final List<SearchHit> _hits = [];
  final Map<String, String> _errors = {};
  int _cacheSize = 0;
  bool _clearingCache = false;
  bool _micSignalOn = true;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _sendMicSignal(bool enabled) async {
    setState(() => _micSignalOn = enabled);
    final sent = await CallController.instance.sendMicSignal(enabled);
    if (!mounted) return;
    showCustomNotification(
      context,
      sent
          ? 'Сигнал микрофона: ${enabled ? 'ВКЛ' : 'ВЫКЛ'} отправлен'
          : 'Нет активного звонка',
    );
  }

  Future<void> _loadCacheSize() async {
    final size = await MediaCache.currentSize();
    if (mounted) setState(() => _cacheSize = size);
  }

  Future<void> _clearCache() async {
    if (_clearingCache) return;
    setState(() => _clearingCache = true);
    final freed = await MediaCache.clear();
    if (!mounted) return;
    setState(() {
      _clearingCache = false;
      _cacheSize = 0;
    });
    showCustomNotification(context, 'Кэш очищен (${formatBytes(freed)})');
  }

  void _pickCacheLimit() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Лимит кэша медиа',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final preset in AppMediaCacheLimit.presets)
              ListTile(
                title: Text(
                  _limitLabel(preset),
                  style: TextStyle(color: cs.onSurface, fontSize: 16),
                ),
                trailing: AppMediaCacheLimit.current.value == preset
                    ? Icon(Symbols.check, color: cs.primary)
                    : null,
                onTap: () {
                  AppMediaCacheLimit.save(preset);
                  Navigator.pop(sheetContext);
                  setState(() {});
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _limitLabel(int bytes) =>
      bytes <= 0 ? 'Без лимита' : formatBytes(bytes);

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final id = int.tryParse(_idController.text);
    if (id == null) return;
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _hits.clear();
      _errors.clear();
    });

    Future<void> tryProbe(
      String label,
      Future<dynamic> Function() probe,
    ) async {
      try {
        final res = await probe();
        logger.i('debug-search $label($id): $res');
        if (res is Map) _extractHits(label, res);
      } on PacketError catch (e) {
        _errors[label] = e.message;
      } catch (e) {
        _errors[label] = e.toString();
      }
    }

    await Future.wait([
      tryProbe('contactInfo', () async {
        final p = await api.sendRequest(Opcode.contactInfo, {
          'contactIds': [id],
        });
        return p.payload;
      }),
      tryProbe('chatInfo', () async {
        final p = await api.sendRequest(Opcode.chatInfo, {
          'chatIds': [id],
        });
        return p.payload;
      }),
      tryProbe('publicSearch', () => chats.searchById(api, id)),
    ]);

    if (!mounted) return;
    setState(() => _isSearching = false);
  }

  void _extractHits(String source, Map raw) {
    final contacts = raw['contacts'];
    if (contacts is List) {
      for (final c in contacts) {
        if (c is Map) {
          final hit = SearchHit.fromContact(source, c);
          if (hit != null) _hits.add(hit);
        }
      }
    }
    final chats = raw['chats'];
    if (chats is List) {
      for (final c in chats) {
        if (c is Map) {
          final hit = SearchHit.fromChat(source, c);
          if (hit != null) _hits.add(hit);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appState = KometApp.stateOf(context);

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const ConnectionSpinner(),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: DebugHeaderSection(),
              ),
            ),
            SliverToBoxAdapter(
              child: DebugQuickActionsSection(
                onExportLog: () => exportDebugLog(context),
              ),
            ),
            SliverToBoxAdapter(child: DebugNetworkSection(appState: appState)),
            const SliverToBoxAdapter(child: DebugFeatureTogglesSection()),
            SliverToBoxAdapter(
              child: DebugCacheSection(
                cacheSize: _cacheSize,
                clearingCache: _clearingCache,
                cacheLimitLabel: _limitLabel(AppMediaCacheLimit.current.value),
                onPickCacheLimit: _pickCacheLimit,
                onClearCache: _clearCache,
              ),
            ),
            SliverToBoxAdapter(
              child: DebugPreviewsSection(
                micSignalOn: _micSignalOn,
                onMicSignalChanged: _sendMicSignal,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: DebugIdSearchSection(
                  idController: _idController,
                  isSearching: _isSearching,
                  hasSearched: _hasSearched,
                  hits: _hits,
                  errors: _errors,
                  onSearch: _search,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: DebugSyncProbeSection(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

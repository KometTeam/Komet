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
import '../../debug/info_section.dart';
import '../../debug/load_simulation_section.dart';
import '../../debug/log_export.dart';
import '../../debug/lottie_polygon_section.dart';
import '../../debug/network_section.dart';
import '../../debug/performance_monitor_section.dart';
import '../../debug/previews_section.dart';
import '../../debug/quick_actions_section.dart';
import '../../debug/server_section.dart';
import '../../debug/sync_probe_section.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/sheet_helpers.dart';
import '../chats/profile_action_sheets.dart';

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
  final DebugServerController _server = DebugServerController();

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
    _server.load();
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
    _server.dispose();
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

  Future<void> _resetServer() async {
    final choice = await showBlurredConfirm(
      context,
      title: 'Сбросить сервер?',
      message:
          'Адрес, порт и доверие сертификату Минцифры вернутся к '
          'значениям по умолчанию, соединение переподнимется',
      confirmLabel: 'Сбросить',
      cancelLabel: 'Отмена',
      destructive: true,
    );
    if (!mounted || !choice.confirmed) return;
    final online = await _server.reset();
    if (mounted) reportServerReconnect(context, online);
  }

  Widget _tab(List<Widget> children) => ListView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.only(top: 12, bottom: 120),
    children: children,
  );

  Widget _padded(Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appState = KometApp.stateOf(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: cs.surface,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: const ConnectionSpinner(),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ListenableBuilder(
                listenable: _server,
                builder: (context, _) => DebugHeaderSection(
                  onReset: _server.busy || _server.isDefault
                      ? null
                      : _resetServer,
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.label,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: cs.primary, width: 3),
                  borderRadius: BorderRadius.circular(3),
                ),
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: const [
                  Tab(text: 'Общее'),
                  Tab(text: 'Рубильники'),
                  Tab(text: 'Инфо'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _tab([
                      DebugServerSection(controller: _server),
                      DebugNetworkSection(appState: appState),
                      DebugQuickActionsSection(
                        onExportLog: () => exportDebugLog(context),
                      ),
                      DebugCacheSection(
                        cacheSize: _cacheSize,
                        clearingCache: _clearingCache,
                        cacheLimitLabel: _limitLabel(
                          AppMediaCacheLimit.current.value,
                        ),
                        onPickCacheLimit: _pickCacheLimit,
                        onClearCache: _clearCache,
                      ),
                      DebugPreviewsSection(
                        micSignalOn: _micSignalOn,
                        onMicSignalChanged: _sendMicSignal,
                      ),
                      _padded(
                        DebugIdSearchSection(
                          idController: _idController,
                          isSearching: _isSearching,
                          hasSearched: _hasSearched,
                          hits: _hits,
                          errors: _errors,
                          onSearch: _search,
                        ),
                      ),
                      _padded(const DebugSyncProbeSection()),
                      _padded(const DebugLoadSimulationSection()),
                      _padded(const DebugPerformanceSection()),
                      const DebugLottiePolygonSection(),
                    ]),
                    _tab([DebugFeatureTogglesSection(appState: appState)]),
                    _tab([DebugInfoSection(server: _server)]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

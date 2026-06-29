import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../backend/modules/chats.dart';
import '../../../core/config/app_swipe_back_desktop.dart';
import '../../../core/config/app_pranks.dart';
import '../../../core/config/app_stories.dart';
import '../../../core/config/app_commands.dart';
import '../../../core/config/app_link_preview.dart';
import '../../../core/config/app_show_extra_info.dart';
import '../../../core/config/app_digital_id_mode.dart';
import '../../../core/config/app_media_cache.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/transport/traffic_monitor.dart';
import '../../../core/utils/debug_session_log.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/media_cache.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/login_success_screen.dart';
import '../calls/call_screen.dart';
import '../../../core/calls/call_controller.dart';
import '../../widgets/connection_status.dart';
import '../digital_id/digital_id_web_screen.dart';
import 'traffic_monitor_screen.dart';

class DebugMenuScreen extends StatefulWidget {
  const DebugMenuScreen({super.key});

  @override
  State<DebugMenuScreen> createState() => _DebugMenuScreenState();
}

class _DebugMenuScreenState extends State<DebugMenuScreen> {
  final _idController = TextEditingController();
  bool _isSearching = false;
  bool _hasSearched = false;
  final List<_SearchHit> _hits = [];
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

  Future<void> _exportDebugLog() async {
    final content = await DebugSessionLog.instance.buildExport(
      endpoint: TrafficMonitor.instance.activeEndpoint,
    );
    if (content == null) {
      if (mounted) showCustomNotification(context, 'Нет запросов для лога');
      return;
    }
    final bytes = Uint8List.fromList(utf8.encode(content));
    final fileName = 'komet_debug_${_fileStamp(DateTime.now())}.txt';
    final isMobile = Platform.isAndroid || Platform.isIOS;
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить отладочный лог',
        fileName: fileName,
        type: FileType.any,
        bytes: isMobile ? bytes : null,
      );
      if (path == null) return;
      if (!isMobile) {
        await File(path).writeAsBytes(bytes);
      }
      if (mounted) {
        showCustomNotification(context, 'Лог сохранён: $path');
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось сохранить лог: $e');
      }
    }
  }

  String _fileStamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
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
      tryProbe('publicSearch', () => ChatsModule.searchById(api, id)),
    ]);

    if (!mounted) return;
    setState(() => _isSearching = false);
  }

  void _extractHits(String source, Map raw) {
    final contacts = raw['contacts'];
    if (contacts is List) {
      for (final c in contacts) {
        if (c is Map) {
          final hit = _SearchHit.fromContact(source, c);
          if (hit != null) _hits.add(hit);
        }
      }
    }
    final chats = raw['chats'];
    if (chats is List) {
      for (final c in chats) {
        if (c is Map) {
          final hit = _SearchHit.fromChat(source, c);
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
            SliverToBoxAdapter(
              child: Padding(
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
                        'Для разработчиков',
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
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _exportDebugLog,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.bug_report,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Отладочный лог',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Все запросы за последние 3 захода в приложение',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Symbols.save_alt,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: appState == null
                    ? const SizedBox.shrink()
                    : ValueListenableBuilder<bool>(
                        valueListenable: appState.fpsOverlayEnabled,
                        builder: (context, fpsOn, _) {
                          return GlossyPill(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                            depth: 6,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 17,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Symbols.speed,
                                  color: cs.onSurfaceVariant,
                                  size: 22,
                                  weight: 400,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Оверлей FPS',
                                        style: TextStyle(
                                          color: cs.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Показ текущего фреймрейта поверх интерфейса',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: fpsOn,
                                  onChanged: (v) {
                                    appState.setFpsOverlayEnabled(v);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: appState == null
                    ? const SizedBox.shrink()
                    : ValueListenableBuilder<bool>(
                        valueListenable: appState.vpnBypassEnabled,
                        builder: (context, bypassOn, _) {
                          return GlossyPill(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                            depth: 6,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 17,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Symbols.vpn_key_off,
                                  color: cs.onSurfaceVariant,
                                  size: 22,
                                  weight: 400,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Обход VPN',
                                        style: TextStyle(
                                          color: cs.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Если обнаружен VPN (tun-интерфейс), '
                                        'подключаться напрямую через Wi-Fi или '
                                        'моб. сеть в обход туннеля. Только Android',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: bypassOn,
                                  onChanged: (v) {
                                    appState.setVpnBypassEnabled(v);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: debugForceOffline,
                  builder: (context, offline, _) {
                    return GlossyPill(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      depth: 6,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.wifi_off,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Офлайн (тест)',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Показать индикаторы соединения во всех '
                                  'экранах, не разрывая реальную сессию',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: offline,
                            onChanged: (v) => debugForceOffline.value = v,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: appState == null
                    ? const SizedBox.shrink()
                    : ValueListenableBuilder<bool>(
                        valueListenable: appState.tlsInsecureEnabled,
                        builder: (context, insecureOn, _) {
                          return GlossyPill(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                            depth: 6,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 17,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Symbols.gpp_bad,
                                  color: cs.onSurfaceVariant,
                                  size: 22,
                                  weight: 400,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Отключить проверку TLS',
                                        style: TextStyle(
                                          color: cs.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Принимать любой сертификат сервера. '
                                        'Только для отладки через MitM-прокси — '
                                        'соединение становится уязвимым к '
                                        'перехвату трафика',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: insecureOn,
                                  onChanged: (v) {
                                    appState.setTlsInsecureEnabled(v);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrafficMonitorScreen(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.lan,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Монитор трафика',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Реалтайм: домены, опкоды и payload внутри '
                                  'сокет-соединения',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Symbols.chevron_right,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: AppSwipeBackDesktop.current,
                  builder: (context, swipeOn, _) {
                    return GlossyPill(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      depth: 6,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.swipe_right,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Свайп-назад в десктоп-режиме',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Включает жест «провести от левого края, чтобы '
                                  'закрыть» внутри встроенной панели чата на '
                                  'десктопе — для тестирования курсором',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: swipeOn,
                            onChanged: (v) {
                              AppSwipeBackDesktop.save(v);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: AppPranks.current,
                  builder: (context, pranksOn, _) {
                    return GlossyPill(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      depth: 6,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.auto_awesome,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Приколь4ики',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: pranksOn,
                            onChanged: (v) {
                              AppPranks.save(v);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: AppDigitalIdNative.current,
                  builder: (context, native, _) {
                    return GlossyPill(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      depth: 6,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.badge,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Нативный Цифровой ID',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  native
                                      ? 'Нативный экран (REST ext-api.max.ru)'
                                      : 'Оригинальная страница в WebView',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: native,
                            onChanged: (v) {
                              AppDigitalIdNative.save(v);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      await resetDigitalIdWebData();
                      if (!context.mounted) return;
                      showCustomNotification(
                        context,
                        'Цифровой ID сброшен — Госуслуги спросят вход заново',
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.restart_alt,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Сбросить Цифровой ID',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Очистить куки и данные WebView',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: AppStories.current,
                  builder: (context, storiesOn, _) {
                    return GlossyPill(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      depth: 6,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.amp_stories,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Истории',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Отображение ленты историй в списке чатов',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: storiesOn,
                            onChanged: (v) {
                              AppStories.save(v);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: AppCommands.current,
                  builder: (context, commandsOn, _) {
                    return GlossyPill(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      depth: 6,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.terminal,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Команды',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Панель команд по вводу «/» в строке сообщения',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: commandsOn,
                            onChanged: (v) {
                              AppCommands.save(v);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: AppLinkPreview.current,
                  builder: (context, linkPreviewOn, _) {
                    return GlossyPill(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      depth: 6,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.link,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Предпросмотр ссылок',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Карточки с превью для ссылок в сообщениях',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: linkPreviewOn,
                            onChanged: (v) {
                              AppLinkPreview.save(v);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: AppShowExtraInfo.current,
                  builder: (context, extraInfoOn, _) {
                    return GlossyPill(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      depth: 6,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.info,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Доп. информация',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Раздел «Info» в настройках и вкладка с '
                                  'технической информацией в профиле собеседника',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: extraInfoOn,
                            onChanged: (v) {
                              AppShowExtraInfo.save(v);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _pickCacheLimit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.data_usage,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Лимит кэша медиа',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _limitLabel(AppMediaCacheLimit.current.value),
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Symbols.chevron_right,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _clearingCache ? null : _clearCache,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.delete_sweep,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Очистить кэш медиа',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _clearingCache
                                      ? 'Очистка…'
                                      : 'Занято: ${formatBytes(_cacheSize)}',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_clearingCache)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      final profile = await AppDatabase.loadActiveProfile();
                      if (!context.mounted) return;
                      final avatar = await precacheLoginAvatar(
                        context,
                        profile?.baseUrl,
                      );
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LoginSuccessScreen(preview: true, avatar: avatar),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.celebration,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'test hello',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Показать приветственную анимацию входа',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Symbols.chevron_right,
                            color: cs.onSurfaceVariant,
                            size: 22,
                            weight: 400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GlossyPill(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  depth: 6,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Экран звонка',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Превью экранов звонков',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DebugCallButton(
                        label: 'Экран звонка (превью)',
                        icon: Symbols.phone,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CallScreen(name: 'Кирил Г.'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Сигнал микрофона (тест)',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Шлёт change-media-settings в активный звонок, '
                                  'не меняя реальный микрофон',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _micSignalOn,
                            onChanged: _sendMicSignal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GlossyPill(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  depth: 6,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Поиск по ID',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Параллельно: contactInfo (32) + chatInfo (48) + publicSearch (60)',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _idController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Введите ID',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (_) => _search(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _isSearching ? null : _search,
                            child: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Symbols.search, size: 20),
                          ),
                        ],
                      ),
                      if (_hasSearched && !_isSearching) ...[
                        const SizedBox(height: 12),
                        if (_hits.isEmpty && _errors.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Ничего не найдено',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        for (final hit in _hits) ...[
                          _SearchResultCard(hit: hit),
                          const SizedBox(height: 8),
                        ],
                        for (final entry in _errors.entries) ...[
                          _ErrorChip(label: entry.key, message: entry.value),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SyncProbeCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _SyncProbeCard extends StatefulWidget {
  const _SyncProbeCard();

  @override
  State<_SyncProbeCard> createState() => _SyncProbeCardState();
}

class _SyncProbeCardState extends State<_SyncProbeCard> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _result;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    if (phone.isEmpty) {
      setState(() => _result = 'Введите номер');
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final packet = await api.sendRequest(Opcode.sync, {
        'contactList': {
          phone: {'firstName': name},
        },
      });
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = _pretty(packet.payload);
      });
    } on PacketError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = 'PacketError: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = 'Ошибка: $e';
      });
    }
  }

  String _pretty(dynamic payload) {
    const encoder = JsonEncoder.withIndent('  ');
    try {
      return encoder.convert(_jsonSafe(payload));
    } catch (_) {
      return payload.toString();
    }
  }

  dynamic _jsonSafe(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _jsonSafe(val)));
    }
    if (v is List) return v.map(_jsonSafe).toList();
    if (v is String || v is num || v is bool || v == null) return v;
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync contactList (21)',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Резолв контакта по номеру и имени, полный ответ сервера',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: '+6282233831826',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: 'Имя',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Отправить'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                _result!,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _HitKind { dialog, chat, channel, bot, official, contact, user, unknown }

class _SearchHit {
  final String source;
  final int id;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final List<_HitKind> badges;
  final bool isChatEntity;

  _SearchHit({
    required this.source,
    required this.id,
    required this.title,
    required this.avatarUrl,
    required this.badges,
    required this.isChatEntity,
    this.subtitle,
  });

  static _SearchHit? fromContact(String source, Map raw) {
    final id = raw['id'];
    if (id is! int) return null;
    final namesRaw = raw['names'];
    String title = 'User #$id';
    if (namesRaw is List && namesRaw.isNotEmpty) {
      final n = namesRaw.first;
      if (n is Map) {
        final full = n['name']?.toString();
        if (full != null && full.isNotEmpty) title = full;
      }
    }
    final opts = (raw['options'] is List)
        ? (raw['options'] as List).whereType<String>().toSet()
        : <String>{};
    final badges = <_HitKind>[];
    if (opts.contains('BOT')) badges.add(_HitKind.bot);
    if (opts.contains('OFFICIAL')) badges.add(_HitKind.official);
    if (badges.isEmpty) badges.add(_HitKind.contact);
    return _SearchHit(
      source: source,
      id: id,
      title: title,
      subtitle: (raw['description'] as String?)?.trim().isNotEmpty == true
          ? raw['description'] as String
          : (raw['phone'] != null ? 'Телефон скрыт' : null),
      avatarUrl: raw['baseUrl'] as String?,
      badges: badges,
      isChatEntity: false,
    );
  }

  static _SearchHit? fromChat(String source, Map raw) {
    final id = raw['id'];
    if (id is! int) return null;
    final type = (raw['type'] as String?) ?? 'CHAT';
    final title = (raw['title'] as String?) ?? 'Chat #$id';
    final pCount = raw['participantsCount'] as int?;
    final badges = <_HitKind>[];
    switch (type) {
      case 'DIALOG':
        badges.add(_HitKind.dialog);
      case 'CHANNEL':
        badges.add(_HitKind.channel);
      case 'CHAT':
        badges.add(_HitKind.chat);
      default:
        badges.add(_HitKind.unknown);
    }
    final opts = raw['options'];
    if (opts is Map && opts['OFFICIAL'] == true) {
      badges.add(_HitKind.official);
    }
    String? subtitle;
    if (type == 'CHANNEL') {
      subtitle = pCount != null ? 'Канал · $pCount подписч.' : 'Канал';
    } else if (type == 'CHAT') {
      subtitle = pCount != null ? 'Группа · $pCount участн.' : 'Группа';
    } else {
      subtitle = 'Диалог';
    }
    return _SearchHit(
      source: source,
      id: id,
      title: title,
      subtitle: subtitle,
      avatarUrl: raw['baseIconUrl'] as String?,
      badges: badges,
      isChatEntity: true,
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final _SearchHit hit;
  const _SearchResultCard({required this.hit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HitAvatar(hit: hit, cs: cs),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        hit.title,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final b in hit.badges) ...[
                      const SizedBox(width: 6),
                      _BadgeChip(kind: b, cs: cs),
                    ],
                  ],
                ),
                if (hit.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hit.subtitle!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'id: ${hit.id}',
                      style: TextStyle(
                        color: cs.outline,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'via ${hit.source}',
                      style: TextStyle(color: cs.outline, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Скопировать id',
            icon: Icon(
              Symbols.content_copy,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: hit.id.toString()));
              if (context.mounted) {
                showCustomNotification(context, 'id скопирован');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _HitAvatar extends StatelessWidget {
  final _SearchHit hit;
  final ColorScheme cs;
  const _HitAvatar({required this.hit, required this.cs});

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    final url = hit.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _fallback(),
          errorWidget: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial = hit.title.isNotEmpty ? hit.title[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final _HitKind kind;
  final ColorScheme cs;
  const _BadgeChip({required this.kind, required this.cs});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;
    switch (kind) {
      case _HitKind.bot:
        label = 'Bot';
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
      case _HitKind.official:
        label = '✓';
        bg = cs.primary;
        fg = cs.onPrimary;
      case _HitKind.contact:
        label = 'Контакт';
        bg = cs.surface;
        fg = cs.onSurfaceVariant;
      case _HitKind.user:
        label = 'User';
        bg = cs.surface;
        fg = cs.onSurfaceVariant;
      case _HitKind.dialog:
        label = 'Диалог';
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
      case _HitKind.chat:
        label = 'Группа';
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
      case _HitKind.channel:
        label = 'Канал';
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
      case _HitKind.unknown:
        label = '?';
        bg = cs.surface;
        fg = cs.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorChip extends StatelessWidget {
  final String label;
  final String message;
  const _ErrorChip({required this.label, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Symbols.error_outline, size: 16, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $message',
              style: TextStyle(color: cs.onErrorContainer, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugCallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DebugCallButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: cs.onSurfaceVariant, size: 22, fill: 1),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

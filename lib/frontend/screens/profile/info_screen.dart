import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/section_header.dart';
import '../../widgets/small_spinner.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _info;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final jsonStr = await AppDatabase.getLoginInfo(accountId);
      if (!mounted) return;
      if (jsonStr != null) {
        setState(() => _info = jsonDecode(jsonStr) as Map<String, dynamic>);
      }
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Error: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: ConnectionTitleText(
          l10n?.infoTitle ?? 'Info',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: SmallSpinner(size: 36))
          : _info == null
          ? Center(
              child: Text(
                'No data',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          : _buildContent(cs, l10n!),
    );
  }

  Widget _buildContent(ColorScheme cs, AppLocalizations l10n) {
    final info = _info!;
    final chats = _asStringMap(info['chats']);
    final server = _asStringMap(info['server']);
    final user = _asStringMap(info['user']);
    final experiments = _asStringMap(info['experiments']);
    final chatSettings = _asStringMap(info['chatSettings']);
    final yMap = _asStringMap(server?['y-map']);

    final accountKeys = <String, String>{
      'registrationTime': l10n.infoRegistrationTime,
      'country': l10n.infoCountry,
      'videoChatHistory': l10n.infoVideoChatHistory,
      'updateTime': l10n.infoUpdateTime,
      'id': l10n.infoId,
      'phone': l10n.infoPhone,
      'photoId': l10n.infoPhotoId,
      'accountStatus': l10n.infoAccountStatus,
      'contactOptions': l10n.infoContactOptions,
      'profileOptions': l10n.infoProfileOptions,
      'names': l10n.infoNames,
      'baseUrl': l10n.infoBaseUrl,
      'baseRawUrl': l10n.infoBaseRawUrl,
    };

    final packetKeys = <String, String>{
      'chatMarker': l10n.infoChatMarker,
      'time': l10n.infoServerTime,
      'updates': l10n.infoUpdates,
      'messagesCount': l10n.infoMessagesCount,
      'contactsCount': l10n.infoContactsCount,
      'presenceCount': l10n.infoPresenceCount,
      'configHash': l10n.infoConfigHash,
    };

    final chatKeys = <String, String>{
      'count': l10n.infoChatsCount,
      'active': l10n.infoChatsActive,
      'hidden': l10n.infoChatsHidden,
      'dialogs': l10n.infoChatsDialogs,
      'groups': l10n.infoChatsGroups,
      'channels': l10n.infoChatsChannels,
      'unread': l10n.infoChatsUnread,
      'newMessages': l10n.infoChatsNewMessages,
      'messages': l10n.infoChatsMessages,
    };

    final serverKeys = <String, String>{
      'account-removal-enabled': l10n.infoAccountRemovalEnabled,
      'image-size': l10n.infoImageSize,
      'gce': l10n.infoGce,
      'gcce': l10n.infoGcce,
      'max-msg-length': l10n.infoMaxMsgLength,
      'quotes-enabled': l10n.infoQuotesEnabled,
      'calls-endpoint': l10n.infoCallsEndpoint,
      'send-location-enabled': l10n.infoSendLocationEnabled,
      'lgce': l10n.infoLgce,
      'wud': l10n.infoWud,
      'video-msg-enabled': l10n.infoVideoMsgEnabled,
      'grse': l10n.infoGrse,
      'edit-timeout': l10n.infoEditTimeout,
      'image-quality': l10n.infoImageQuality,
      'unsafe-files-alert': l10n.infoUnsafeFilesAlert,
      'account-nickname-enabled': l10n.infoAccountNicknameEnabled,
      'mentions_entity_names_limit': l10n.infoMentionsEntityNamesLimit,
      'reactions-enabled': l10n.infoReactionsEnabled,
    };

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(l10n.infoAccountSection),
          ...accountKeys.entries.map(
            (entry) =>
                _buildDataRow(entry.key, entry.value, info[entry.key], cs),
          ),

          const SizedBox(height: 16),
          SectionHeader(l10n.infoPacketSection),
          ...packetKeys.entries.map(
            (entry) =>
                _buildDataRow(entry.key, entry.value, info[entry.key], cs),
          ),

          const SizedBox(height: 16),
          SectionHeader(l10n.infoChatsSection),
          ...chatKeys.entries.map(
            (entry) => _buildDataRow(
              'chats.${entry.key}',
              entry.value,
              chats?[entry.key],
              cs,
            ),
          ),

          const SizedBox(height: 16),
          SectionHeader(l10n.infoServerSection),
          ...serverKeys.entries.map(
            (entry) =>
                _buildDataRow(entry.key, entry.value, server?[entry.key], cs),
          ),
          ..._buildDynamicRows(
            server,
            cs,
            excludedKeys: {
              ...serverKeys.keys,
              'y-map',
              'file-upload-unsupported-types',
              'white-list-links',
            },
          ),

          const SizedBox(height: 8),
          SectionHeader(l10n.infoYMapSection),
          _buildDataRow('y-map.tile', l10n.infoTile, yMap?['tile'], cs),
          _buildDataRow(
            'y-map.geocoder',
            l10n.infoGeocoder,
            yMap?['geocoder'],
            cs,
          ),
          _buildDataRow('y-map.static', l10n.infoStatic, yMap?['static'], cs),

          const SizedBox(height: 8),
          SectionHeader(l10n.infoFileUploadTypes),
          _buildListValueRow(
            'file-upload-unsupported-types',
            l10n.infoFileUploadTypes,
            server?['file-upload-unsupported-types'] as List?,
            cs,
            showLabel: false,
          ),

          const SizedBox(height: 8),
          SectionHeader(l10n.infoWhiteListLinks),
          _buildListValueRow(
            'white-list-links',
            l10n.infoWhiteListLinks,
            server?['white-list-links'] as List?,
            cs,
            showLabel: false,
          ),

          if (chatSettings != null && chatSettings.isNotEmpty) ...[
            const SizedBox(height: 8),
            SectionHeader(l10n.infoChatSettingsSection),
            ..._buildDynamicRows(chatSettings, cs),
          ],

          if (experiments != null && experiments.isNotEmpty) ...[
            const SizedBox(height: 8),
            SectionHeader(l10n.infoExperimentsSection),
            ..._buildDynamicRows(experiments, cs),
          ],

          const SizedBox(height: 8),
          SectionHeader(l10n.infoUserSection),
          ..._buildDynamicRows(user, cs),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicRows(
    Map<String, dynamic>? values,
    ColorScheme cs, {
    Set<String> excludedKeys = const {},
  }) {
    if (values == null) return [];
    final entries = <MapEntry<String, dynamic>>[];
    for (final entry in values.entries) {
      if (excludedKeys.contains(entry.key) || entry.value == null) continue;
      _flattenEntry(entry.key, entry.value, entries);
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((entry) => _buildDataRow(entry.key, entry.key, entry.value, cs))
        .toList();
  }

  void _flattenEntry(
    String key,
    dynamic value,
    List<MapEntry<String, dynamic>> target,
  ) {
    final map = _asStringMap(value);
    if (map == null || map.isEmpty) {
      target.add(MapEntry(key, value));
      return;
    }
    for (final entry in map.entries) {
      _flattenEntry('$key.${entry.key}', entry.value, target);
    }
  }

  Widget _buildDataRow(
    String key,
    String label,
    dynamic value,
    ColorScheme cs,
  ) {
    if (value is List) {
      return _buildListValueRow(key, label, value, cs);
    }
    return _buildRow(key, label, _formatValue(value, key), cs);
  }

  Widget _buildRow(String key, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: GlossyPill(
        key: ValueKey('info-$key'),
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        depth: 6,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListValueRow(
    String key,
    String label,
    List? items,
    ColorScheme cs, {
    bool showLabel = true,
  }) {
    final values = items ?? const [];
    final simple = values.every(
      (item) => item == null || item is String || item is num || item is bool,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: GlossyPill(
        key: ValueKey('info-$key'),
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.all(16),
        depth: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLabel) ...[
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (values.isEmpty)
              Text('-', style: TextStyle(color: cs.onSurfaceVariant))
            else if (simple)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: values
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatValue(item, key),
                          style: TextStyle(fontSize: 13, color: cs.onSurface),
                        ),
                      ),
                    )
                    .toList(),
              )
            else
              Text(
                const JsonEncoder.withIndent('  ').convert(values),
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatValue(dynamic value, String key) {
    if (value == null) return '-';
    if (value is Map && value.containsKey('chatMarker')) {
      final ts = value['chatMarker'] as int?;
      return ts != null ? _formatTs(ts) : '-';
    }
    if (key == 'phone' && value is num && value > 0) return '+$value';
    if (value is int && value > 1000000000000) return _formatTs(value);
    if (key == 'edit-timeout' && value is int && value > 0) {
      final weeks = value ~/ 604800;
      final days = (value % 604800) ~/ 86400;
      if (weeks > 0) {
        return '$weeks нед ${days > 0 ? '$days дн' : ''}'.trim();
      }
      final h = value ~/ 3600;
      final m = (value % 3600) ~/ 60;
      if (h > 0) return '${h}h ${m}m';
      return '${m}m';
    }
    return value.toString();
  }

  String _formatTs(int ts) {
    if (ts < 1000000000000) return ts.toString();
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.year}-${pad2(dt.month)}-${pad2(dt.day)} '
        '${pad2(dt.hour)}:${pad2(dt.minute)}:${pad2(dt.second)}';
  }

  Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}

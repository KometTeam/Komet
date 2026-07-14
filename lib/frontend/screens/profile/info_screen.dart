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
    final server = info['server'] as Map<String, dynamic>?;
    final user = info['user'] as Map<String, dynamic>?;
    final yMap = server?['y-map'] as Map<String, dynamic>?;

    final accountKeys = <String, String>{
      'registrationTime': l10n.infoRegistrationTime,
      'country': l10n.infoCountry,
      'videoChatHistory': l10n.infoVideoChatHistory,
      'updateTime': l10n.infoUpdateTime,
      'id': l10n.infoId,
      'chatMarker': l10n.infoChatMarker,
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(l10n.infoAccountSection),
        ...accountKeys.entries.map(
          (e) =>
              _buildRow(e.key, e.value, _formatValue(info[e.key], e.key), cs),
        ),

        const SizedBox(height: 16),
        SectionHeader(l10n.infoServerSection),
        ...serverKeys.entries.map(
          (e) => _buildRow(
            e.key,
            e.value,
            _formatValue(server?[e.key], e.key),
            cs,
          ),
        ),

        const SizedBox(height: 8),
        SectionHeader(l10n.infoYMapSection),
        _buildRow('tile', l10n.infoTile, yMap?['tile']?.toString() ?? '-', cs),
        _buildRow(
          'geocoder',
          l10n.infoGeocoder,
          yMap?['geocoder']?.toString() ?? '-',
          cs,
        ),
        _buildRow(
          'static',
          l10n.infoStatic,
          yMap?['static']?.toString() ?? '-',
          cs,
        ),

        const SizedBox(height: 8),
        SectionHeader(l10n.infoFileUploadTypes),
        _buildListRow(server?['file-upload-unsupported-types'] as List?, cs),

        const SizedBox(height: 8),
        SectionHeader(l10n.infoWhiteListLinks),
        _buildListRow(server?['white-list-links'] as List?, cs),

        const SizedBox(height: 8),
        SectionHeader(l10n.infoUserSection),
        if (user != null)
          ...user.entries
              .where((e) => e.value != null)
              .map((e) => _buildRow(e.key, e.key, e.value.toString(), cs)),

        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildRow(String key, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: GlossyPill(
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

  Widget _buildListRow(List? items, ColorScheme cs) {
    if (items == null || items.isEmpty) {
      return GlossyPill(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        depth: 6,
        child: Text('-', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(16),
      depth: 6,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: items
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
                  item.toString(),
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _formatValue(dynamic value, String key) {
    if (value == null) return '-';
    if (value is Map && value.containsKey('chatMarker')) {
      final ts = value['chatMarker'] as int?;
      return ts != null ? _formatTs(ts) : '-';
    }
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
}

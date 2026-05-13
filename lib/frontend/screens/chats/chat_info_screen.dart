import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' as main;
import '../../widgets/custom_notification.dart';

class ChatInfoScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;

  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _chatData;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadChatData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadChatData() async {
    try {
      final packet = await main.api.sendRequest(Opcode.chatInfo, {
        'chatIds': [widget.chatId],
      });

      final payload = packet.payload as Map?;
      if (payload == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final errorField = payload['error'];
      if (errorField != null) {
        String errorMsg = 'Error';
        if (errorField is Map) {
          errorMsg = errorField['localizedMessage'] ?? errorField['message'] ?? errorField.toString();
        } else if (errorField is String) {
          errorMsg = errorField;
        }
        if (mounted) showCustomNotification(context, errorMsg);
        setState(() => _isLoading = false);
        return;
      }

      final chats = payload['chats'] as List?;
      if (chats != null && chats.isNotEmpty) {
        _chatData = Map<String, dynamic>.from(chats.first as Map);
      } else if (chats != null && chats.isEmpty) {
        if (mounted) showCustomNotification(context, 'No data found');
      }

      if (mounted) setState(() => _isLoading = false);
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
        title: Text(
          l10n?.chatInfoTitle ?? 'Info',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? _buildShimmer(cs)
          : _chatData == null
              ? Center(
                  child: Text(
                    'No data',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : _buildContent(cs, l10n),
    );
  }

  Widget _buildShimmer(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(
          10,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme cs, AppLocalizations? l10n) {
    final chat = _chatData!;
    final type = chat['type'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer,
            ),
            child: widget.imageUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(widget.imageUrl, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text(
                      widget.name.isNotEmpty
                          ? widget.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            widget.name,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 24),

        if (type == 'CHANNEL') ...[
          _buildSectionTitle('Channel', cs),
          _buildRow(
            l10n?.chatInfoSubscribers ?? 'subscribers:',
            (chat['participantsCount'] as int?)?.toString() ?? '-',
            cs,
          ),
          if ((chat['link'] as String?)?.isNotEmpty ?? false)
            _buildRow(
              l10n?.chatInfoLink ?? 'link:',
              chat['link'] as String,
              cs,
            ),
          _buildRow(
            l10n?.chatInfoOfficial ?? 'official:',
            (chat['options']?['OFFICIAL'] as bool?)?.toString() ?? '-',
            cs,
          ),
          _buildRow(
            l10n?.chatInfoComments ?? 'comments:',
            (chat['options']?['COMMENTS'] as bool?)?.toString() ?? '-',
            cs,
          ),
          _buildRow(
            l10n?.chatInfoAplus ?? 'approved by Roskomnadzor:',
            (chat['options']?['A_PLUS_CHANNEL'] as bool?)?.toString() ?? '-',
            cs,
          ),
          _buildRow(
            l10n?.chatInfoSignAdmin ?? 'admin signature:',
            (chat['options']?['SIGN_ADMIN'] as bool?)?.toString() ?? '-',
            cs,
          ),
          if ((chat['modified'] as int?) != null)
            _buildRow(
              l10n?.chatInfoLastChanged ?? 'last changed:',
              _formatTs(chat['modified'] as int),
              cs,
            ),
          if ((chat['created'] as int?) != null)
            _buildRow(
              l10n?.chatInfoCreated ?? 'created:',
              _formatTs(chat['created'] as int),
              cs,
            ),
        ],

        if (type == 'CHAT') ...[
          _buildSectionTitle('Chat', cs),
          _buildRow(
            l10n?.chatInfoMembers ?? 'members:',
            (chat['participantsCount'] as int?)?.toString() ?? '-',
            cs,
          ),
          if ((chat['hasBots'] as bool?) ?? false)
            _buildRow(
              l10n?.chatInfoHasBots ?? 'has bots:',
              'true',
              cs,
            ),
          if ((chat['blockedParticipantsCount'] as int?) != null &&
              chat['blockedParticipantsCount'] > 0)
            _buildRow(
              l10n?.chatInfoBlockedCount ?? 'blocked in group:',
              (chat['blockedParticipantsCount'] as int).toString(),
              cs,
            ),
          _buildRow(
            l10n?.chatInfoOfficialStatus ?? 'official status:',
            (chat['options']?['OFFICIAL'] as bool?)?.toString() ?? '-',
            cs,
          ),
          if ((chat['modified'] as int?) != null)
            _buildRow(
              l10n?.chatInfoLastChanged ?? 'last changed:',
              _formatTs(chat['modified'] as int),
              cs,
            ),
          if ((chat['joinTime'] as int?) != null && chat['joinTime'] != 1)
            _buildRow(
              l10n?.chatInfoJoined ?? 'joined:',
              _formatTs(chat['joinTime'] as int),
              cs,
            ),
          if ((chat['created'] as int?) != null)
            _buildRow(
              l10n?.chatInfoGroupCreated ?? 'group created:',
              _formatTs(chat['created'] as int),
              cs,
            ),
          if ((chat['owner'] as int?) != null)
            _buildRow(
              l10n?.chatInfoGroupOwner ?? 'group owner:',
              (chat['owner'] as int).toString(),
              cs,
            ),
        ],

        if (type == 'DIALOG') ...[
          if ((chat['created'] as int?) != null &&
              chat['created'] != 0 &&
              chat['created'] != 1)
            _buildRow(
              l10n?.chatInfoDialogStarted ?? 'dialog started:',
              _formatTs(chat['created'] as int),
              cs,
            ),
        ],

        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4, right: 4),
      child: Text(
        title,
        style: TextStyle(
          color: cs.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
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
    );
  }

  String _formatTs(int ts) {
    if (ts < 1000000000000) return ts.toString();
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
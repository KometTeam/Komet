import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/messages.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../models/attachment.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/schedule_time_picker.dart';
import '../../widgets/sheet_helpers.dart';

class ScheduledMessagesScreen extends StatefulWidget {
  final int chatId;
  final int accountId;
  final String chatName;

  const ScheduledMessagesScreen({
    super.key,
    required this.chatId,
    required this.accountId,
    required this.chatName,
  });

  @override
  State<ScheduledMessagesScreen> createState() =>
      _ScheduledMessagesScreenState();
}

class _ScheduledMessagesScreenState extends State<ScheduledMessagesScreen> {
  final List<CachedMessage> _messages = [];
  StreamSubscription<Packet>? _pushSub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _pushSub = api.pushStream
        .where(
          (p) =>
              p.opcode == Opcode.notifMsgDelayed &&
              p.payload is Map &&
              p.payload['chatId'] == widget.chatId,
        )
        .listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await messagesModule.fetchDelayedMessages(
      widget.accountId,
      widget.chatId,
    );
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(list);
      _loading = false;
    });
  }

  Future<DateTime?> _pickTime(DateTime initial) => showScheduleTimePicker(
    context,
    initial: initial,
    title: AppLocalizations.of(context)!.scheduledPickTimeTitle,
  );

  Future<void> _edit(CachedMessage msg) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: msg.text ?? '');
    var when = DateTime.fromMillisecondsSinceEpoch(
      msg.delayedTimeToFire ?? msg.time,
    );
    final cs = Theme.of(context).colorScheme;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.scheduledEditTitle,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 1,
                maxLines: 5,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: l10n.scheduledMessageTextHint,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final picked = await _pickTime(when);
                  if (picked != null) setSheet(() => when = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Symbols.schedule, size: 18, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          formatDateTimeWords(when),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Symbols.edit, size: 16, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(l10n.scheduledSave),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || !mounted) {
      controller.dispose();
      return;
    }

    final ok = await messagesModule.editScheduledMessage(
      widget.chatId,
      msg.id,
      text: controller.text.trim(),
      timeToFire: when.millisecondsSinceEpoch,
    );
    controller.dispose();
    if (!mounted) return;
    if (ok) {
      Haptics.send();
      _load();
    } else {
      showCustomNotification(context, l10n.scheduledEditFailed);
    }
  }

  Future<void> _delete(CachedMessage msg) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.scheduledDeleteConfirmTitle,
      message: l10n.scheduledDeleteConfirmMessage,
      confirmLabel: l10n.scheduledDeleteConfirmLabel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final ok = await messagesModule.deleteMessages(
      widget.chatId,
      [msg.id],
      forEveryone: true,
      itemType: 'DELAYED',
    );
    if (!mounted) return;
    if (ok) {
      Haptics.send();
      setState(() => _messages.removeWhere((m) => m.id == msg.id));
    } else {
      showCustomNotification(context, l10n.scheduledDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerHigh,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.scheduledAppBarTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
            Text(
              widget.chatName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
          ? _empty(cs)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _tile(cs, _messages[i]),
              ),
            ),
    );
  }

  Widget _empty(ColorScheme cs) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Symbols.schedule, size: 56, color: cs.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context)!.scheduledEmpty,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
        ),
      ],
    ),
  );

  (IconData, String)? _attachLabel(CachedMessage msg) {
    final attaches = msg.attachments;
    if (attaches == null || attaches.isEmpty) return null;
    final l10n = AppLocalizations.of(context)!;
    switch (attaches.first.type) {
      case AttachmentType.photo:
        return (Symbols.image, l10n.scheduledAttachPhoto);
      case AttachmentType.video:
        return (Symbols.videocam, l10n.scheduledAttachVideo);
      case AttachmentType.audio:
        return (Symbols.mic, l10n.scheduledAttachVoice);
      case AttachmentType.file:
        return (Symbols.description, l10n.scheduledAttachFile);
      case AttachmentType.location:
        return (Symbols.location_on, l10n.scheduledAttachLocation);
      case AttachmentType.forward:
        return (Symbols.forward, l10n.scheduledAttachForwarded);
      default:
        return (Symbols.attach_file, l10n.scheduledAttachGeneric);
    }
  }

  Widget _tile(ColorScheme cs, CachedMessage msg) {
    final fireMs = msg.delayedTimeToFire ?? msg.time;
    final fireAt = DateTime.fromMillisecondsSinceEpoch(fireMs);
    final hasText = (msg.text ?? '').isNotEmpty;
    final attach = _attachLabel(msg);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _edit(msg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (attach != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: hasText ? 4 : 0),
                      child: Row(
                        children: [
                          Icon(attach.$1, size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            attach.$2,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasText)
                    Text(
                      msg.text!,
                      style: TextStyle(color: cs.onSurface, fontSize: 15),
                    )
                  else if (attach == null)
                    Text(
                      AppLocalizations.of(context)!.scheduledAttachGeneric,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Symbols.schedule,
                        size: 14,
                        color: cs.primary,
                        weight: 500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatDateTimeWords(fireAt),
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Symbols.edit, color: cs.onSurfaceVariant, weight: 400),
              onPressed: () => _edit(msg),
            ),
            IconButton(
              icon: Icon(Symbols.delete, color: cs.error, weight: 400),
              onPressed: () => _delete(msg),
            ),
          ],
        ),
      ),
    );
  }
}

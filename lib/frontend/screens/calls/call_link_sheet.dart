import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/backend/modules/calls.dart';
import 'package:komet/frontend/screens/chats/chat_list_screen.dart';
import 'package:komet/frontend/screens/contacts/contact_sheet_common.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/small_spinner.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/main.dart' show messagesModule;

Future<bool> showCreatedCallSheet(
  BuildContext context, {
  required CreatedCall call,
}) async {
  final started = await showBlurredCard<bool>(
    context,
    (host) => _CreatedCallCard(call: call, hostContext: host),
  );
  return started ?? false;
}

class _CreatedCallCard extends StatefulWidget {
  final CreatedCall call;
  final BuildContext hostContext;

  const _CreatedCallCard({required this.call, required this.hostContext});

  @override
  State<_CreatedCallCard> createState() => _CreatedCallCardState();
}

class _CreatedCallCardState extends State<_CreatedCallCard> {
  bool _sending = false;

  Future<void> _copy() async {
    final message = AppLocalizations.of(context)!.sharedLinkCopied;
    await Clipboard.setData(ClipboardData(text: widget.call.url));
    if (!mounted) return;
    showCustomNotification(context, message);
  }

  Future<void> _sendInMax() async {
    if (_sending) return;
    final target = await openForwardScreen(context: context);
    if (target == null || !mounted) return;

    setState(() => _sending = true);
    final ok = await messagesModule.sendLinkMessage(
      target.chatId,
      widget.call.url,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    final l10n = AppLocalizations.of(context)!;
    showCustomNotification(
      context,
      ok ? l10n.callLinkSent : l10n.callLinkSendFailed,
    );
  }

  Widget _action(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: busy
                  ? SmallSpinner(size: 24, color: cs.primary)
                  : Icon(icon, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final title = widget.call.callName ?? l10n.callLinkGroupCall;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width > 420 ? 380 : double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primary,
                          Color.alphaBlend(
                            Colors.white.withValues(alpha: 0.25),
                            cs.primary,
                          ),
                        ],
                      ),
                    ),
                    child: Icon(
                      Symbols.call,
                      fill: 1,
                      color: cs.onPrimary,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.call.url,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.primary, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _action(
                          cs,
                          icon: Symbols.content_copy,
                          label: l10n.sharedCopyLink,
                          onTap: _copy,
                        ),
                        _action(
                          cs,
                          icon: Symbols.reply,
                          label: l10n.callLinkSendInMax,
                          onTap: _sendInMax,
                          busy: _sending,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n.callLinkStart,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

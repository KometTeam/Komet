import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/crypto/e2ee_service.dart';
import '../../l10n/app_localizations.dart';
import 'custom_notification.dart';

// #***! плашка над композером: собеседник предложил шифрование или сменил ключ
class E2eeBanner extends StatelessWidget {
  final int accountId;
  final int chatId;
  final String peerName;
  final VoidCallback onOpenDetails;

  const E2eeBanner({
    super.key,
    required this.accountId,
    required this.chatId,
    required this.peerName,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: E2eeService.instance.revision,
      builder: (context, _, _) {
        final info = E2eeService.instance.info(accountId, chatId);
        if (info == null || !info.needsAttention) {
          return const SizedBox.shrink();
        }
        final cs = Theme.of(context).colorScheme;
        final l10n = AppLocalizations.of(context)!;
        final keyChanged =
            info.phase == E2eePhase.keyChanged &&
            E2eeService.instance.offerChangesPeer(accountId, chatId);
        final rehandshake =
            info.phase == E2eePhase.keyChanged && !keyChanged;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
          decoration: BoxDecoration(
            color: keyChanged ? cs.errorContainer : cs.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    keyChanged ? Symbols.warning : Symbols.lock,
                    size: 20,
                    color: keyChanged
                        ? cs.onErrorContainer
                        : cs.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      keyChanged
                          ? l10n.e2eeBannerKeyChanged(peerName)
                          : rehandshake
                          ? l10n.e2eeBannerRehandshake(peerName)
                          : l10n.e2eeBannerPending(peerName),
                      style: TextStyle(
                        color: keyChanged
                            ? cs.onErrorContainer
                            : cs.onPrimaryContainer,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => E2eeService.instance.declineOffer(
                      accountId: accountId,
                      chatId: chatId,
                    ),
                    child: Text(l10n.e2eeDecline),
                  ),
                  if (keyChanged)
                    TextButton(
                      onPressed: onOpenDetails,
                      child: Text(l10n.e2eeFingerprint),
                    ),
                  FilledButton.tonal(
                    onPressed: () async {
                      final ok = await E2eeService.instance.acceptOffer(
                        accountId: accountId,
                        chatId: chatId,
                      );
                      if (!ok && context.mounted) {
                        showCustomNotification(context, l10n.e2eeAcceptFailed);
                      }
                    },
                    child: Text(l10n.e2eeAccept),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

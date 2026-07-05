import 'package:flutter/material.dart';

import '../../core/utils/update_checker.dart';
import '../../core/utils/update_installer.dart';
import '../../core/utils/link_opener.dart';
import '../../l10n/app_localizations.dart';
import 'custom_notification.dart';

Future<void> showUpdateDialog(
  BuildContext context,
  AppUpdateInfo info,
) async {
  final l10n = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final cs = Theme.of(dialogContext).colorScheme;
      final notes = info.notes;
      return AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        title: Text(
          l10n.updateAvailableTitle,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: cs.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.updateAvailableBody(info.version),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.updateWhatsNew,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Text(
                    notes,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(
            onPressed: () {
              UpdateChecker.skip(info.tag);
              Navigator.pop(dialogContext);
            },
            child: Text(
              l10n.updateSkip,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.updateLater,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _startUpdate(context, info);
            },
            child: Text(l10n.updateAction),
          ),
        ],
      );
    },
  );
}

Future<void> _startUpdate(BuildContext context, AppUpdateInfo info) async {
  if (!UpdateInstaller.isSupported) {
    await openExternalUrl(context, info.url);
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateProgressDialog(info: info),
  );
}

class _UpdateProgressDialog extends StatefulWidget {
  final AppUpdateInfo info;

  const _UpdateProgressDialog({required this.info});

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final result = await UpdateInstaller.downloadAndInstall(
      widget.info,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p.clamp(0.0, 1.0));
      },
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (!result.ok) {
      final l10n = AppLocalizations.of(context)!;
      showCustomNotification(context, l10n.updateDownloadFailed);
      await openExternalUrl(context, widget.info.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final percent = (_progress * 100).round();
    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.updateDownloading,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$percent%',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

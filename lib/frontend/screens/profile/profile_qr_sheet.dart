import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_shape.dart';
import '../../../core/links/profile_link.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/qr_code_view.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/small_spinner.dart';

const Color _cardColor = Color(0xFFFFFFFF);
const Color _moduleColor = Color(0xFF101418);

Future<void> showProfileQrSheet(
  BuildContext context, {
  required String name,
  String? avatarUrl,
}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => _ProfileQrSheet(name: name, avatarUrl: avatarUrl),
  );
}

class _ProfileQrSheet extends StatefulWidget {
  final String name;
  final String? avatarUrl;

  const _ProfileQrSheet({required this.name, this.avatarUrl});

  @override
  State<_ProfileQrSheet> createState() => _ProfileQrSheetState();
}

class _ProfileQrSheetState extends State<_ProfileQrSheet> {
  String? _link;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? link;
    try {
      link = await ownProfileLink();
    } catch (_) {
      link = null;
    }
    if (!mounted) return;
    setState(() {
      _link = link;
      _failed = link == null;
    });
  }

  Future<void> _copy() async {
    final link = _link;
    if (link == null) return;
    final message = AppLocalizations.of(context)!.sharedLinkCopied;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    showCustomNotification(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final qrSize = (width - 128).clamp(180.0, 260.0);
    final link = _link;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetGrabber()),
            Text(
              l10n.profileQrTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.profileQrHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: AppShape.cardRadius,
                ),
                child: SizedBox.square(
                  dimension: qrSize,
                  child: Center(child: _buildCode(cs, l10n, qrSize)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: link == null ? null : _copy,
              icon: const Icon(Icons.link, size: 20),
              label: Text(l10n.sharedCopyLink),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: AppShape.buttonBorder,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCode(ColorScheme cs, AppLocalizations l10n, double qrSize) {
    if (_failed) {
      return Text(
        l10n.profileQrUnavailable,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _moduleColor, fontSize: 14),
      );
    }
    final link = _link;
    if (link == null) return SmallSpinner(size: 28, color: cs.primary);
    return QrCodeView(
      data: link,
      size: qrSize,
      moduleColor: _moduleColor,
      center: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: _cardColor,
          shape: BoxShape.circle,
        ),
        child: KometAvatar(
          name: widget.name,
          imageUrl: widget.avatarUrl,
          size: qrSize * 0.24 - 8,
        ),
      ),
    );
  }
}

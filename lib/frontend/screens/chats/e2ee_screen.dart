import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_fonts.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/primary_loading_button.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';
import '../../../core/security/app_lock.dart';

class E2eeScreen extends StatefulWidget {
  final int accountId;
  final int chatId;
  final int peerId;
  final String peerName;

  const E2eeScreen({
    super.key,
    required this.accountId,
    required this.chatId,
    required this.peerId,
    required this.peerName,
  });

  @override
  State<E2eeScreen> createState() => _E2eeScreenState();
}

class _E2eeScreenState extends State<E2eeScreen> {
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  String? _fingerprint;
  bool _loading = true;

  E2eeService get _service => E2eeService.instance;

  E2eeSessionInfo? get _info => _service.info(widget.accountId, widget.chatId);

  E2eePhase get _phase => _info?.phase ?? E2eePhase.none;

  @override
  void initState() {
    super.initState();
    _service.revision.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    _service.revision.removeListener(_refresh);
    _busy.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await _service.ensureLoaded(widget.accountId);
    final fingerprint = await _service.fingerprint(
      widget.accountId,
      widget.chatId,
    );
    if (!mounted) return;
    setState(() {
      _fingerprint = fingerprint;
      _loading = false;
    });
  }

  Future<void> _run(Future<bool> Function() action, String failure) async {
    _busy.value = true;
    final ok = await action();
    if (!mounted) return;
    _busy.value = false;
    if (!ok) showCustomNotification(context, failure);
  }

  Future<void> _enable() => _run(
    () => _service.startOffer(
      accountId: widget.accountId,
      chatId: widget.chatId,
      peerId: widget.peerId,
    ),
    AppLocalizations.of(context)!.e2eeOfferFailed,
  );

  Future<void> _accept() => _run(
    () => _service.acceptOffer(
      accountId: widget.accountId,
      chatId: widget.chatId,
    ),
    AppLocalizations.of(context)!.e2eeAcceptFailed,
  );

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        content: Text(l10n.e2eeResetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.e2eeDecline),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.e2eeReset),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.resetSession(
      accountId: widget.accountId,
      chatId: widget.chatId,
    );
  }

  Future<void> _rotate() async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        content: Text(l10n.e2eeRotateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.e2eeDecline),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.e2eeRotateIdentity),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _busy.value = true;
    final ok = await _service.rotateIdentity(widget.accountId);
    if (!mounted) return;
    _busy.value = false;
    showCustomNotification(
      context,
      ok ? l10n.e2eeRotated : l10n.e2eeRotateFailed,
    );
  }

  Future<String?> _askPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        title: Text(l10n.e2eeTransferPassword),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          enableSuggestions: false,
          autocorrect: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.e2eeDecline),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    final password = await _askPassword();
    if (password == null || !mounted) return;
    _busy.value = true;
    final bytes = await _service.exportTransfer(widget.accountId, password);
    if (!mounted) return;
    _busy.value = false;
    if (bytes == null) {
      showCustomNotification(context, l10n.e2eeExportFailed);
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/komet-e2ee-${widget.accountId}.kct');
    await file.writeAsBytes(bytes, flush: true);
    await AppLock.instance.external(() => Share.shareXFiles([XFile(file.path)]));
    // #***! файл содержит ключ личности и все сессии, в кэше ему делать нечего
    try {
      await file.delete();
    } catch (_) {}
    if (!mounted) return;
    showCustomNotification(context, l10n.e2eeExportedAndDisabled);
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await AppLock.instance.external(() => FilePicker.platform.pickFiles(withData: true));
    final file = picked?.files.singleOrNull;
    if (file == null || !mounted) return;
    Uint8List? bytes = file.bytes;
    final path = file.path;
    if (bytes == null && path != null) bytes = await File(path).readAsBytes();
    if (bytes == null || !mounted) return;
    final password = await _askPassword();
    if (password == null || !mounted) return;
    _busy.value = true;
    final count = await _service.importTransfer(
      widget.accountId,
      bytes,
      password,
    );
    if (!mounted) return;
    _busy.value = false;
    showCustomNotification(
      context,
      count == null ? l10n.e2eeImportFailed : l10n.e2eeImported(count),
    );
  }

  String _statusText(AppLocalizations l10n) => switch (_phase) {
    E2eePhase.none => l10n.e2eeStatusNone,
    E2eePhase.offered => l10n.e2eeStatusOffered(widget.peerName),
    E2eePhase.pendingConsent => l10n.e2eeStatusPending(widget.peerName),
    E2eePhase.established => l10n.e2eeStatusEstablished,
    E2eePhase.keyChanged => l10n.e2eeStatusKeyChanged(widget.peerName),
  };

  IconData _statusIcon() => switch (_phase) {
    E2eePhase.none => Symbols.lock_open,
    E2eePhase.offered => Symbols.hourglass_top,
    E2eePhase.pendingConsent => Symbols.lock_clock,
    E2eePhase.established => Symbols.lock,
    E2eePhase.keyChanged => Symbols.warning,
  };

  Widget _fingerprintBlock(ColorScheme cs, AppLocalizations l10n) {
    final digits = _fingerprint;
    final rows = <Widget>[];
    if (digits != null) {
      for (var row = 0; row < 3; row++) {
        final groups = <String>[];
        for (var group = 0; group < 4; group++) {
          final start = (row * 4 + group) * 5;
          groups.add(digits.substring(start, start + 5));
        }
        rows.add(
          Text(
            groups.join('  '),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 1.5,
              height: 1.6,
            ),
          ),
        );
      }
    }
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.e2eeFingerprint,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (digits == null)
            Center(child: SmallSpinner(size: 24, color: cs.primary))
          else
            ...rows,
          const SizedBox(height: 12),
          Text(
            l10n.e2eeFingerprintHint(widget.peerName),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(AppLocalizations l10n) {
    switch (_phase) {
      case E2eePhase.none:
        return [
          PrimaryLoadingButton(
            loading: _busy,
            onPressed: widget.peerId == 0 ? null : _enable,
            child: Text(l10n.e2eeEnable),
          ),
        ];
      case E2eePhase.offered:
        return [
          OutlinedButton(
            onPressed: () => _service.resetSession(
              accountId: widget.accountId,
              chatId: widget.chatId,
            ),
            child: Text(l10n.e2eeCancelOffer),
          ),
        ];
      case E2eePhase.pendingConsent:
      case E2eePhase.keyChanged:
        return [
          PrimaryLoadingButton(
            loading: _busy,
            onPressed: _accept,
            child: Text(l10n.e2eeAccept),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _service.declineOffer(
              accountId: widget.accountId,
              chatId: widget.chatId,
            ),
            child: Text(l10n.e2eeDecline),
          ),
        ];
      case E2eePhase.established:
        return [
          OutlinedButton(onPressed: _reset, child: Text(l10n.e2eeReset)),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final info = _info;
    final showFingerprint =
        _phase == E2eePhase.established || _phase == E2eePhase.keyChanged;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurface, weight: 400),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.e2eeTitle,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: displayFontOf(context),
          ),
        ),
      ),
      body: _loading
          ? Center(child: SmallSpinner(size: 36, color: cs.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlossyPill(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(20),
                    depth: 6,
                    child: Row(
                      children: [
                        Icon(_statusIcon(), color: cs.primary, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _statusText(l10n),
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._actions(l10n),
                  if (showFingerprint) ...[
                    const SizedBox(height: 16),
                    _fingerprintBlock(cs, l10n),
                    const SizedBox(height: 16),
                    SettingsCard(
                      children: [
                        SettingsToggleTile(
                          icon: Symbols.verified_user,
                          label: l10n.e2eeVerified,
                          value: info?.verified ?? false,
                          onChanged: (value) => _service.setVerified(
                            accountId: widget.accountId,
                            chatId: widget.chatId,
                            verified: value,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    l10n.e2eeTransferTitle,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.e2eeTransferHint,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _export,
                          child: Text(l10n.e2eeExport),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _import,
                          child: Text(l10n.e2eeImport),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _rotate,
                    child: Text(l10n.e2eeRotateIdentity),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${l10n.e2eeCeiling}\n\n${l10n.e2eeNeedsKomet(widget.peerName)}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

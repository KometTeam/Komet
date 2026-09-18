import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_symbols_icons/symbols.dart';
import 'package:qr/qr.dart';

import '../../../core/push/push_link_service.dart';
import '../../../core/push/push_proxy_client.dart';
import '../../../core/storage/device_identity.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/link_opener.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';

enum _Stage { loading, idle, qr, password }

class PushLinkScreen extends StatefulWidget {
  const PushLinkScreen({super.key});

  @override
  State<PushLinkScreen> createState() => _PushLinkScreenState();
}

class _PushLinkScreenState extends State<PushLinkScreen> {
  final _passwordController = TextEditingController();

  _Stage _stage = _Stage.loading;
  bool _busy = false;
  bool _linked = false;
  PushLinkSession? _session;
  Timer? _pollTimer;
  String? _passwordHint;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _passwordController.dispose();
    final linkId = _session?.linkId;
    if (linkId != null) {
      PushLinkService.instance.cancel(linkId);
    }
    PushLinkService.instance.clear();
    super.dispose();
  }

  Future<void> _reload() async {
    final linked = await PushProxyClient.instance.isLinked();
    if (!mounted) return;
    setState(() {
      _linked = linked;
      _stage = _Stage.idle;
      _session = null;
      _passwordHint = null;
    });
    _pollTimer?.cancel();
  }

  Future<void> _startLink() async {
    final l10n = AppLocalizations.of(context)!;
    final apnsToken = PushProxyClient.instance.apnsToken;
    if (apnsToken == null || apnsToken.isEmpty) {
      showCustomNotification(context, l10n.pushLinkApnsMissing);
      return;
    }
    setState(() => _busy = true);
    try {
      final session = await PushLinkService.instance.start(
        apnsToken: apnsToken,
        voipToken: PushProxyClient.instance.voipToken ?? '',
        deviceId: await DeviceIdentity.deviceId(),
        isDev: kDebugMode,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _stage = _Stage.qr;
      });
      _schedulePolling(session.pollEvery);
    } catch (e) {
      if (mounted) showCustomNotification(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _schedulePolling(Duration interval) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _poll());
  }

  Future<void> _poll() async {
    final session = _session;
    if (session == null || _busy) return;
    try {
      final status = await PushLinkService.instance.status(session.linkId);
      if (!mounted) return;
      if (status.isPassword) {
        _pollTimer?.cancel();
        setState(() {
          _stage = _Stage.password;
          _passwordHint = status.hint;
        });
        return;
      }
      if (status.isDone) {
        _pollTimer?.cancel();
        await _finishLink();
      }
    } catch (e) {
      _pollTimer?.cancel();
      if (mounted) {
        setState(() => _stage = _Stage.idle);
        showCustomNotification(context, e.toString());
      }
    }
  }

  Future<void> _submitPassword() async {
    final session = _session;
    if (session == null || _busy) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.pushLinkPasswordInvalid,
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final status = await PushLinkService.instance.password(
        session.linkId,
        password,
      );
      if (status.isDone) {
        _pollTimer?.cancel();
        await _finishLink();
      } else if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.pushLinkPasswordWrong,
        );
      }
    } catch (e) {
      if (mounted) showCustomNotification(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishLink() async {
    PushProxyClient.instance.setLinked(true);
    unawaited(PushProxyClient.instance.verifyAndSync());
    Haptics.success();
    if (!mounted) return;
    showCustomNotification(
      context,
      AppLocalizations.of(context)!.pushLinkLinkedDone,
    );
    setState(() {
      _linked = true;
      _stage = _Stage.idle;
      _session = null;
      _passwordHint = null;
    });
  }

  Future<void> _unlink() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.pushLinkUnlink,
      message: l10n.pushLinkUnlinkConfirm,
      confirmLabel: l10n.pushLinkUnlink,
    );
    if (!confirmed) return;
    await PushProxyClient.instance.unregister();
    if (!mounted) return;
    showCustomNotification(
      context,
      AppLocalizations.of(context)!.pushLinkUnlinkedDone,
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.webPushTitle,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: switch (_stage) {
          _Stage.loading => const Center(child: SmallSpinner(size: 36)),
          _Stage.idle => _idleView(cs, l10n),
          _Stage.qr => _qrView(cs, l10n),
          _Stage.password => _passwordView(cs, l10n),
        },
      ),
    );
  }

  Widget _idleView(ColorScheme cs, AppLocalizations l10n) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_linked) ...[
                    Row(
                      children: [
                        Icon(Symbols.check_circle, color: cs.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.pushLinkLinked,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.pushLinkLinkedBody,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _busy ? null : _unlink,
                      child: Text(l10n.pushLinkUnlink),
                    ),
                  ] else ...[
                    Text(
                      l10n.pushLinkIntro,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _startLink,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: SmallSpinner(size: 18),
                            )
                          : const Icon(Symbols.qr_code_2),
                      label: Text(l10n.pushLinkConnect),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _qrView(ColorScheme cs, AppLocalizations l10n) {
    final session = _session;
    if (session == null) {
      return const Center(child: SmallSpinner(size: 36));
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    l10n.pushLinkScan,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: PushQrView(data: session.qrLink, size: 220),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: SmallSpinner(size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.pushLinkWaiting,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => openExternalUrl(context, session.qrLink),
                    icon: const Icon(Symbols.open_in_new),
                    label: Text(l10n.pushLinkOpenMax),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _passwordView(ColorScheme cs, AppLocalizations l10n) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.pushLinkPasswordBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_passwordHint != null && _passwordHint!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _passwordHint!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofocus: true,
                    onSubmitted: (_) => _submitPassword(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      suffixIcon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: SmallSpinner(size: 18),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            unawaited(_submitPassword());
                          },
                    icon: const Icon(Symbols.lock),
                    label: Text(l10n.pushLinkConfirm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PushQrView extends StatelessWidget {
  final String data;
  final double size;

  const PushQrView({super.key, required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    QrImage? image;
    try {
      final code = QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      );
      image = QrImage(code);
    } catch (_) {
      image = null;
    }

    if (image == null) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(child: SmallSpinner(size: 28)),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _QrPainter(image)),
    );
  }
}

class _QrPainter extends CustomPainter {
  final QrImage image;

  const _QrPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final modules = image.moduleCount;
    final cell = size.width / max(1, modules);
    final dark = Paint()..color = Colors.black;
    for (var row = 0; row < modules; row++) {
      for (var col = 0; col < modules; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(col * cell, row * cell, cell + 0.5, cell + 0.5),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.image != image;
}

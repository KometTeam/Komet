import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/contacts.dart';
import '../../../core/cache/info_cache.dart';
import '../../../core/nfc/nfc_exchange_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../models/contact_info.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/small_spinner.dart';

enum _Stage {
  checking,
  unsupported,
  disabled,
  failed,
  scanning,
  exchanging,
  found,
  adding,
  added,
}

class NfcExchangeSheet extends StatefulWidget {
  const NfcExchangeSheet({super.key});

  @override
  State<NfcExchangeSheet> createState() => _NfcExchangeSheetState();
}

class _NfcExchangeSheetState extends State<NfcExchangeSheet>
    with TickerProviderStateMixin {
  final _nfc = NfcExchangeService.instance;
  late final AnimationController _pulse;
  late final AnimationController _reveal;
  StreamSubscription<NfcEvent>? _sub;

  _Stage _stage = _Stage.checking;
  int? _peerId;
  int? _peerPhone;
  ContactInfo? _peerInfo;
  String _failReason = '';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _begin();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _nfc.stop();
    _pulse.dispose();
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    final status = await _nfc.status();
    if (!mounted) return;
    if (!status.supported) {
      setState(() => _stage = _Stage.unsupported);
      return;
    }
    if (!status.enabled) {
      setState(() => _stage = _Stage.disabled);
      return;
    }
    final profile = await AppDatabase.loadActiveProfile();
    if (!mounted) return;
    if (profile == null) {
      setState(() => _stage = _Stage.unsupported);
      return;
    }
    _sub = _nfc.events.listen(_onEvent);
    await _nfc.start(profile.id, profile.phone);
    if (mounted) setState(() => _stage = _Stage.scanning);
  }

  Future<void> _onEvent(NfcEvent event) async {
    if (event.type == NfcEventType.cancelled) {
      if (mounted && _stage == _Stage.scanning) {
        setState(() => _stage = _Stage.disabled);
      }
      return;
    }
    if (event.type == NfcEventType.error) {
      if (mounted && _peerId == null) {
        setState(() {
          _failReason = _reasonText(event.reason);
          _stage = _Stage.failed;
        });
      }
      return;
    }
    if (event.type == NfcEventType.exchanging) {
      if (mounted && _peerId == null && _stage == _Stage.scanning) {
        setState(() => _stage = _Stage.exchanging);
      }
      return;
    }
    final id = event.id;
    if (id == null || _peerId != null) return;
    _peerId = id;
    _peerPhone = (event.phone != null && event.phone! > 0) ? event.phone : null;
    HapticFeedback.mediumImpact();
    _reveal.forward(from: 0);
    setState(() => _stage = _Stage.found);
    final info = await ContactInfoFetch.get(id);
    if (!mounted) return;
    setState(() => _peerInfo = info);
  }

  String _peerName() {
    final l10n = AppLocalizations.of(context)!;
    return _peerInfo?.displayName ??
        l10n.nfcPeerNameFallback('${_peerId ?? ''}');
  }

  String _firstNameForAdd() {
    return _peerInfo?.firstName ??
        _peerInfo?.displayName ??
        AppLocalizations.of(context)!.nfcPeerFirstNameFallback;
  }

  Future<void> _add() async {
    final id = _peerId;
    if (id == null) return;
    setState(() => _stage = _Stage.adding);
    try {
      await ContactsModule.addContact(
        api,
        id,
        _firstNameForAdd(),
        phone: _peerPhone ?? 0,
      );
      if (!mounted) return;
      setState(() => _stage = _Stage.added);
      showCustomNotification(context, AppLocalizations.of(context)!.nfcContactAdded);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _stage = _Stage.found);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.nfcAddFailed(e.toString()),
      );
    }
  }

  String _reasonText(String? reason) {
    final l10n = AppLocalizations.of(context)!;
    switch (reason) {
      case 'bluetooth_off':
        return l10n.nfcReasonBluetoothOff;
      case 'permission':
        return l10n.nfcReasonPermission;
      default:
        return l10n.nfcReasonDefault;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: cs.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.nfcSheetTitle,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(
                      _stage == _Stage.found ? 'found' : _stage.name,
                    ),
                    child: _buildContent(cs),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    switch (_stage) {
      case _Stage.checking:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: SmallSpinner(size: 36),
        );
      case _Stage.unsupported:
        return _message(cs, Symbols.nfc, l10n.nfcUnsupported);
      case _Stage.disabled:
        return _message(cs, Symbols.nfc, l10n.nfcDisabled);
      case _Stage.failed:
        return _message(cs, Symbols.bluetooth_disabled, _failReason);
      case _Stage.scanning:
        return _scanning(cs);
      case _Stage.exchanging:
        return _exchanging(cs);
      case _Stage.found:
      case _Stage.adding:
      case _Stage.added:
        return _foundCard(cs);
    }
  }

  Widget _message(ColorScheme cs, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 44),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _scanning(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => CustomPaint(
                painter: _RadarPainter(_pulse.value, cs.primary),
                child: child,
              ),
              child: Center(
                child: Icon(Symbols.nfc, color: cs.primary, size: 48),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.nfcScanningTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.nfcScanningSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _exchanging(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => CustomPaint(
                painter: _RadarPainter(_pulse.value, cs.primary),
                child: child,
              ),
              child: Center(
                child: Icon(Symbols.sync, color: cs.primary, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            l10n.nfcExchangingTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.nfcExchangingSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _foundCard(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final loading = _peerInfo == null && _stage == _Stage.found;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, child) {
                final t = _reveal.value;
                final pop = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
                return CustomPaint(
                  painter: _BurstPainter(t, cs.primary),
                  child: Center(
                    child: Transform.scale(scale: pop, child: child),
                  ),
                );
              },
              child: KometAvatar(
                name: _peerName(),
                imageUrl: _peerInfo?.avatarUrl,
                size: 92,
                fontSize: 34,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _peerName(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            formatPhone(_peerPhone) ?? l10n.nfcPeerIdFallback('${_peerId ?? ''}'),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_stage == _Stage.adding || loading) ? null : _add,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _stage == _Stage.adding
                  ? const SmallSpinner(size: 20)
                  : Text(
                      _stage == _Stage.added
                          ? l10n.nfcAdded
                          : l10n.nfcAddContact,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final radius = maxRadius * t;
      final opacity = (1.0 - t) * 0.35;
      if (opacity <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
    final corePaint = Paint()
      ..color = color.withValues(
        alpha: 0.10 + 0.05 * math.sin(progress * 2 * math.pi),
      );
    canvas.drawCircle(center, maxRadius * 0.32, corePaint);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BurstPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final eased = Curves.easeOut.transform(progress.clamp(0.0, 1.0));

    final glow = Paint()..color = color.withValues(alpha: (1.0 - eased) * 0.18);
    canvas.drawCircle(center, maxRadius * (0.45 + 0.55 * eased), glow);

    for (var i = 0; i < 3; i++) {
      final delay = i * 0.18;
      final t = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final wave = Curves.easeOut.transform(t);
      final radius = maxRadius * (0.3 + 0.7 * wave);
      final opacity = (1.0 - wave) * 0.5;
      if (opacity <= 0) continue;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1.0 - wave) + 0.5
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, ring);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

import 'package:flutter/material.dart';
import 'package:m3e_collection/m3e_collection.dart'
    show ExpressiveRefreshIndicator;
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/digital_id.dart';
import '../../../backend/modules/webapp.dart';
import '../../../core/utils/webview_support.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show digitalIdModule;
import '../../../models/digital_id.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/error_view.dart';
import '../../widgets/small_spinner.dart';
import '../webapp/web_app_screen.dart';

String _documentLabel(AppLocalizations l10n, String type) {
  return switch (type) {
    'passport' => l10n.digitalIdDocPassport,
    'oms' => l10n.digitalIdDocOms,
    'inn' => l10n.digitalIdInnLabel,
    'driver_license' => l10n.digitalIdDocDriverLicense,
    'vehicle_sts' => l10n.digitalIdDocVehicleSts,
    'snils' => l10n.digitalIdSnilsLabel,
    'child_birth_cert' => l10n.digitalIdDocChildBirthCert,
    'pension_cert' => l10n.digitalIdDocPensionCert,
    'disabled_cert' => l10n.digitalIdDocDisabledCert,
    'large_family_cert' => l10n.digitalIdDocLargeFamilyCert,
    'student_ticket' => l10n.digitalIdDocStudentTicket,
    'child_inn' => l10n.digitalIdDocChildInn,
    'child_oms' => l10n.digitalIdDocChildOms,
    _ => type,
  };
}

class DigitalIdScreen extends StatefulWidget {
  const DigitalIdScreen({super.key});

  @override
  State<DigitalIdScreen> createState() => _DigitalIdScreenState();
}

class _DigitalIdScreenState extends State<DigitalIdScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _needsGosuslugi = false;
  DigitalIdUserDocs? _docs;
  DigitalIdBiometryStatus? _biometry;
  List<DigitalIdAcmsCard> _cards = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsGosuslugi = false;
    });
    try {
      final biometry = await digitalIdModule.biometryStatus();
      DigitalIdUserDocs? docs;
      try {
        docs = await digitalIdModule.loadDocuments();
      } on DigitalIdException catch (e) {
        if (e.isNoGosuslugiLink) {
          if (mounted) setState(() => _needsGosuslugi = true);
        } else {
          rethrow;
        }
      }
      final cards = await digitalIdModule.getCardsList(passStatus: 'active');
      if (!mounted) return;
      setState(() {
        _biometry = biometry;
        _docs = docs;
        _cards = cards;
        _loading = false;
      });
    } on DigitalIdException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _linkGosuslugi() async {
    if (_busy) return;
    if (!webViewSupported) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.digitalIdGosuslugiLinkUnavailable,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final link = await digitalIdModule.createEsiaLink();
      if (!mounted) return;
      if (link.url.isEmpty) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.digitalIdGosuslugiLinkFailed,
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebAppScreen(
            title: AppLocalizations.of(context)!.digitalIdGosuslugiTitle,
            loader: () async => WebAppLaunch(url: link.url),
          ),
        ),
      );
      if (!mounted) return;
      await _load();
    } on DigitalIdException catch (e) {
      if (mounted) showCustomNotification(context, e.message);
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.devicesGenericError(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadDocsExplicit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final docs = await digitalIdModule.loadDocuments(createIfMissing: true);
      if (!mounted) return;
      if (docs != null) {
        setState(() => _docs = docs);
      } else {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.digitalIdDocsUnavailable,
        );
      }
    } on DigitalIdException catch (e) {
      if (!mounted) return;
      if (e.isNoGosuslugiLink) setState(() => _needsGosuslugi = true);
      showCustomNotification(context, e.message);
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.devicesGenericError(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const ConnectionSpinner(),
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.digitalIdTitle),
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return const Center(child: SmallSpinner(size: 36));
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_docs == null) {
      return _buildOnboarding(cs);
    }
    return ExpressiveRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ..._buildProfile(cs, _docs!),
          if (_cards.isNotEmpty) ..._buildCards(cs),
          const SizedBox(height: 16),
          _buildBiometryInfo(cs),
        ],
      ),
    );
  }

  Widget _buildOnboarding(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.badge, size: 72, color: cs.primary),
                      const SizedBox(height: 20),
                      Text(
                        l10n.digitalIdNotConfiguredTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _needsGosuslugi
                            ? l10n.digitalIdLinkGosuslugiHint
                            : l10n.digitalIdLinkOrRefreshHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _loadDocsExplicit,
                    icon: const Icon(Symbols.sync, size: 18),
                    label: Text(
                      l10n.digitalIdLoadDocuments,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _linkGosuslugi,
                    icon: _busy
                        ? const SmallSpinner(size: 18)
                        : const Icon(Symbols.link, size: 18),
                    label: Text(
                      l10n.digitalIdLinkGosuslugiButton,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBiometryInfo(cs),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProfile(ColorScheme cs, DigitalIdUserDocs docs) {
    final l10n = AppLocalizations.of(context)!;
    final profile = docs.profile;
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Symbols.verified_user, size: 36, color: cs.onPrimaryContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName.isEmpty
                        ? l10n.digitalIdGosuslugiProfileFallback
                        : profile.fullName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  if (profile.birthDate != null)
                    Text(
                      l10n.digitalIdBirthDate(profile.birthDate!),
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildInfoSection(cs, l10n.digitalIdPersonalDataTitle, [
        if (profile.snils != null) (l10n.digitalIdSnilsLabel, profile.snils!),
        if (profile.inn != null) (l10n.digitalIdInnLabel, profile.inn!),
        if (profile.gender != null)
          (l10n.contactProfileInfoGender, profile.gender!),
        if (profile.birthPlace != null)
          (l10n.digitalIdBirthPlaceLabel, profile.birthPlace!),
        if (profile.registrationAddress != null)
          (
            l10n.digitalIdRegistrationAddressLabel,
            profile.registrationAddress!.formatted,
          ),
      ]),
      if (profile.documents.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          l10n.digitalIdDocumentsTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...profile.documents.map((doc) => _buildDocumentTile(cs, doc)),
      ],
    ];
  }

  Widget _buildInfoSection(
    ColorScheme cs,
    String title,
    List<(String, String)> rows,
  ) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      row.$1,
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(ColorScheme cs, DigitalIdDocument doc) {
    final l10n = AppLocalizations.of(context)!;
    final label = _documentLabel(l10n, doc.type);
    final subtitleParts = <String>[
      if (doc.series != null) l10n.digitalIdDocSeries(doc.series!),
      if (doc.number != null) l10n.digitalIdDocNumber(doc.number!),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Symbols.description, color: cs.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(', '),
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCards(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return [
      const SizedBox(height: 16),
      Text(
        l10n.digitalIdPassesTitle,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      ..._cards.map(
        (card) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Symbols.badge, color: cs.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.companyName,
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                    ),
                    Text(
                      l10n.digitalIdCardInn(card.inn),
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildBiometryInfo(ColorScheme cs) {
    final biometry = _biometry;
    if (biometry == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Icon(
          biometry.hasBiometryToken ? Symbols.check_circle : Symbols.info,
          size: 18,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            biometry.hasBiometryToken
                ? l10n.digitalIdBiometryConfigured
                : l10n.digitalIdBiometryNotConfigured,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

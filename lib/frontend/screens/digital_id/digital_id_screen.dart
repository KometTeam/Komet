import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/digital_id.dart';
import '../../../backend/modules/webapp.dart';
import '../../../core/utils/webview_support.dart';
import '../../../main.dart' show digitalIdModule;
import '../../../models/digital_id.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../webapp/web_app_screen.dart';

const Map<String, String> _documentLabels = {
  'passport': 'Паспорт РФ',
  'oms': 'Полис ОМС',
  'inn': 'ИНН',
  'driver_license': 'Водительское удостоверение',
  'vehicle_sts': 'СТС',
  'snils': 'СНИЛС',
  'child_birth_cert': 'Свидетельство о рождении',
  'pension_cert': 'Пенсионное удостоверение',
  'disabled_cert': 'Справка об инвалидности',
  'large_family_cert': 'Удостоверение многодетной семьи',
  'student_ticket': 'Студенческий билет',
  'child_inn': 'ИНН ребёнка',
  'child_oms': 'Полис ОМС ребёнка',
};

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
        'Привязка Госуслуг недоступна на этой платформе. Сделайте это в приложении на телефоне.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final link = await digitalIdModule.createEsiaLink();
      if (!mounted) return;
      if (link.url.isEmpty) {
        showCustomNotification(context, 'Не удалось получить ссылку Госуслуг');
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebAppScreen(
            title: 'Госуслуги',
            loader: () async => WebAppLaunch(url: link.url),
          ),
        ),
      );
      if (!mounted) return;
      await _load();
    } on DigitalIdException catch (e) {
      if (mounted) showCustomNotification(context, e.message);
    } catch (e) {
      if (mounted) showCustomNotification(context, 'Ошибка: $e');
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
          'Документы пока недоступны. Попробуйте позже.',
        );
      }
    } on DigitalIdException catch (e) {
      if (!mounted) return;
      if (e.isNoGosuslugiLink) setState(() => _needsGosuslugi = true);
      showCustomNotification(context, e.message);
    } catch (e) {
      if (mounted) showCustomNotification(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const ConnectionSpinner(),
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Цифровой ID'),
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    if (_docs == null) {
      return _buildOnboarding(cs);
    }
    return RefreshIndicator(
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
                        'Цифровой ID не настроен',
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
                            ? 'Привяжите аккаунт Госуслуг, чтобы документы появились в Цифровом ID. Номер телефона в MAX должен совпадать с номером в профиле Госуслуг.'
                            : 'Привяжите Госуслуги, чтобы получить доступ к документам, или обновите страницу, если уже настраивали Цифровой ID.',
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
                    label: const Text(
                      'Загрузить документы',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _linkGosuslugi,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Symbols.link, size: 18),
                    label: const Text(
                      'Привязать Госуслуги',
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
                    profile.fullName.isEmpty ? 'Профиль Госуслуг' : profile.fullName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  if (profile.birthDate != null)
                    Text(
                      'Дата рождения: ${profile.birthDate}',
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
      _buildInfoSection(cs, 'Личные данные', [
        if (profile.snils != null) ('СНИЛС', profile.snils!),
        if (profile.inn != null) ('ИНН', profile.inn!),
        if (profile.gender != null) ('Пол', profile.gender!),
        if (profile.birthPlace != null) ('Место рождения', profile.birthPlace!),
        if (profile.registrationAddress != null)
          ('Адрес регистрации', profile.registrationAddress!.formatted),
      ]),
      if (profile.documents.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          'Документы',
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
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        row.$1,
                        style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
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
              )),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(ColorScheme cs, DigitalIdDocument doc) {
    final label = _documentLabels[doc.type] ?? doc.type;
    final subtitleParts = <String>[
      if (doc.series != null) 'серия ${doc.series}',
      if (doc.number != null) '№ ${doc.number}',
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
    return [
      const SizedBox(height: 16),
      Text(
        'Пропуска',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      ..._cards.map((card) => Container(
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
                        'ИНН ${card.inn}',
                        style:
                            TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
    ];
  }

  Widget _buildBiometryInfo(ColorScheme cs) {
    final biometry = _biometry;
    if (biometry == null) return const SizedBox.shrink();
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
                ? 'Биометрия настроена на этом устройстве'
                : 'Биометрия на этом устройстве не настроена',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.cloud_off, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

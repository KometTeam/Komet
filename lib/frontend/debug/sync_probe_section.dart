import 'dart:convert';

import 'package:flutter/material.dart';

import '../../backend/modules/contacts.dart';
import '../../backend/modules/phonebook_sync.dart';
import '../../core/contacts/device_contacts_service.dart';
import '../../core/protocol/packet.dart';
import '../../core/utils/format.dart';
import '../../core/utils/names.dart';
import '../../main.dart';
import '../screens/contacts/open_contact_profile.dart';
import '../widgets/glossy_pill.dart';
import '../widgets/komet_avatar.dart';
import '../widgets/small_spinner.dart';
import '../widgets/verified_mark.dart';
import '../../core/config/app_shape.dart';

// #***! номер руками, но дальше всё как у записи из телефонной книги
class DebugSyncProbeSection extends StatefulWidget {
  const DebugSyncProbeSection({super.key});

  @override
  State<DebugSyncProbeSection> createState() => _DebugSyncProbeSectionState();
}

class _DebugSyncProbeSectionState extends State<DebugSyncProbeSection> {
  final _phoneController = TextEditingController();
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  bool _loading = false;
  String? _result;
  PhonebookSyncResult? _answer;

  @override
  void dispose() {
    _phoneController.dispose();
    _firstController.dispose();
    _lastController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final first = _firstController.text.trim();
    final last = _lastController.text.trim();
    final entry = DeviceContactsService.entryFor(
      number: _phoneController.text,
      first: first,
      last: last,
      displayName: [first, last].where((s) => s.isNotEmpty).join(' '),
    );
    if (entry == null) {
      setState(() {
        _answer = null;
        _result = 'Номер короче 7 цифр — из книги такой не уйдёт';
      });
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
      _answer = null;
    });
    final sent = '${entry.phone}: ${_pretty(entry.toWire())}';
    try {
      final answer = await accountModule.phonebook.sendManual(entry);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _answer = answer;
        _result = 'Ушло\n$sent\n\nОтвет\n${_pretty(answer.raw)}';
      });
    } on PacketError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = 'Ушло\n$sent\n\nPacketError: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = 'Ошибка: $e';
      });
    }
  }

  String _pretty(dynamic payload) {
    const encoder = JsonEncoder.withIndent('  ');
    try {
      return encoder.convert(_jsonSafe(payload));
    } catch (_) {
      return payload.toString();
    }
  }

  dynamic _jsonSafe(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _jsonSafe(val)));
    }
    if (v is List) return v.map(_jsonSafe).toList();
    if (v is String || v is num || v is bool || v == null) return v;
    return v.toString();
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_loading,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Номер из телефонной книги (SYNC 21)',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Уходит так же, как запись из книги: тот же номер и имя, '
            'найденный человек сохраняется в контакты',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _field(
            _phoneController,
            '+7 999 123-45-67',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          _field(_firstController, 'Имя'),
          const SizedBox(height: 10),
          _field(_lastController, 'Фамилия'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: AppShape.buttonBorder,
            ),
            child: _loading
                ? const SmallSpinner(size: 20)
                : const Text('Отправить'),
          ),
          if (_answer case final answer?) ...[
            const SizedBox(height: 12),
            Text(
              answer.contacts.isEmpty
                  ? 'Сервер никого не вернул'
                  : 'Сервер вернул: ${answer.contacts.length}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            for (final contact in answer.contacts)
              _FoundContactTile(key: ValueKey(contact.id), contact: contact),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                _result!,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// #***! кого сервер нашёл по номеру, тап открывает профиль
class _FoundContactTile extends StatelessWidget {
  const _FoundContactTile({super.key, required this.contact});

  final CachedContact contact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = displayName(
      contact.firstName,
      contact.lastName,
      fallback: 'id ${contact.id}',
    );
    final subtitle = [
      ?formatPhone(contact.phone),
      'id ${contact.id}',
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openContactDialogProfile(
        context,
        contactId: contact.id,
        name: name,
        avatarUrl: contact.baseUrl,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            KometAvatar(
              name: name,
              imageUrl: contact.baseUrl,
              size: 44,
              userId: contact.id,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (contact.isVerified) ...[
                        const SizedBox(width: 4),
                        VerifiedMark(color: cs.primary, size: 15),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

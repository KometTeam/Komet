import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/contacts.dart';
import '../../../backend/modules/messages.dart' show ContactCache;
import '../../../core/config/app_shape.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../models/contact_info.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/small_spinner.dart';

typedef FoundUser = ({int userId, int chatId, String name, String avatarUrl});

enum _FindMode { phone, id }

Future<FoundUser?> showFindUserSheet(
  BuildContext context, {
  required String title,
  required String actionLabel,
}) {
  return showModalBottomSheet<FoundUser>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => _FindUserSheet(title: title, actionLabel: actionLabel),
  );
}

class _FindUserSheet extends StatefulWidget {
  final String title;
  final String actionLabel;

  const _FindUserSheet({required this.title, required this.actionLabel});

  @override
  State<_FindUserSheet> createState() => _FindUserSheetState();
}

class _FindUserSheetState extends State<_FindUserSheet> {
  final _controller = TextEditingController();
  _FindMode _mode = _FindMode.phone;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setMode(_FindMode mode) {
    if (_mode == mode || _loading) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_mode == _FindMode.phone) {
      await _submitPhone();
    } else {
      await _submitId();
    }
  }

  String? _phoneCandidate(String query) {
    if (!RegExp(r'^[+\d\s\-()]+$').hasMatch(query)) return null;
    final digits = query.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 5) return null;
    return query;
  }

  Future<void> _submitPhone() async {
    final query = _phoneCandidate(_controller.text.trim());
    if (query == null) {
      setState(() => _error = 'Введите корректный номер телефона');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ContactsModule.findByPhone(api, query);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _loading = false;
          _error = 'Контакт с таким номером не найден';
        });
        return;
      }
      await _finish(
        userId: result.id,
        name: result.name,
        avatarUrl: result.avatarUrl,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ошибка: $e';
        });
      }
    }
  }

  Future<void> _submitId() async {
    final raw = _controller.text.trim();
    final id = int.tryParse(raw);
    if (id == null) {
      setState(() => _error = 'Введите числовой ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final packet = await api.sendRequest(Opcode.contactInfo, {
        'contactIds': [id],
      });
      final contacts = (packet.payload as Map?)?['contacts'] as List?;
      if (contacts == null || contacts.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Контакт с таким ID не найден';
          });
        }
        return;
      }
      final raw = Map<String, dynamic>.from(contacts.first as Map);
      final info = ContactInfo.fromMap(raw);
      ContactsModule.primeContactCache(raw);
      await _finish(
        userId: id,
        name: info.displayName,
        avatarUrl: info.avatarUrl,
      );
    } on PacketError catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ошибка: $e';
        });
      }
    }
  }

  Future<void> _finish({
    required int userId,
    required String? name,
    required String? avatarUrl,
  }) async {
    final accountId = await TokenStorage.getActiveAccountId();
    final existing = accountId == null
        ? null
        : await AppDatabase.findDialogChatByParticipant(accountId, userId);
    if (!mounted) return;
    Navigator.of(context).pop((
      userId: userId,
      chatId: existing ?? ((accountId ?? 0) ^ userId),
      name:
          ContactCache.get(userId) ??
          name ??
          AppLocalizations.of(context)!.userFallbackName(userId),
      avatarUrl: avatarUrl ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
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
              SegmentedButton<_FindMode>(
                segments: const [
                  ButtonSegment(
                    value: _FindMode.phone,
                    label: Text('Номер'),
                    icon: Icon(Symbols.call, size: 18),
                  ),
                  ButtonSegment(
                    value: _FindMode.id,
                    label: Text('ID'),
                    icon: Icon(Symbols.tag, size: 18),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _setMode(s.first),
                showSelectedIcon: false,
                style: ButtonStyle(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: _mode == _FindMode.phone
                    ? TextInputType.phone
                    : TextInputType.number,
                enabled: !_loading,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: TextStyle(color: cs.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: _mode == _FindMode.phone
                      ? 'Введите номер телефона'
                      : 'Введите ID контакта',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    _mode == _FindMode.phone ? Symbols.call : Symbols.tag,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.error_outline,
                        size: 18,
                        color: cs.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  shape: AppShape.buttonBorder,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SmallSpinner(size: 20)
                    : Text(widget.actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

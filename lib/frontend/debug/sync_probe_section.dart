import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../main.dart';
import '../widgets/glossy_pill.dart';
import '../widgets/small_spinner.dart';

class DebugSyncProbeSection extends StatefulWidget {
  const DebugSyncProbeSection({super.key});

  @override
  State<DebugSyncProbeSection> createState() => _DebugSyncProbeSectionState();
}

class _DebugSyncProbeSectionState extends State<DebugSyncProbeSection> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _result;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    if (phone.isEmpty) {
      setState(() => _result = 'Введите номер');
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final packet = await api.sendRequest(Opcode.sync, {
        'contactList': {
          phone: {'firstName': name},
        },
      });
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = _pretty(packet.payload);
      });
    } on PacketError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = 'PacketError: ${e.message}';
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
            'Sync contactList (21)',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Резолв контакта по номеру и имени, полный ответ сервера',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: '+6282233831826',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: 'Имя',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SmallSpinner(size: 20)
                : const Text('Отправить'),
          ),
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

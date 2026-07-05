import 'package:flutter/material.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:material_symbols_icons/symbols.dart';

class AttachmentPanel extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onPickFile;
  final Future<bool> Function(int fileId) onSendById;

  const AttachmentPanel({
    super.key,
    required this.onClose,
    required this.onPickFile,
    required this.onSendById,
  });

  @override
  State<AttachmentPanel> createState() => _AttachmentPanelState();
}

class _AttachmentPanelState extends State<AttachmentPanel> {
  final TextEditingController _fileIdController = TextEditingController();
  bool _sendingById = false;

  Future<void> _sendById() async {
    final s = _fileIdController.text.trim();
    if (s.isEmpty) return;
    final id = int.tryParse(s);
    if (id == null) {
      showCustomNotification(context, 'Неверный fileId');
      return;
    }
    setState(() => _sendingById = true);
    final ok = await widget.onSendById(id);
    if (!mounted) return;
    setState(() => _sendingById = false);
    if (ok) _fileIdController.clear();
  }

  @override
  void dispose() {
    _fileIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildButton(
                        label: 'Выбрать из файла',
                        icon: Symbols.folder_open,
                        filled: true,
                        onTap: _sendingById ? null : widget.onPickFile,
                        cs: cs,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildButton(
                        label: 'Отправить по id',
                        icon: null,
                        filled: false,
                        onTap: _sendingById ? null : _sendById,
                        cs: cs,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _fileIdController,
                  style: TextStyle(color: cs.onSurface, fontSize: 14),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'fileId...',
                    hintStyle: TextStyle(color: cs.onSurfaceVariant),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
          Positioned(
            left: 6,
            top: 6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: Icon(
                  Symbols.close,
                  color: cs.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData? icon,
    required bool filled,
    required VoidCallback? onTap,
    required ColorScheme cs,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? cs.primaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: filled
              ? null
              : Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: filled ? cs.onPrimaryContainer : cs.onSurface,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: filled ? cs.onPrimaryContainer : cs.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

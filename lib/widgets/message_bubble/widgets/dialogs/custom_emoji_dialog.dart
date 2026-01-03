import 'package:flutter/material.dart';

class CustomEmojiDialog extends StatefulWidget {
  final Function(String) onEmojiSelected;

  const CustomEmojiDialog({super.key, required this.onEmojiSelected});

  static Future<void> show(
    BuildContext context, {
    required Function(String) onEmojiSelected,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CustomEmojiDialog(onEmojiSelected: onEmojiSelected),
    );
  }

  @override
  State<CustomEmojiDialog> createState() => _CustomEmojiDialogState();
}

class _CustomEmojiDialogState extends State<CustomEmojiDialog> {
  final TextEditingController _controller = TextEditingController();
  String _selectedEmoji = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            Icons.emoji_emotions,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('Введите эмодзи'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: TextField(
              controller: _controller,
              maxLength: 1,
              decoration: InputDecoration(
                hintText: 'Введите эмодзи...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterText: '',
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedEmoji = value;
                });
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedEmoji.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(_selectedEmoji, style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: _selectedEmoji.isNotEmpty
              ? () {
                  widget.onEmojiSelected(_selectedEmoji);
                  Navigator.of(context).pop();
                }
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Добавить'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}

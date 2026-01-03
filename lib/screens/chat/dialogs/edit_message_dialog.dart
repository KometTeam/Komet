import 'package:flutter/material.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/app_sizes.dart';

class EditMessageDialog extends StatefulWidget {
  final Message message;
  final Function(String) onEdit;

  const EditMessageDialog({
    super.key,
    required this.message,
    required this.onEdit,
  });

  static Future<void> show(
    BuildContext context, {
    required Message message,
    required Function(String) onEdit,
  }) {
    return showDialog(
      context: context,
      builder: (context) => EditMessageDialog(message: message, onEdit: onEdit),
    );
  }

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать сообщение'),
      content: TextField(
        controller: _controller,
        maxLines: 5,
        decoration: const InputDecoration(hintText: 'Введите текст...'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () {
            final newText = _controller.text.trim();
            if (newText.isNotEmpty) {
              widget.onEdit(newText);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

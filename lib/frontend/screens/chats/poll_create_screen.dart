import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/custom_notification.dart';
import '../../widgets/sheet_helpers.dart';

class PollDraft {
  final String title;
  final List<String> answers;
  final bool multiple;
  final bool anonymous;

  const PollDraft({
    required this.title,
    required this.answers,
    required this.multiple,
    required this.anonymous,
  });
}

Future<PollDraft?> showCreatePollSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<PollDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => const _PollCreateSheet(),
  );
}

const int _maxAnswers = 10;

class _PollCreateSheet extends StatefulWidget {
  const _PollCreateSheet();

  @override
  State<_PollCreateSheet> createState() => _PollCreateSheetState();
}

class _PollCreateSheetState extends State<_PollCreateSheet> {
  final TextEditingController _question = TextEditingController();
  final List<TextEditingController> _answers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multiple = false;
  bool _anonymous = true;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canCreate {
    if (_question.text.trim().isEmpty) return false;
    final filled = _answers.where((c) => c.text.trim().isNotEmpty).length;
    return filled >= 2;
  }

  void _addAnswer() {
    if (_answers.length >= _maxAnswers) return;
    setState(() => _answers.add(TextEditingController()));
  }

  void _removeAnswer(int index) {
    if (_answers.length <= 2) return;
    setState(() => _answers.removeAt(index).dispose());
  }

  void _submit() {
    final title = _question.text.trim();
    final answers = _answers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (title.isEmpty || answers.length < 2) {
      showCustomNotification(context, 'Введите вопрос и минимум 2 варианта');
      return;
    }
    Navigator.of(context).pop(
      PollDraft(
        title: title,
        answers: answers,
        multiple: _multiple,
        anonymous: _anonymous,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SheetGrabber(),
              _buildHeader(cs),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _buildQuestionField(cs),
                    const SizedBox(height: 20),
                    Text(
                      'Варианты ответа',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _answers.length; i++)
                      _buildAnswerField(cs, i),
                    if (_answers.length < _maxAnswers)
                      _buildAddAnswerButton(cs),
                    const SizedBox(height: 16),
                    _buildToggle(
                      cs,
                      label: 'Несколько вариантов ответа',
                      value: _multiple,
                      onChanged: (v) => setState(() => _multiple = v),
                    ),
                    _buildToggle(
                      cs,
                      label: 'Анонимное голосование',
                      value: _anonymous,
                      onChanged: (v) => setState(() => _anonymous = v),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'Новый опрос',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _canCreate ? _submit : null,
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionField(ColorScheme cs) {
    return TextField(
      controller: _question,
      style: TextStyle(color: cs.onSurface, fontSize: 16),
      cursorColor: cs.primary,
      maxLength: 300,
      maxLines: null,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Задайте вопрос',
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildAnswerField(ColorScheme cs, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _answers[index],
              style: TextStyle(color: cs.onSurface, fontSize: 15),
              cursorColor: cs.primary,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Вариант ${index + 1}',
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                counterText: '',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_answers.length > 2)
            IconButton(
              icon: Icon(Symbols.remove_circle, color: cs.onSurfaceVariant),
              onPressed: () => _removeAnswer(index),
            ),
        ],
      ),
    );
  }

  Widget _buildAddAnswerButton(ColorScheme cs) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _addAnswer,
        icon: const Icon(Symbols.add, size: 20),
        label: const Text('Добавить вариант'),
      ),
    );
  }

  Widget _buildToggle(
    ColorScheme cs, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: cs.onSurface, fontSize: 15)),
      value: value,
      onChanged: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
    );
  }
}

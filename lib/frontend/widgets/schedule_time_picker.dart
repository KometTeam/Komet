import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import 'custom_notification.dart';
import 'sheet_helpers.dart';

const List<String> _weekdayShort = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

/// Барабан выбора времени отправки («Отправить позже»): три колонки —
/// день, час, минута. Возвращает выбранный момент в будущем или null.
Future<DateTime?> showScheduleTimePicker(
  BuildContext context, {
  DateTime? initial,
  String title = 'Отправить позже',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => _ScheduleSheet(initial: initial, title: title),
  );
}

class _ScheduleSheet extends StatefulWidget {
  final DateTime? initial;
  final String title;

  const _ScheduleSheet({required this.initial, required this.title});

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  static const int _dayCount = 366;

  late final DateTime _today;
  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  late int _dayIndex;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final base = (widget.initial != null && widget.initial!.isAfter(now))
        ? widget.initial!
        : now.add(const Duration(minutes: 1));

    _dayIndex = DateTime(
      base.year,
      base.month,
      base.day,
    ).difference(_today).inDays.clamp(0, _dayCount - 1);
    _hour = base.hour;
    _minute = base.minute;

    _dayCtrl = FixedExtentScrollController(initialItem: _dayIndex);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  String _dayLabel(int index) {
    if (index == 0) return 'Сегодня';
    if (index == 1) return 'Завтра';
    final d = _today.add(Duration(days: index));
    return '${_weekdayShort[d.weekday - 1]}, ${d.day} ${kRuMonthsShort[d.month - 1]}.';
  }

  DateTime get _selected => DateTime(
    _today.year,
    _today.month,
    _today.day + _dayIndex,
    _hour,
    _minute,
  );

  String get _buttonLabel {
    final s = _selected;
    final day = _dayIndex == 0
        ? 'сегодня'
        : _dayIndex == 1
        ? 'завтра'
        : '${s.day} ${kRuMonthsShort[s.month - 1]}';
    return 'Отправить $day в ${formatClock(s)}';
  }

  void _confirm() {
    final result = _selected;
    if (!result.isAfter(DateTime.now())) {
      showCustomNotification(context, 'Время должно быть в будущем');
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: Row(
                children: [
                  _wheel(
                    cs: cs,
                    controller: _dayCtrl,
                    count: _dayCount,
                    flex: 3,
                    align: Alignment.centerLeft,
                    onChanged: (i) => _dayIndex = i,
                    label: _dayLabel,
                  ),
                  _wheel(
                    cs: cs,
                    controller: _hourCtrl,
                    count: 24,
                    onChanged: (i) => _hour = i,
                    label: pad2,
                  ),
                  _wheel(
                    cs: cs,
                    controller: _minuteCtrl,
                    count: 60,
                    onChanged: (i) => _minute = i,
                    label: pad2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _confirm,
                child: Text(
                  _buttonLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required ColorScheme cs,
    required FixedExtentScrollController controller,
    required int count,
    required void Function(int) onChanged,
    required String Function(int) label,
    int flex = 1,
    Alignment align = Alignment.center,
  }) {
    return Expanded(
      flex: flex,
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 40,
        squeeze: 1.1,
        diameterRatio: 1.5,
        backgroundColor: Colors.transparent,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: cs.primary.withValues(alpha: 0.07),
        ),
        onSelectedItemChanged: (i) => setState(() => onChanged(i)),
        children: List.generate(
          count,
          (i) => Align(
            alignment: align,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                label(i),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurface, fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

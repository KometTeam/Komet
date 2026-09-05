import 'package:flutter/material.dart';

import '../../core/config/app_shape.dart';
import '../../core/storage/app_database.dart';
import '../widgets/glossy_pill.dart';
import '../widgets/small_spinner.dart';
import 'load_simulator.dart';
import 'render_stress_screen.dart';

class DebugLoadSimulationSection extends StatefulWidget {
  const DebugLoadSimulationSection({super.key});

  @override
  State<DebugLoadSimulationSection> createState() =>
      _DebugLoadSimulationSectionState();
}

class _DebugLoadSimulationSectionState
    extends State<DebugLoadSimulationSection> {
  final _chatIdController = TextEditingController();
  bool _busy = false;
  bool _loadingChats = false;
  String? _result;
  List<({int id, String title})> _myChats = const [];
  final Set<int> _selectedForParallel = {};

  @override
  void initState() {
    super.initState();
    _loadMyChats();
  }

  @override
  void dispose() {
    _chatIdController.dispose();
    super.dispose();
  }

  Future<int?> _activeAccountId() async {
    final profile = await AppDatabase.loadActiveProfile();
    return profile?.id;
  }

  Future<void> _loadMyChats() async {
    setState(() => _loadingChats = true);
    try {
      final accountId = await _activeAccountId();
      if (accountId == null) throw Exception('нет активного профиля');
      final rows = await AppDatabase.loadChats(accountId, includeHidden: true);
      if (!mounted) return;
      setState(() {
        _loadingChats = false;
        _myChats = rows
            .map(
              (r) => (
                id: r['id'] as int,
                title: (r['title'] as String?)?.trim().isNotEmpty == true
                    ? r['title'] as String
                    : '(без названия)',
              ),
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingChats = false;
        _result = 'Ошибка загрузки списка чатов: $e';
      });
    }
  }

  Future<int?> _resolveChatId({required int accountId}) async {
    final chatId = int.tryParse(_chatIdController.text.trim());
    if (chatId == null) {
      setState(() => _result = 'Введите числовой ID чата');
      return null;
    }
    final exists = await AppDatabase.chatExistsInCache(accountId, chatId);
    if (!exists) {
      setState(
        () => _result =
            'Чат $chatId не найден в локальном кэше — выбери из списка '
            'ниже или открой этот чат хотя бы раз, чтобы он закэшировался.',
      );
      return null;
    }
    return chatId;
  }

  Future<void> _generate(int count) async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final accountId = await _activeAccountId();
      if (accountId == null) throw Exception('нет активного профиля');
      final chatId = await _resolveChatId(accountId: accountId);
      if (chatId == null) {
        setState(() => _busy = false);
        return;
      }
      await LoadSimulator.generateMessages(
        accountId: accountId,
        chatId: chatId,
        count: count,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result =
            'Добавлено $count синтетических сообщений в чат $chatId.\n'
            'Переоткрой чат, чтобы увидеть их.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'Ошибка: $e';
      });
    }
  }

  Future<void> _clear() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final accountId = await _activeAccountId();
      if (accountId == null) throw Exception('нет активного профиля');
      final chatId = await _resolveChatId(accountId: accountId);
      if (chatId == null) {
        setState(() => _busy = false);
        return;
      }
      await LoadSimulator.clear(accountId: accountId, chatId: chatId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'Синтетические сообщения в чате $chatId удалены.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'Ошибка: $e';
      });
    }
  }

  Future<void> _generateParallel(int perChat) async {
    if (_selectedForParallel.isEmpty) {
      setState(() => _result = 'Выбери хотя бы один чат из списка ниже');
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final accountId = await _activeAccountId();
      if (accountId == null) throw Exception('нет активного профиля');
      final chatIds = _selectedForParallel.toList();
      await LoadSimulator.generateAcrossChats(
        accountId: accountId,
        chatIds: chatIds,
        perChat: perChat,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result =
            'Параллельно добавлено по $perChat сообщений в '
            '${chatIds.length} чатов: $chatIds.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'Ошибка: $e';
      });
    }
  }

  Future<void> _clearParallel() async {
    if (_selectedForParallel.isEmpty) {
      setState(() => _result = 'Выбери хотя бы один чат из списка ниже');
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final accountId = await _activeAccountId();
      if (accountId == null) throw Exception('нет активного профиля');
      final chatIds = _selectedForParallel.toList();
      await LoadSimulator.clearAcrossChats(accountId: accountId, chatIds: chatIds);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'Синтетические сообщения удалены из ${chatIds.length} чатов.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'Ошибка: $e';
      });
    }
  }

  void _openRenderStress() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'RenderStressScreen'),
        builder: (_) => const RenderStressScreen(),
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
            'Симуляция нагрузки',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Набивает локальную БД фейковыми сообщениями в указанном чате '
            'для стресс-теста скролла и рендера. Пишет напрямую в БД — '
            'чат нужно переоткрыть, чтобы увидеть изменения. Чат должен '
            'уже быть в локальном кэше (открывался хотя бы раз).',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _loadingChats
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: SmallSpinner(size: 16),
                      )
                    : DropdownButtonFormField<int>(
                        initialValue: int.tryParse(_chatIdController.text),
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: _myChats.isEmpty
                              ? 'Нет закэшированных чатов'
                              : 'Выбери чат',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        items: [
                          for (final chat in _myChats)
                            DropdownMenuItem(
                              value: chat.id,
                              child: Text(
                                '${chat.title} (${chat.id})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _busy || _myChats.isEmpty
                            ? null
                            : (id) => setState(
                                () => _chatIdController.text = id.toString(),
                              ),
                      ),
              ),
              IconButton(
                onPressed: _loadingChats ? null : _loadMyChats,
                icon: const Icon(Icons.refresh),
                tooltip: 'Обновить список чатов',
              ),
            ],
          ),
          if (_myChats.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Отметь чипы ниже, чтобы добавить чаты в параллельный тест '
              'дальше по странице.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chat in _myChats)
                  FilterChip(
                    label: Text('${chat.title} (${chat.id})'),
                    selected: _selectedForParallel.contains(chat.id),
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _selectedForParallel.add(chat.id);
                            } else {
                              _selectedForParallel.remove(chat.id);
                            }
                            _chatIdController.text = chat.id.toString();
                          }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final count in [100, 1000, 5000])
                FilledButton(
                  onPressed: _busy ? null : () => _generate(count),
                  style: FilledButton.styleFrom(shape: AppShape.buttonBorder),
                  child: Text('+$count'),
                ),
              OutlinedButton(
                onPressed: _busy ? null : _clear,
                style: OutlinedButton.styleFrom(shape: AppShape.buttonBorder),
                child: const Text('Очистить'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Параллельная нагрузка на несколько чатов',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Отметь чаты выше (FilterChip), затем пиши сразу во все — '
            'имитация нагрузки от нескольких чатов одновременно.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final count in [200, 1000])
                FilledButton(
                  onPressed: _busy ? null : () => _generateParallel(count),
                  style: FilledButton.styleFrom(shape: AppShape.buttonBorder),
                  child: Text('Выбранным +$count каждому'),
                ),
              OutlinedButton(
                onPressed: _busy ? null : _clearParallel,
                style: OutlinedButton.styleFrom(shape: AppShape.buttonBorder),
                child: const Text('Очистить у выбранных'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Рендер-стресс-тест',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Открывает экран с сотнями синтетических "пузырей" и сам '
            'автоматически быстро скроллит его, снимая FPS/джанк через '
            'встроенный APM. Результат — воспроизводимая цифра, не на глаз.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _openRenderStress,
            style: FilledButton.styleFrom(shape: AppShape.buttonBorder),
            child: const Text('Запустить рендер-стресс-тест'),
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const Center(child: SmallSpinner(size: 20)),
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
              child: Text(
                _result!,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

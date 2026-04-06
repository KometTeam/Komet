import 'dart:math';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart' show accountModule;
import '../../../backend/modules/account.dart'
    show PrivacyConfig, BlockedContact;
import '../../../core/storage/app_database.dart';
import '../../widgets/custom_notification.dart';
import 'password_entry_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _is2faEnabled = false;
  PrivacyConfig? _privacyConfig;
  List<BlockedContact> _blockedContacts = [];
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        accountModule.getPrivacyConfig(),
        accountModule.getBlockedContacts(),
        AppDatabase.loadActiveProfile(),
      ]);
      if (mounted) {
        setState(() {
          _privacyConfig = results[0] as PrivacyConfig;
          _blockedContacts = results[1] as List<BlockedContact>;
          final profile = results[2] as ProfileData?;
          _is2faEnabled = profile?.profileOptions?.contains(2) ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Ошибка загрузки: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final newConfig = await accountModule.updatePrivacyConfig({key: value});
      if (mounted) {
        setState(() => _privacyConfig = newConfig);
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Ошибка сохранения: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? _buildShimmer(cs)
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildAppBar(context, cs)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildTopSection(cs),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildPrivacySettings(cs),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _buildInfoLabel(cs),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildConfidentialSection(cs),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      child: _buildBlacklistSection(cs),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildShimmer(ColorScheme cs) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildAppBar(context, cs),
          _buildShimmerSection(cs, height: 104),
          const SizedBox(height: 12),
          _buildShimmerSection(cs, height: 280),
          const SizedBox(height: 20),
          _buildShimmerSection(cs, height: 220),
          const SizedBox(height: 12),
          _buildShimmerSection(cs, height: 120),
        ],
      ),
    );
  }

  Widget _buildShimmerSection(ColorScheme cs, {required double height}) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.3 + 0.2 * sin(_shimmerController.value * pi * 2);
        return Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Symbols.arrow_back,
              color: cs.onSurface,
              size: 24,
              weight: 400,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            'Безопасность',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
          const Spacer(),
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getPrivacyLabel(String value) {
    switch (value) {
      case 'ALL':
        return 'Все';
      case 'CONTACTS':
        return 'Мои контакты';
      case 'NONE':
        return 'Никто';
      default:
        return value;
    }
  }

  Widget _buildTopSection(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildPasswordRow(cs),
          _buildNavRow(
            cs,
            icon: Symbols.shield,
            label: 'Семейная защита',
            subtitle: _privacyConfig?.familyProtection == 'ON'
                ? 'Включена'
                : 'Отключена',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRow(ColorScheme cs) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PasswordEntryScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              child: Row(
                children: [
                  Icon(
                    Symbols.key,
                    color: cs.onSurfaceVariant,
                    size: 22,
                    weight: 400,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Пароль для входа',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _is2faEnabled ? 'Включён' : 'Отключён',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildWarningBadge(cs),
                  const SizedBox(width: 4),
                  Icon(
                    Symbols.chevron_right,
                    color: cs.outline,
                    size: 20,
                    weight: 400,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 58),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySettings(ColorScheme cs) {
    final isSafeMode = _privacyConfig?.safeMode ?? false;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            child: Row(
              children: [
                Icon(
                  Symbols.lock,
                  color: cs.onSurfaceVariant,
                  size: 22,
                  weight: 400,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Безопасный режим',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Скрывает личную информацию',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isSafeMode,
                  onChanged: (v) => showCustomNotification(
                    context,
                    'Изменение настроек пока недоступно',
                  ),
                ),
              ],
            ),
          ),
          if (isSafeMode) ...[
            Padding(
              padding: const EdgeInsets.only(left: 58),
              child: Divider(
                height: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            _buildSubRow(
              cs,
              label: 'Найти меня по номеру',
              value: _getPrivacyLabel(_privacyConfig?.searchByPhone ?? 'ALL'),
              isLast: false,
            ),
            _buildSubRow(
              cs,
              label: 'Кто может мне звонить',
              value: _getPrivacyLabel(
                _privacyConfig?.incomingCall ?? 'CONTACTS',
              ),
              isLast: false,
            ),
            _buildSubRow(
              cs,
              label: 'Кто может приглашать в чаты',
              value: _getPrivacyLabel(
                _privacyConfig?.chatsInvite ?? 'CONTACTS',
              ),
              isLast: false,
            ),
            _buildSubRow(
              cs,
              label: 'Показывать контакт',
              value: _privacyConfig?.contentLevelAccess == true
                  ? 'Безопасный'
                  : 'Весь',
              isLast: true,
            ),
          ],
          if (!isSafeMode) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Divider(
                height: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            _buildOptionRow(
              cs,
              icon: Symbols.phone,
              label: 'Кто может мне звонить',
              value: _getPrivacyLabel(
                _privacyConfig?.incomingCall ?? 'CONTACTS',
              ),
              isLast: false,
              onTap: () => _showOptionSheet(
                context,
                cs,
                title: 'Кто может мне звонить',
                currentValue: _privacyConfig?.incomingCall ?? 'CONTACTS',
                options: const [('ALL', 'Все'), ('CONTACTS', 'Мои контакты')],
                onSelect: (value) => _updateSetting('INCOMING_CALL', value),
              ),
            ),
            _buildOptionRow(
              cs,
              icon: Symbols.group,
              label: 'Кто может приглашать в чаты',
              value: _getPrivacyLabel(
                _privacyConfig?.chatsInvite ?? 'CONTACTS',
              ),
              isLast: false,
              onTap: () => _showOptionSheet(
                context,
                cs,
                title: 'Кто может приглашать в чаты',
                currentValue: _privacyConfig?.chatsInvite ?? 'CONTACTS',
                options: const [('ALL', 'Все'), ('CONTACTS', 'Мои контакты')],
                onSelect: (value) => _updateSetting('CHATS_INVITE', value),
              ),
            ),
            _buildOptionRow(
              cs,
              icon: Symbols.contact_phone,
              label: 'Найти меня по номеру',
              value: _getPrivacyLabel(_privacyConfig?.searchByPhone ?? 'ALL'),
              isLast: false,
              onTap: () => _showOptionSheet(
                context,
                cs,
                title: 'Найти меня по номеру',
                currentValue: _privacyConfig?.searchByPhone ?? 'ALL',
                options: const [('ALL', 'Все'), ('CONTACTS', 'Мои контакты')],
                onSelect: (value) => _updateSetting('SEARCH_BY_PHONE', value),
              ),
            ),
            _buildOptionRow(
              cs,
              icon: Icons.visibility_off_outlined,
              label: 'Видеть статус «в сети»',
              value: _privacyConfig?.hidden == true ? 'Никто' : 'Мои контакты',
              isLast: true,
              onTap: () => _showHiddenStatusSheet(context, cs),
            ),
          ],
        ],
      ),
    );
  }

  void _showOptionSheet(
    BuildContext context,
    ColorScheme cs, {
    required String title,
    required String currentValue,
    required List<(String, String)> options,
    required void Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
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
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...options.map((option) {
                final isSelected = option.$1 == currentValue;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(option.$1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.$2,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Symbols.check, color: cs.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showHiddenStatusSheet(BuildContext context, ColorScheme cs) {
    final currentValue = _privacyConfig?.hidden == true ? 'NONE' : 'CONTACTS';

    if (currentValue == 'NONE') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Вы уверены?', style: TextStyle(color: cs.onSurface)),
          content: Text(
            'Вы не сможете видеть статусы посещения других пользователей.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена', style: TextStyle(color: cs.primary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateSetting('HIDDEN', false);
              },
              child: Text('Да', style: TextStyle(color: cs.primary)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
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
                'Видеть статус «в сети»',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildOptionSheetItem(
                cs,
                'Мои контакты',
                currentValue == 'CONTACTS',
                () {
                  Navigator.pop(context);
                  _updateSetting('HIDDEN', false);
                },
              ),
              _buildOptionSheetItem(cs, 'Никто', currentValue == 'NONE', () {
                Navigator.pop(context);
                _showHiddenStatusConfirmDialog(context, cs);
              }, isLast: true),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showHiddenStatusConfirmDialog(BuildContext context, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Вы уверены?', style: TextStyle(color: cs.onSurface)),
        content: Text(
          'Вы не сможете видеть статусы посещения других пользователей.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: cs.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateSetting('HIDDEN', true);
            },
            child: Text('Да', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionSheetItem(
    ColorScheme cs,
    String label,
    bool isSelected,
    VoidCallback onTap, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: cs.onSurface, fontSize: 16),
                    ),
                  ),
                  if (isSelected)
                    Icon(Symbols.check, color: cs.primary, size: 20),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoLabel(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 0),
      child: Text(
        'КОНФИДЕНЦИАЛЬНОСТЬ',
        style: TextStyle(
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildConfidentialSection(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildSwitchRow(
            cs,
            icon: Symbols.description,
            label: 'Галочки «Прочитано»',
            value: _privacyConfig?.showReadMark ?? true,
            isLast: false,
            onChanged: (v) => _updateSetting('SHOW_READ_MARK', v),
          ),
          _buildSwitchRow(
            cs,
            icon: Symbols.keyboard_alt,
            label: 'Альтернативная клавиатура',
            value: _privacyConfig?.altKeyboard ?? false,
            isLast: false,
            onChanged: (v) => _updateSetting('ALT_KEYBOARD', v),
          ),
          _buildSwitchRow(
            cs,
            icon: Symbols.warning,
            label: 'Принимать опасные файлы',
            value: _privacyConfig?.unsafeFiles ?? true,
            isLast: false,
            onChanged: (v) => _updateSetting('UNSAFE_FILES', v),
          ),
          _buildSwitchRow(
            cs,
            icon: Icons.mic_none_outlined,
            label: 'Транскрибация аудио',
            value: _privacyConfig?.audioTranscriptionEnabled ?? true,
            isLast: true,
            onChanged: (v) => _updateSetting('AUDIO_TRANSCRIPTION_ENABLED', v),
          ),
        ],
      ),
    );
  }

  Widget _buildBlacklistSection(ColorScheme cs) {
    final count = _blockedContacts.length;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showCustomNotification(
            context,
            'Чёрный список: $count контактов',
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            child: Row(
              children: [
                Icon(
                  Symbols.block,
                  color: cs.onSurfaceVariant,
                  size: 22,
                  weight: 400,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Чёрный список',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count ${_getBlockedCountText(count)}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Symbols.chevron_right,
                  color: cs.outline,
                  size: 20,
                  weight: 400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getBlockedCountText(int count) {
    if (count == 0) return 'контактов';
    final mod = count % 10;
    if (mod == 1 && count != 11) return 'контакт';
    if (mod >= 2 && mod <= 4 && (count < 10 || count > 20)) return 'контакта';
    return 'контактов';
  }

  Widget _buildNavRow(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    String? subtitle,
    String? value,
    Widget? trailing,
    required bool isLast,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showCustomNotification(context, label),
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              child: Row(
                children: [
                  Icon(icon, color: cs.onSurfaceVariant, size: 22, weight: 400),
                  const SizedBox(width: 16),
                  Expanded(
                    child: subtitle != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            label,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                  if (value != null)
                    Text(
                      value,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  if (trailing != null) trailing,
                  const SizedBox(width: 4),
                  Icon(
                    Symbols.chevron_right,
                    color: cs.outline,
                    size: 20,
                    weight: 400,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }

  Widget _buildOptionRow(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required String value,
    required bool isLast,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              child: Row(
                children: [
                  Icon(icon, color: cs.onSurfaceVariant, size: 22, weight: 400),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Symbols.chevron_right,
                    color: cs.outline,
                    size: 20,
                    weight: 400,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }

  Widget _buildSubRow(
    ColorScheme cs, {
    required String label,
    required String value,
    required bool isLast,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showCustomNotification(context, label),
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: cs.onSurface, fontSize: 15),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Symbols.chevron_right,
                    color: cs.outline,
                    size: 18,
                    weight: 400,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.35),
            indent: 20,
            endIndent: 20,
          ),
      ],
    );
  }

  Widget _buildSwitchRow(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required bool value,
    required bool isLast,
    required void Function(bool) onChanged,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: cs.onSurfaceVariant, size: 22, weight: 400),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }

  Widget _buildWarningBadge(ColorScheme cs) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: cs.error, shape: BoxShape.circle),
      child: Icon(
        Symbols.priority_high,
        color: cs.onError,
        size: 14,
        weight: 700,
      ),
    );
  }
}

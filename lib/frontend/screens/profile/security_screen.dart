import 'dart:math';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart' show accountModule;
import '../../../backend/modules/account.dart'
    show PrivacyConfig, BlockedContact;
import '../../../core/storage/app_database.dart';
import '../../../core/config/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/sheet_helpers.dart';
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
      bool is2faEnabled;
      try {
        is2faEnabled = (await accountModule.get2faStatus()).enabled;
      } catch (_) {
        final profile = results[2] as ProfileData?;
        is2faEnabled = profile?.profileOptions?.contains(2) ?? false;
      }
      if (mounted) {
        setState(() {
          _privacyConfig = results[0] as PrivacyConfig;
          _blockedContacts = results[1] as List<BlockedContact>;
          _is2faEnabled = is2faEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.securityLoadError(e.toString()),
        );
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
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.securitySaveError(e.toString()),
        );
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
          ConnectionTitleText(
            AppLocalizations.of(context)!.securityTitle,
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
    final l10n = AppLocalizations.of(context)!;
    switch (value) {
      case 'ALL':
        return l10n.securityPrivacyAll;
      case 'CONTACTS':
        return l10n.securityPrivacyContacts;
      case 'NONE':
      case 'NOBODY':
        return l10n.securityPrivacyNobody;
      default:
        return value;
    }
  }

  Widget _buildTopSection(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      child: Column(
        children: [
          _buildPasswordRow(cs),
          _settingsRow(
            cs,
            icon: Symbols.shield,
            label: l10n.securityFamilyProtection,
            subtitle: _privacyConfig?.familyProtection == 'ON'
                ? l10n.securityEnabledFem
                : l10n.securityDisabledFem,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRow(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
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
                          l10n.securityPasswordTitle,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _is2faEnabled
                              ? l10n.securityEnabledMasc
                              : l10n.securityDisabledMasc,
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
    final l10n = AppLocalizations.of(context)!;
    final isSafeMode = _privacyConfig?.safeMode ?? false;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
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
                        l10n.securityModeTitle,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.securityModeSubtitle,
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
                    l10n.securitySettingsUnavailable,
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
            _settingsRow(
              cs,
              label: l10n.securityFindByPhone,
              trailingText: _getPrivacyLabel(
                _privacyConfig?.searchByPhone ?? 'ALL',
              ),
              verticalPadding: 16,
              labelFontSize: 15,
              labelFontWeight: null,
              chevronSize: 18,
              insetDivider: false,
              isLast: false,
            ),
            _settingsRow(
              cs,
              label: l10n.securityWhoCanCall,
              trailingText: _getPrivacyLabel(
                _privacyConfig?.incomingCall ?? 'CONTACTS',
              ),
              verticalPadding: 16,
              labelFontSize: 15,
              labelFontWeight: null,
              chevronSize: 18,
              insetDivider: false,
              isLast: false,
            ),
            _settingsRow(
              cs,
              label: l10n.securityWhoCanInvite,
              trailingText: _getPrivacyLabel(
                _privacyConfig?.chatsInvite ?? 'CONTACTS',
              ),
              verticalPadding: 16,
              labelFontSize: 15,
              labelFontWeight: null,
              chevronSize: 18,
              insetDivider: false,
              isLast: false,
            ),
            _settingsRow(
              cs,
              label: l10n.securityShowContact,
              trailingText: _privacyConfig?.contentLevelAccess == true
                  ? l10n.securityContentSafe
                  : l10n.securityContentAll,
              verticalPadding: 16,
              labelFontSize: 15,
              labelFontWeight: null,
              chevronSize: 18,
              insetDivider: false,
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
            _settingsRow(
              cs,
              icon: Symbols.phone,
              label: l10n.securityWhoCanCall,
              trailingText: _getPrivacyLabel(
                _privacyConfig?.incomingCall ?? 'CONTACTS',
              ),
              isLast: false,
              onTap: () => _showOptionSheet(
                context,
                cs,
                title: l10n.securityWhoCanCall,
                currentValue: _privacyConfig?.incomingCall ?? 'CONTACTS',
                options: [
                  ('ALL', l10n.securityPrivacyAll),
                  ('CONTACTS', l10n.securityPrivacyContacts),
                ],
                onSelect: (value) => _updateSetting('INCOMING_CALL', value),
              ),
            ),
            _settingsRow(
              cs,
              icon: Symbols.group,
              label: l10n.securityWhoCanInvite,
              trailingText: _getPrivacyLabel(
                _privacyConfig?.chatsInvite ?? 'CONTACTS',
              ),
              isLast: false,
              onTap: () => _showOptionSheet(
                context,
                cs,
                title: l10n.securityWhoCanInvite,
                currentValue: _privacyConfig?.chatsInvite ?? 'CONTACTS',
                options: [
                  ('ALL', l10n.securityPrivacyAll),
                  ('CONTACTS', l10n.securityPrivacyContacts),
                ],
                onSelect: (value) => _updateSetting('CHATS_INVITE', value),
              ),
            ),
            _settingsRow(
              cs,
              icon: Symbols.contact_phone,
              label: l10n.securityFindByPhone,
              trailingText: _getPrivacyLabel(
                _privacyConfig?.searchByPhone ?? 'ALL',
              ),
              isLast: false,
              onTap: () => _showOptionSheet(
                context,
                cs,
                title: l10n.securityFindByPhone,
                currentValue: _privacyConfig?.searchByPhone ?? 'ALL',
                options: [
                  ('ALL', l10n.securityPrivacyAll),
                  ('CONTACTS', l10n.securityPrivacyContacts),
                ],
                onSelect: (value) => _updateSetting('SEARCH_BY_PHONE', value),
              ),
            ),
            _settingsRow(
              cs,
              icon: Icons.visibility_off_outlined,
              label: l10n.securityShowOnlineStatus,
              trailingText: _privacyConfig?.hidden == true
                  ? l10n.securityPrivacyNobody
                  : l10n.securityPrivacyContacts,
              isLast: false,
              onTap: () => _showHiddenStatusSheet(context, cs),
            ),
            _settingsRow(
              cs,
              icon: Symbols.contact_page,
              label: l10n.securityShowMyNumber,
              trailingText: _getPrivacyLabel(
                _privacyConfig?.phoneNumberPrivacy ?? 'ALL',
              ),
              isLast: true,
              onTap: () => _showOptionSheet(
                context,
                cs,
                title: l10n.securityShowMyNumber,
                currentValue: _privacyConfig?.phoneNumberPrivacy ?? 'ALL',
                options: [
                  ('ALL', l10n.securityPrivacyAll),
                  ('CONTACTS', l10n.securityPrivacyContacts),
                  ('NOBODY', l10n.securityPrivacyNobody),
                ],
                onSelect: (value) =>
                    _updateSetting('PHONE_NUMBER_PRIVACY', value),
              ),
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
      shape: kSheetShape,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const SheetGrabber(margin: EdgeInsets.zero),
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

  Future<void> _showHiddenStatusSheet(
    BuildContext context,
    ColorScheme cs,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final currentValue = _privacyConfig?.hidden == true ? 'NONE' : 'CONTACTS';

    if (currentValue == 'NONE') {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.securityConfirmTitle,
        message: l10n.securityHiddenStatusWarning,
        confirmLabel: l10n.spoofDialogYes,
      );
      if (confirmed) _updateSetting('HIDDEN', false);
      return;
    }

    _showOptionSheet(
      context,
      cs,
      title: l10n.securityShowOnlineStatus,
      currentValue: currentValue,
      options: [
        ('CONTACTS', l10n.securityPrivacyContacts),
        ('NONE', l10n.securityPrivacyNobody),
      ],
      onSelect: (value) {
        if (value == 'CONTACTS') {
          _updateSetting('HIDDEN', false);
        } else {
          _showHiddenStatusConfirmDialog(context, cs);
        }
      },
    );
  }

  Future<void> _showHiddenStatusConfirmDialog(
    BuildContext context,
    ColorScheme cs,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.securityConfirmTitle,
      message: l10n.securityHiddenStatusWarning,
      confirmLabel: l10n.spoofDialogYes,
    );
    if (confirmed) _updateSetting('HIDDEN', true);
  }

  Widget _buildInfoLabel(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 0),
      child: Text(
        AppLocalizations.of(context)!.securityConfidentialityHeader,
        style: TextStyle(
          color: cs.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildConfidentialSection(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final showReadMark = _privacyConfig?.showReadMark ?? true;
    final altKeyboard = _privacyConfig?.altKeyboard ?? false;
    final unsafeFiles = _privacyConfig?.unsafeFiles ?? true;
    final audioTranscription =
        _privacyConfig?.audioTranscriptionEnabled ?? true;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      child: Column(
        children: [
          _settingsRow(
            cs,
            icon: Symbols.description,
            label: l10n.securityReadReceipts,
            trailingWidget: Switch(
              value: showReadMark,
              onChanged: (v) => _updateSetting('SHOW_READ_MARK', v),
            ),
            showChevron: false,
            verticalPadding: 14,
            isLast: false,
            onTap: () => _updateSetting('SHOW_READ_MARK', !showReadMark),
          ),
          _settingsRow(
            cs,
            icon: Symbols.keyboard_alt,
            label: l10n.securityAltKeyboard,
            trailingWidget: Switch(
              value: altKeyboard,
              onChanged: (v) => _updateSetting('ALT_KEYBOARD', v),
            ),
            showChevron: false,
            verticalPadding: 14,
            isLast: false,
            onTap: () => _updateSetting('ALT_KEYBOARD', !altKeyboard),
          ),
          _settingsRow(
            cs,
            icon: Symbols.warning,
            label: l10n.securityUnsafeFiles,
            trailingWidget: Switch(
              value: unsafeFiles,
              onChanged: (v) => _updateSetting('UNSAFE_FILES', v),
            ),
            showChevron: false,
            verticalPadding: 14,
            isLast: false,
            onTap: () => _updateSetting('UNSAFE_FILES', !unsafeFiles),
          ),
          _settingsRow(
            cs,
            icon: Icons.mic_none_outlined,
            label: l10n.securityAudioTranscription,
            trailingWidget: Switch(
              value: audioTranscription,
              onChanged: (v) =>
                  _updateSetting('AUDIO_TRANSCRIPTION_ENABLED', v),
            ),
            showChevron: false,
            verticalPadding: 14,
            isLast: true,
            onTap: () => _updateSetting(
              'AUDIO_TRANSCRIPTION_ENABLED',
              !audioTranscription,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlacklistSection(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final count = _blockedContacts.length;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showCustomNotification(
            context,
            l10n.securityBlacklistNotification('$count'),
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
                        l10n.securityBlacklistTitle,
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

  Widget _settingsRow(
    ColorScheme cs, {
    IconData? icon,
    required String label,
    String? subtitle,
    String? trailingText,
    Widget? trailingWidget,
    bool showChevron = true,
    double chevronSize = 20,
    double verticalPadding = 17,
    double labelFontSize = 16,
    FontWeight? labelFontWeight = FontWeight.w500,
    bool insetDivider = true,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ?? () => showCustomNotification(context, label),
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: verticalPadding,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: cs.onSurfaceVariant,
                      size: 22,
                      weight: 400,
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: subtitle != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: labelFontSize,
                                  fontWeight: labelFontWeight,
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
                              fontSize: labelFontSize,
                              fontWeight: labelFontWeight,
                            ),
                          ),
                  ),
                  if (trailingText != null)
                    Text(
                      trailingText,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ?trailingWidget,
                  if (showChevron) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Symbols.chevron_right,
                      color: cs.outline,
                      size: chevronSize,
                      weight: 400,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          insetDivider
              ? Padding(
                  padding: const EdgeInsets.only(left: 58),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                )
              : Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                  indent: 20,
                  endIndent: 20,
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

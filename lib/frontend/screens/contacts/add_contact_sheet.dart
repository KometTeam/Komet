import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:komet/backend/modules/contacts.dart';
import 'package:komet/core/config/countries.dart';
import 'package:komet/frontend/screens/auth/phone_input_formatter.dart';
import 'package:komet/frontend/screens/auth/select_country_screen.dart';
import 'package:komet/frontend/screens/contacts/contact_sheet_common.dart';
import 'package:komet/frontend/screens/contacts/open_contact_profile.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/main.dart';

Future<void> showAddContactSheet(BuildContext context) {
  return showBlurredCard<void>(
    context,
    (host) => _AddContactCard(hostContext: host),
  );
}

class _AddContactCard extends StatefulWidget {
  final BuildContext hostContext;

  const _AddContactCard({required this.hostContext});

  @override
  State<_AddContactCard> createState() => _AddContactCardState();
}

class _AddContactCardState extends State<_AddContactCard> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _firstCtrl = TextEditingController();
  final TextEditingController _lastCtrl = TextEditingController();

  late CountryName _country;
  bool _loading = false;
  String? _notFoundPhone;

  @override
  void initState() {
    super.initState();
    final allowed = api.registrationCountries;
    _country =
        countriesByCode['RU'] ??
        (allowed.isNotEmpty ? allowed.first : allCountries.first);
    if (allowed.isNotEmpty && !allowed.any((c) => c.code == _country.code)) {
      _country = allowed.first;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  String get _digits => _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
  bool get _phoneValid => _digits.length == _country.phoneDigits;
  bool get _canSave =>
      _phoneValid && _firstCtrl.text.trim().isNotEmpty && !_loading;

  Future<void> _pickCountry() async {
    final picked = await Navigator.of(context).push<CountryName>(
      MaterialPageRoute(
        builder: (_) => SelectCountryScreen(
          selectedCountry: _country,
          countries: api.registrationCountries,
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _country = picked;
        _phoneCtrl.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _loading = true);
    final phone = '${_country.phoneCode}$_digits';
    final result = await ContactsModule.addContactByPhone(
      api,
      phone: phone,
      firstName: _firstCtrl.text.trim(),
      lastName: _lastCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result.status) {
      case AddContactStatus.added:
        final contact = result.contact;
        Navigator.of(context).pop();
        if (contact == null) return;
        final name = (contact.lastName != null && contact.lastName!.isNotEmpty)
            ? '${contact.firstName} ${contact.lastName}'
            : contact.firstName;
        if (!widget.hostContext.mounted) return;
        await openContactDialogProfile(
          widget.hostContext,
          contactId: contact.id,
          name: name,
          avatarUrl: contact.baseUrl,
        );
      case AddContactStatus.notFound:
        setState(() => _notFoundPhone = phone);
      case AddContactStatus.error:
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.addContactError,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width > 420 ? 380 : double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _notFoundPhone != null
                  ? _buildNotFound(cs)
                  : _buildForm(cs),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.addContactTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _buildPhoneRow(cs),
          contactSheetDivider(cs),
          _buildTextRow(
            cs,
            controller: _firstCtrl,
            hint: l10n.addContactFirstName,
          ),
          contactSheetDivider(cs),
          _buildTextRow(
            cs,
            controller: _lastCtrl,
            hint: l10n.addContactLastName,
          ),
          contactSheetDivider(cs),
          _buildSaveButton(cs, l10n),
        ],
      ),
    );
  }

  Widget _buildPhoneRow(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          InkWell(
            onTap: _loading ? null : _pickCountry,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    contactFlagEmoji(_country.code),
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _country.phoneCode,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: ValueKey(_country.code),
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                PhoneInputFormatter(_country),
              ],
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: cs.onSurface, fontSize: 16),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: _country.phoneMask.replaceAll('#', '0'),
                hintStyle: TextStyle(color: cs.outline, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextRow(
    ColorScheme cs, {
    required TextEditingController controller,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: cs.onSurface, fontSize: 16),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                hintText: hint,
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${controller.text.characters.length}/60',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme cs, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _canSave ? _save : null,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: cs.primary,
          disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        child: _loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : Text(
                l10n.addContactSave,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildNotFound(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.addContactNotFound(_notFoundPhone ?? ''),
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.addContactNotFoundSubtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => setState(() => _notFoundPhone = null),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(l10n.addContactSearchOther),
            ),
          ),
        ],
      ),
    );
  }

}

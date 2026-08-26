import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/core/config/countries.dart';
import 'package:komet/l10n/app_localizations.dart';

class SelectCountryScreen extends StatefulWidget {
  final CountryName selectedCountry;
  final List<CountryName> countries;

  SelectCountryScreen({
    super.key,
    required this.selectedCountry,
    List<CountryName>? countries,
  }) : countries = countries ?? allCountries;

  @override
  State<SelectCountryScreen> createState() => _SelectCountryScreenState();
}

class _CountrySearchEntry {
  final CountryName country;
  final String ruLower;
  final String enLower;

  const _CountrySearchEntry(this.country, this.ruLower, this.enLower);
}

class _SelectCountryScreenState extends State<SelectCountryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<CountryName> _sortedCountries = const [];
  List<CountryName> _filteredCountries = const [];
  List<_CountrySearchEntry> _searchEntries = const [];
  String _lang = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == _lang) return;
    _lang = lang;
    _sortedCountries = sortedByDisplayName(widget.countries, lang);
    _searchEntries = _sortedCountries
        .map(
          (c) => _CountrySearchEntry(c, c.ru.toLowerCase(), c.en.toLowerCase()),
        )
        .toList();
    _filteredCountries = _applyFilter(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CountryName> _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _sortedCountries;
    final matches = _searchEntries
        .where(
          (e) =>
              e.ruLower.contains(q) ||
              e.enLower.contains(q) ||
              e.country.phoneCode.contains(q),
        )
        .map((e) => e.country)
        .toList();
    if (_looksLikePhoneCode(q)) {
      matches.sort((a, b) {
        final byPrimary =
            (isPrimaryForPhoneCode(b) ? 1 : 0) -
            (isPrimaryForPhoneCode(a) ? 1 : 0);
        if (byPrimary != 0) return byPrimary;
        return a
            .displayName(_lang)
            .toLowerCase()
            .compareTo(b.displayName(_lang).toLowerCase());
      });
    }
    return matches;
  }

  static bool _looksLikePhoneCode(String query) =>
      RegExp(r'^\+?\d+$').hasMatch(query);

  void _filterCountries(String query) {
    setState(() => _filteredCountries = _applyFilter(query));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: l10n.selectCountrySearchHint,
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: _filterCountries,
              )
            : Text(
                l10n.selectCountryTitle,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredCountries = _sortedCountries;
                }
              });
            },
            icon: Icon(
              _isSearching ? Symbols.close : Symbols.search,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _filteredCountries.length,
        itemBuilder: (context, index) {
          final country = _filteredCountries[index];
          final isSelected = country.code == widget.selectedCountry.code;

          return ListTile(
            leading: Text(
              country.phoneCode,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            title: Text(
              country.displayName(lang),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            trailing: isSelected
                ? Icon(Symbols.check, color: cs.primary)
                : null,
            onTap: () {
              Navigator.pop(context, country);
            },
          );
        },
      ),
    );
  }
}

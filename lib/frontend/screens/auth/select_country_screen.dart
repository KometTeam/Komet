import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _SelectCountryScreenState extends State<SelectCountryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  late List<CountryName> _filteredCountries;

  @override
  void initState() {
    super.initState();
    _filteredCountries = widget.countries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = widget.countries;
      } else {
        final q = query.toLowerCase();
        _filteredCountries = widget.countries.where((c) {
          return c.ru.toLowerCase().contains(q) ||
              c.en.toLowerCase().contains(q) ||
              c.phoneCode.contains(q);
        }).toList();
      }
    });
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
                style: GoogleFonts.inter(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: l10n.selectCountrySearchHint,
                  hintStyle: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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
                  _filteredCountries = widget.countries;
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
              style: GoogleFonts.inter(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            title: Text(
              lang == 'ru' ? country.ru : country.en,
              style: GoogleFonts.inter(
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

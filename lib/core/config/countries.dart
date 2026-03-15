import 'dart:convert';

class CountryName {
  final String code; // ISO 3166-1 alpha-2, например "RU"
  final String en;
  final String ru;
  final String phoneCode;   // Код страны для звонков, например "+7"
  final int phoneDigits;    // Количество цифр номера после кода страны
  final String phoneMask;   // Маска абонентского номера, например "(###) ###-##-##"
  final List<int> phoneGroupSizes;        // Размеры групп цифр, например [3, 3, 2, 2]
  final List<String> phoneGroupSeparators; // Разделители вокруг групп, например ["(", ") ", "-", "-", ""]

  const CountryName({
    required this.code,
    required this.en,
    required this.ru,
    required this.phoneCode,
    required this.phoneDigits,
    required this.phoneMask,
    required this.phoneGroupSizes,
    required this.phoneGroupSeparators,
  });
}

/// Полный список стран (195 государств) с названием на русском и английском.
///
/// Источник данных:
/// https://github.com/stefangabos/world_countries
final List<CountryName> allCountries = _buildCountries();

/// Быстрый доступ по ISO-коду.
final Map<String, CountryName> countriesByCode = {
  for (final country in allCountries) country.code: country,
};

/// Пример использования:
/// ```dart
/// final country = exampleCountryLookup('RU');
/// print(country?['ru']); // Россия
/// print(country?['en']); // Russian Federation
/// ```
Map<String, String>? exampleCountryLookup(String code) {
  final country = countriesByCode[code.toUpperCase()];
  if (country == null) return null;

  return {
    'code': country.code,
    'ru': country.ru,
    'en': country.en,
  };
}

List<CountryName> _buildCountries() {
  final enList = (jsonDecode(_countriesEnJson) as List)
      .cast<Map<String, dynamic>>();
  final ruList = (jsonDecode(_countriesRuJson) as List)
      .cast<Map<String, dynamic>>();

  final ruByCode = <String, String>{
    for (final item in ruList)
      (item['alpha2'] as String).toUpperCase(): item['name'] as String,
  };

  final countries = enList.map((item) {
    final code = (item['alpha2'] as String).toUpperCase();
    final en = item['name'] as String;
    final ru = ruByCode[code] ?? en;

    final phoneCode = item['phoneCode'] as String;
    final phoneDigits = item['phoneDigits'] as int;
    final phoneMask = item['phoneMask'] as String;
    final phoneGroupSizes = (item['phoneGroupSizes'] as List).cast<int>();
    final phoneGroupSeparators = (item['phoneGroupSeparators'] as List).cast<String>();

    return CountryName(code: code, en: en, ru: ru, phoneCode: phoneCode, phoneDigits: phoneDigits, phoneMask: phoneMask, phoneGroupSizes: phoneGroupSizes, phoneGroupSeparators: phoneGroupSeparators);
  }).toList();

  countries.sort((a, b) => a.en.compareTo(b.en));
  return countries;
}

const String _countriesEnJson = '''[
{"id": 4, "alpha2": "af", "alpha3": "afg", "name": "Afghanistan", "phoneCode": "+93", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 8, "alpha2": "al", "alpha3": "alb", "name": "Albania", "phoneCode": "+355", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 12, "alpha2": "dz", "alpha3": "dza", "name": "Algeria", "phoneCode": "+213", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 20, "alpha2": "ad", "alpha3": "and", "name": "Andorra", "phoneCode": "+376", "phoneDigits": 6, "phoneMask": "######", "phoneGroupSizes": [6], "phoneGroupSeparators": ["", ""]}
{"id": 24, "alpha2": "ao", "alpha3": "ago", "name": "Angola", "phoneCode": "+244", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 28, "alpha2": "ag", "alpha3": "atg", "name": "Antigua and Barbuda", "phoneCode": "+1268", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 32, "alpha2": "ar", "alpha3": "arg", "name": "Argentina", "phoneCode": "+54", "phoneDigits": 10, "phoneMask": "(##) ####-####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 51, "alpha2": "am", "alpha3": "arm", "name": "Armenia", "phoneCode": "+374", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 36, "alpha2": "au", "alpha3": "aus", "name": "Australia", "phoneCode": "+61", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 40, "alpha2": "at", "alpha3": "aut", "name": "Austria", "phoneCode": "+43", "phoneDigits": 10, "phoneMask": "### ######", "phoneGroupSizes": [3, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 31, "alpha2": "az", "alpha3": "aze", "name": "Azerbaijan", "phoneCode": "+994", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 44, "alpha2": "bs", "alpha3": "bhs", "name": "Bahamas", "phoneCode": "+1242", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 48, "alpha2": "bh", "alpha3": "bhr", "name": "Bahrain", "phoneCode": "+973", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 50, "alpha2": "bd", "alpha3": "bgd", "name": "Bangladesh", "phoneCode": "+880", "phoneDigits": 10, "phoneMask": "####-######", "phoneGroupSizes": [4, 6], "phoneGroupSeparators": ["", "-", ""]}
{"id": 52, "alpha2": "bb", "alpha3": "brb", "name": "Barbados", "phoneCode": "+1246", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 112, "alpha2": "by", "alpha3": "blr", "name": "Belarus", "phoneCode": "+375", "phoneDigits": 9, "phoneMask": "## ###-##-##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", "-", "-", ""]}
{"id": 56, "alpha2": "be", "alpha3": "bel", "name": "Belgium", "phoneCode": "+32", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 84, "alpha2": "bz", "alpha3": "blz", "name": "Belize", "phoneCode": "+501", "phoneDigits": 7, "phoneMask": "###-####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", "-", ""]}
{"id": 204, "alpha2": "bj", "alpha3": "ben", "name": "Benin", "phoneCode": "+229", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 64, "alpha2": "bt", "alpha3": "btn", "name": "Bhutan", "phoneCode": "+975", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 68, "alpha2": "bo", "alpha3": "bol", "name": "Bolivia, Plurinational State of", "phoneCode": "+591", "phoneDigits": 8, "phoneMask": "########", "phoneGroupSizes": [8], "phoneGroupSeparators": ["", ""]}
{"id": 70, "alpha2": "ba", "alpha3": "bih", "name": "Bosnia and Herzegovina", "phoneCode": "+387", "phoneDigits": 8, "phoneMask": "## ###-###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", "-", ""]}
{"id": 72, "alpha2": "bw", "alpha3": "bwa", "name": "Botswana", "phoneCode": "+267", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 76, "alpha2": "br", "alpha3": "bra", "name": "Brazil", "phoneCode": "+55", "phoneDigits": 11, "phoneMask": "(##) #####-####", "phoneGroupSizes": [2, 5, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 96, "alpha2": "bn", "alpha3": "brn", "name": "Brunei Darussalam", "phoneCode": "+673", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 100, "alpha2": "bg", "alpha3": "bgr", "name": "Bulgaria", "phoneCode": "+359", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 854, "alpha2": "bf", "alpha3": "bfa", "name": "Burkina Faso", "phoneCode": "+226", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 108, "alpha2": "bi", "alpha3": "bdi", "name": "Burundi", "phoneCode": "+257", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 132, "alpha2": "cv", "alpha3": "cpv", "name": "Cabo Verde", "phoneCode": "+238", "phoneDigits": 7, "phoneMask": "### ## ##", "phoneGroupSizes": [3, 2, 2], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 116, "alpha2": "kh", "alpha3": "khm", "name": "Cambodia", "phoneCode": "+855", "phoneDigits": 9, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 120, "alpha2": "cm", "alpha3": "cmr", "name": "Cameroon", "phoneCode": "+237", "phoneDigits": 9, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 124, "alpha2": "ca", "alpha3": "can", "name": "Canada", "phoneCode": "+1", "phoneDigits": 10, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 140, "alpha2": "cf", "alpha3": "caf", "name": "Central African Republic", "phoneCode": "+236", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 148, "alpha2": "td", "alpha3": "tcd", "name": "Chad", "phoneCode": "+235", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 152, "alpha2": "cl", "alpha3": "chl", "name": "Chile", "phoneCode": "+56", "phoneDigits": 9, "phoneMask": "# #### ####", "phoneGroupSizes": [1, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 156, "alpha2": "cn", "alpha3": "chn", "name": "China", "phoneCode": "+86", "phoneDigits": 11, "phoneMask": "### #### ####", "phoneGroupSizes": [3, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 170, "alpha2": "co", "alpha3": "col", "name": "Colombia", "phoneCode": "+57", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 174, "alpha2": "km", "alpha3": "com", "name": "Comoros", "phoneCode": "+269", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 178, "alpha2": "cg", "alpha3": "cog", "name": "Congo", "phoneCode": "+242", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 180, "alpha2": "cd", "alpha3": "cod", "name": "Congo, Democratic Republic of the", "phoneCode": "+243", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 188, "alpha2": "cr", "alpha3": "cri", "name": "Costa Rica", "phoneCode": "+506", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 384, "alpha2": "ci", "alpha3": "civ", "name": "Côte d'Ivoire", "phoneCode": "+225", "phoneDigits": 10, "phoneMask": "## ## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", " ", ""]}
{"id": 191, "alpha2": "hr", "alpha3": "hrv", "name": "Croatia", "phoneCode": "+385", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 192, "alpha2": "cu", "alpha3": "cub", "name": "Cuba", "phoneCode": "+53", "phoneDigits": 8, "phoneMask": "########", "phoneGroupSizes": [8], "phoneGroupSeparators": ["", ""]}
{"id": 196, "alpha2": "cy", "alpha3": "cyp", "name": "Cyprus", "phoneCode": "+357", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 203, "alpha2": "cz", "alpha3": "cze", "name": "Czechia", "phoneCode": "+420", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 208, "alpha2": "dk", "alpha3": "dnk", "name": "Denmark", "phoneCode": "+45", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 262, "alpha2": "dj", "alpha3": "dji", "name": "Djibouti", "phoneCode": "+253", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 212, "alpha2": "dm", "alpha3": "dma", "name": "Dominica", "phoneCode": "+1767", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 214, "alpha2": "do", "alpha3": "dom", "name": "Dominican Republic", "phoneCode": "+1809", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 218, "alpha2": "ec", "alpha3": "ecu", "name": "Ecuador", "phoneCode": "+593", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 818, "alpha2": "eg", "alpha3": "egy", "name": "Egypt", "phoneCode": "+20", "phoneDigits": 10, "phoneMask": "## #### ####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 222, "alpha2": "sv", "alpha3": "slv", "name": "El Salvador", "phoneCode": "+503", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 226, "alpha2": "gq", "alpha3": "gnq", "name": "Equatorial Guinea", "phoneCode": "+240", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 232, "alpha2": "er", "alpha3": "eri", "name": "Eritrea", "phoneCode": "+291", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 233, "alpha2": "ee", "alpha3": "est", "name": "Estonia", "phoneCode": "+372", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 748, "alpha2": "sz", "alpha3": "swz", "name": "Eswatini", "phoneCode": "+268", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 231, "alpha2": "et", "alpha3": "eth", "name": "Ethiopia", "phoneCode": "+251", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 242, "alpha2": "fj", "alpha3": "fji", "name": "Fiji", "phoneCode": "+679", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 246, "alpha2": "fi", "alpha3": "fin", "name": "Finland", "phoneCode": "+358", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 250, "alpha2": "fr", "alpha3": "fra", "name": "France", "phoneCode": "+33", "phoneDigits": 9, "phoneMask": "# ## ## ## ##", "phoneGroupSizes": [1, 2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", " ", ""]}
{"id": 266, "alpha2": "ga", "alpha3": "gab", "name": "Gabon", "phoneCode": "+241", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 270, "alpha2": "gm", "alpha3": "gmb", "name": "Gambia", "phoneCode": "+220", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 268, "alpha2": "ge", "alpha3": "geo", "name": "Georgia", "phoneCode": "+995", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 276, "alpha2": "de", "alpha3": "deu", "name": "Germany", "phoneCode": "+49", "phoneDigits": 10, "phoneMask": "#### #######", "phoneGroupSizes": [4, 7], "phoneGroupSeparators": ["", " ", ""]}
{"id": 288, "alpha2": "gh", "alpha3": "gha", "name": "Ghana", "phoneCode": "+233", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 300, "alpha2": "gr", "alpha3": "grc", "name": "Greece", "phoneCode": "+30", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 308, "alpha2": "gd", "alpha3": "grd", "name": "Grenada", "phoneCode": "+1473", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 320, "alpha2": "gt", "alpha3": "gtm", "name": "Guatemala", "phoneCode": "+502", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 324, "alpha2": "gn", "alpha3": "gin", "name": "Guinea", "phoneCode": "+224", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 624, "alpha2": "gw", "alpha3": "gnb", "name": "Guinea-Bissau", "phoneCode": "+245", "phoneDigits": 9, "phoneMask": "### ######", "phoneGroupSizes": [3, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 328, "alpha2": "gy", "alpha3": "guy", "name": "Guyana", "phoneCode": "+592", "phoneDigits": 7, "phoneMask": "###-####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", "-", ""]}
{"id": 332, "alpha2": "ht", "alpha3": "hti", "name": "Haiti", "phoneCode": "+509", "phoneDigits": 8, "phoneMask": "## ## ####", "phoneGroupSizes": [2, 2, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 340, "alpha2": "hn", "alpha3": "hnd", "name": "Honduras", "phoneCode": "+504", "phoneDigits": 8, "phoneMask": "####-####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", "-", ""]}
{"id": 348, "alpha2": "hu", "alpha3": "hun", "name": "Hungary", "phoneCode": "+36", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 352, "alpha2": "is", "alpha3": "isl", "name": "Iceland", "phoneCode": "+354", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 356, "alpha2": "in", "alpha3": "ind", "name": "India", "phoneCode": "+91", "phoneDigits": 10, "phoneMask": "##### #####", "phoneGroupSizes": [5, 5], "phoneGroupSeparators": ["", " ", ""]}
{"id": 360, "alpha2": "id", "alpha3": "idn", "name": "Indonesia", "phoneCode": "+62", "phoneDigits": 10, "phoneMask": "### #### ####", "phoneGroupSizes": [3, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 364, "alpha2": "ir", "alpha3": "irn", "name": "Iran, Islamic Republic of", "phoneCode": "+98", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 368, "alpha2": "iq", "alpha3": "irq", "name": "Iraq", "phoneCode": "+964", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 372, "alpha2": "ie", "alpha3": "irl", "name": "Ireland", "phoneCode": "+353", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 376, "alpha2": "il", "alpha3": "isr", "name": "Israel", "phoneCode": "+972", "phoneDigits": 9, "phoneMask": "##-###-####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", "-", "-", ""]}
{"id": 380, "alpha2": "it", "alpha3": "ita", "name": "Italy", "phoneCode": "+39", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 388, "alpha2": "jm", "alpha3": "jam", "name": "Jamaica", "phoneCode": "+1876", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 392, "alpha2": "jp", "alpha3": "jpn", "name": "Japan", "phoneCode": "+81", "phoneDigits": 10, "phoneMask": "##-####-####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", "-", "-", ""]}
{"id": 400, "alpha2": "jo", "alpha3": "jor", "name": "Jordan", "phoneCode": "+962", "phoneDigits": 9, "phoneMask": "# #### ####", "phoneGroupSizes": [1, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 398, "alpha2": "kz", "alpha3": "kaz", "name": "Kazakhstan", "phoneCode": "+7", "phoneDigits": 10, "phoneMask": "(###) ###-##-##", "phoneGroupSizes": [3, 3, 2, 2], "phoneGroupSeparators": ["(", ") ", "-", "-", ""]}
{"id": 404, "alpha2": "ke", "alpha3": "ken", "name": "Kenya", "phoneCode": "+254", "phoneDigits": 9, "phoneMask": "### ######", "phoneGroupSizes": [3, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 296, "alpha2": "ki", "alpha3": "kir", "name": "Kiribati", "phoneCode": "+686", "phoneDigits": 8, "phoneMask": "## ######", "phoneGroupSizes": [2, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 408, "alpha2": "kp", "alpha3": "prk", "name": "Korea, Democratic People's Republic of", "phoneCode": "+850", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 410, "alpha2": "kr", "alpha3": "kor", "name": "Korea, Republic of", "phoneCode": "+82", "phoneDigits": 10, "phoneMask": "##-####-####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", "-", "-", ""]}
{"id": 414, "alpha2": "kw", "alpha3": "kwt", "name": "Kuwait", "phoneCode": "+965", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 417, "alpha2": "kg", "alpha3": "kgz", "name": "Kyrgyzstan", "phoneCode": "+996", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 418, "alpha2": "la", "alpha3": "lao", "name": "Lao People's Democratic Republic", "phoneCode": "+856", "phoneDigits": 9, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 428, "alpha2": "lv", "alpha3": "lva", "name": "Latvia", "phoneCode": "+371", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 422, "alpha2": "lb", "alpha3": "lbn", "name": "Lebanon", "phoneCode": "+961", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 426, "alpha2": "ls", "alpha3": "lso", "name": "Lesotho", "phoneCode": "+266", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 430, "alpha2": "lr", "alpha3": "lbr", "name": "Liberia", "phoneCode": "+231", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 434, "alpha2": "ly", "alpha3": "lby", "name": "Libya", "phoneCode": "+218", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 438, "alpha2": "li", "alpha3": "lie", "name": "Liechtenstein", "phoneCode": "+423", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 440, "alpha2": "lt", "alpha3": "ltu", "name": "Lithuania", "phoneCode": "+370", "phoneDigits": 8, "phoneMask": "### #####", "phoneGroupSizes": [3, 5], "phoneGroupSeparators": ["", " ", ""]}
{"id": 442, "alpha2": "lu", "alpha3": "lux", "name": "Luxembourg", "phoneCode": "+352", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 450, "alpha2": "mg", "alpha3": "mdg", "name": "Madagascar", "phoneCode": "+261", "phoneDigits": 9, "phoneMask": "## ## ### ##", "phoneGroupSizes": [2, 2, 3, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 454, "alpha2": "mw", "alpha3": "mwi", "name": "Malawi", "phoneCode": "+265", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 458, "alpha2": "my", "alpha3": "mys", "name": "Malaysia", "phoneCode": "+60", "phoneDigits": 10, "phoneMask": "##-#### ####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", "-", " ", ""]}
{"id": 462, "alpha2": "mv", "alpha3": "mdv", "name": "Maldives", "phoneCode": "+960", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 466, "alpha2": "ml", "alpha3": "mli", "name": "Mali", "phoneCode": "+223", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 470, "alpha2": "mt", "alpha3": "mlt", "name": "Malta", "phoneCode": "+356", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 584, "alpha2": "mh", "alpha3": "mhl", "name": "Marshall Islands", "phoneCode": "+692", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 478, "alpha2": "mr", "alpha3": "mrt", "name": "Mauritania", "phoneCode": "+222", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 480, "alpha2": "mu", "alpha3": "mus", "name": "Mauritius", "phoneCode": "+230", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 484, "alpha2": "mx", "alpha3": "mex", "name": "Mexico", "phoneCode": "+52", "phoneDigits": 10, "phoneMask": "## #### ####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 583, "alpha2": "fm", "alpha3": "fsm", "name": "Micronesia, Federated States of", "phoneCode": "+691", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 498, "alpha2": "md", "alpha3": "mda", "name": "Moldova, Republic of", "phoneCode": "+373", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 492, "alpha2": "mc", "alpha3": "mco", "name": "Monaco", "phoneCode": "+377", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 496, "alpha2": "mn", "alpha3": "mng", "name": "Mongolia", "phoneCode": "+976", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 499, "alpha2": "me", "alpha3": "mne", "name": "Montenegro", "phoneCode": "+382", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 504, "alpha2": "ma", "alpha3": "mar", "name": "Morocco", "phoneCode": "+212", "phoneDigits": 9, "phoneMask": "###-###-###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", "-", "-", ""]}
{"id": 508, "alpha2": "mz", "alpha3": "moz", "name": "Mozambique", "phoneCode": "+258", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 104, "alpha2": "mm", "alpha3": "mmr", "name": "Myanmar", "phoneCode": "+95", "phoneDigits": 9, "phoneMask": "# ### ####", "phoneGroupSizes": [1, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 516, "alpha2": "na", "alpha3": "nam", "name": "Namibia", "phoneCode": "+264", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 520, "alpha2": "nr", "alpha3": "nru", "name": "Nauru", "phoneCode": "+674", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 524, "alpha2": "np", "alpha3": "npl", "name": "Nepal", "phoneCode": "+977", "phoneDigits": 10, "phoneMask": "##-### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", "-", " ", ""]}
{"id": 528, "alpha2": "nl", "alpha3": "nld", "name": "Netherlands", "phoneCode": "+31", "phoneDigits": 9, "phoneMask": "# ## ## ## ##", "phoneGroupSizes": [1, 2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", " ", ""]}
{"id": 554, "alpha2": "nz", "alpha3": "nzl", "name": "New Zealand", "phoneCode": "+64", "phoneDigits": 9, "phoneMask": "##-### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", "-", " ", ""]}
{"id": 558, "alpha2": "ni", "alpha3": "nic", "name": "Nicaragua", "phoneCode": "+505", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 562, "alpha2": "ne", "alpha3": "ner", "name": "Niger", "phoneCode": "+227", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 566, "alpha2": "ng", "alpha3": "nga", "name": "Nigeria", "phoneCode": "+234", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 807, "alpha2": "mk", "alpha3": "mkd", "name": "North Macedonia", "phoneCode": "+389", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 578, "alpha2": "no", "alpha3": "nor", "name": "Norway", "phoneCode": "+47", "phoneDigits": 8, "phoneMask": "### ## ###", "phoneGroupSizes": [3, 2, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 512, "alpha2": "om", "alpha3": "omn", "name": "Oman", "phoneCode": "+968", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 586, "alpha2": "pk", "alpha3": "pak", "name": "Pakistan", "phoneCode": "+92", "phoneDigits": 10, "phoneMask": "### #######", "phoneGroupSizes": [3, 7], "phoneGroupSeparators": ["", " ", ""]}
{"id": 585, "alpha2": "pw", "alpha3": "plw", "name": "Palau", "phoneCode": "+680", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 591, "alpha2": "pa", "alpha3": "pan", "name": "Panama", "phoneCode": "+507", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 598, "alpha2": "pg", "alpha3": "png", "name": "Papua New Guinea", "phoneCode": "+675", "phoneDigits": 8, "phoneMask": "### ## ###", "phoneGroupSizes": [3, 2, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 600, "alpha2": "py", "alpha3": "pry", "name": "Paraguay", "phoneCode": "+595", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 604, "alpha2": "pe", "alpha3": "per", "name": "Peru", "phoneCode": "+51", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 608, "alpha2": "ph", "alpha3": "phl", "name": "Philippines", "phoneCode": "+63", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 616, "alpha2": "pl", "alpha3": "pol", "name": "Poland", "phoneCode": "+48", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 620, "alpha2": "pt", "alpha3": "prt", "name": "Portugal", "phoneCode": "+351", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 634, "alpha2": "qa", "alpha3": "qat", "name": "Qatar", "phoneCode": "+974", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 642, "alpha2": "ro", "alpha3": "rou", "name": "Romania", "phoneCode": "+40", "phoneDigits": 10, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 643, "alpha2": "ru", "alpha3": "rus", "name": "Russian Federation", "phoneCode": "+7", "phoneDigits": 10, "phoneMask": "(###) ###-##-##", "phoneGroupSizes": [3, 3, 2, 2], "phoneGroupSeparators": ["(", ") ", "-", "-", ""]}
{"id": 646, "alpha2": "rw", "alpha3": "rwa", "name": "Rwanda", "phoneCode": "+250", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 659, "alpha2": "kn", "alpha3": "kna", "name": "Saint Kitts and Nevis", "phoneCode": "+1869", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 662, "alpha2": "lc", "alpha3": "lca", "name": "Saint Lucia", "phoneCode": "+1758", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 670, "alpha2": "vc", "alpha3": "vct", "name": "Saint Vincent and the Grenadines", "phoneCode": "+1784", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 882, "alpha2": "ws", "alpha3": "wsm", "name": "Samoa", "phoneCode": "+685", "phoneDigits": 7, "phoneMask": "## #####", "phoneGroupSizes": [2, 5], "phoneGroupSeparators": ["", " ", ""]}
{"id": 674, "alpha2": "sm", "alpha3": "smr", "name": "San Marino", "phoneCode": "+378", "phoneDigits": 10, "phoneMask": "## ## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", " ", ""]}
{"id": 678, "alpha2": "st", "alpha3": "stp", "name": "Sao Tome and Principe", "phoneCode": "+239", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 682, "alpha2": "sa", "alpha3": "sau", "name": "Saudi Arabia", "phoneCode": "+966", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 686, "alpha2": "sn", "alpha3": "sen", "name": "Senegal", "phoneCode": "+221", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 688, "alpha2": "rs", "alpha3": "srb", "name": "Serbia", "phoneCode": "+381", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 690, "alpha2": "sc", "alpha3": "syc", "name": "Seychelles", "phoneCode": "+248", "phoneDigits": 7, "phoneMask": "# ### ###", "phoneGroupSizes": [1, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 694, "alpha2": "sl", "alpha3": "sle", "name": "Sierra Leone", "phoneCode": "+232", "phoneDigits": 8, "phoneMask": "## ######", "phoneGroupSizes": [2, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 702, "alpha2": "sg", "alpha3": "sgp", "name": "Singapore", "phoneCode": "+65", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 703, "alpha2": "sk", "alpha3": "svk", "name": "Slovakia", "phoneCode": "+421", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 705, "alpha2": "si", "alpha3": "svn", "name": "Slovenia", "phoneCode": "+386", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 90, "alpha2": "sb", "alpha3": "slb", "name": "Solomon Islands", "phoneCode": "+677", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 706, "alpha2": "so", "alpha3": "som", "name": "Somalia", "phoneCode": "+252", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 710, "alpha2": "za", "alpha3": "zaf", "name": "South Africa", "phoneCode": "+27", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 728, "alpha2": "ss", "alpha3": "ssd", "name": "South Sudan", "phoneCode": "+211", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 724, "alpha2": "es", "alpha3": "esp", "name": "Spain", "phoneCode": "+34", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 144, "alpha2": "lk", "alpha3": "lka", "name": "Sri Lanka", "phoneCode": "+94", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 729, "alpha2": "sd", "alpha3": "sdn", "name": "Sudan", "phoneCode": "+249", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 740, "alpha2": "sr", "alpha3": "sur", "name": "Suriname", "phoneCode": "+597", "phoneDigits": 7, "phoneMask": "###-####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", "-", ""]}
{"id": 752, "alpha2": "se", "alpha3": "swe", "name": "Sweden", "phoneCode": "+46", "phoneDigits": 9, "phoneMask": "##-### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", "-", " ", " ", ""]}
{"id": 756, "alpha2": "ch", "alpha3": "che", "name": "Switzerland", "phoneCode": "+41", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 760, "alpha2": "sy", "alpha3": "syr", "name": "Syrian Arab Republic", "phoneCode": "+963", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 762, "alpha2": "tj", "alpha3": "tjk", "name": "Tajikistan", "phoneCode": "+992", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 834, "alpha2": "tz", "alpha3": "tza", "name": "Tanzania, United Republic of", "phoneCode": "+255", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 764, "alpha2": "th", "alpha3": "tha", "name": "Thailand", "phoneCode": "+66", "phoneDigits": 9, "phoneMask": "##-### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", "-", " ", ""]}
{"id": 626, "alpha2": "tl", "alpha3": "tls", "name": "Timor-Leste", "phoneCode": "+670", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 768, "alpha2": "tg", "alpha3": "tgo", "name": "Togo", "phoneCode": "+228", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 776, "alpha2": "to", "alpha3": "ton", "name": "Tonga", "phoneCode": "+676", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 780, "alpha2": "tt", "alpha3": "tto", "name": "Trinidad and Tobago", "phoneCode": "+1868", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 788, "alpha2": "tn", "alpha3": "tun", "name": "Tunisia", "phoneCode": "+216", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 792, "alpha2": "tr", "alpha3": "tur", "name": "Türkiye", "phoneCode": "+90", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 795, "alpha2": "tm", "alpha3": "tkm", "name": "Turkmenistan", "phoneCode": "+993", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 798, "alpha2": "tv", "alpha3": "tuv", "name": "Tuvalu", "phoneCode": "+688", "phoneDigits": 6, "phoneMask": "######", "phoneGroupSizes": [6], "phoneGroupSeparators": ["", ""]}
{"id": 800, "alpha2": "ug", "alpha3": "uga", "name": "Uganda", "phoneCode": "+256", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 804, "alpha2": "ua", "alpha3": "ukr", "name": "Ukraine", "phoneCode": "+380", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 784, "alpha2": "ae", "alpha3": "are", "name": "United Arab Emirates", "phoneCode": "+971", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 826, "alpha2": "gb", "alpha3": "gbr", "name": "United Kingdom of Great Britain and Northern Ireland", "phoneCode": "+44", "phoneDigits": 10, "phoneMask": "#### ######", "phoneGroupSizes": [4, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 840, "alpha2": "us", "alpha3": "usa", "name": "United States of America", "phoneCode": "+1", "phoneDigits": 10, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 858, "alpha2": "uy", "alpha3": "ury", "name": "Uruguay", "phoneCode": "+598", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 860, "alpha2": "uz", "alpha3": "uzb", "name": "Uzbekistan", "phoneCode": "+998", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 548, "alpha2": "vu", "alpha3": "vut", "name": "Vanuatu", "phoneCode": "+678", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 862, "alpha2": "ve", "alpha3": "ven", "name": "Venezuela, Bolivarian Republic of", "phoneCode": "+58", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 704, "alpha2": "vn", "alpha3": "vnm", "name": "Viet Nam", "phoneCode": "+84", "phoneDigits": 10, "phoneMask": "## #### ####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 887, "alpha2": "ye", "alpha3": "yem", "name": "Yemen", "phoneCode": "+967", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 894, "alpha2": "zm", "alpha3": "zmb", "name": "Zambia", "phoneCode": "+260", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 716, "alpha2": "zw", "alpha3": "zwe", "name": "Zimbabwe", "phoneCode": "+263", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
]''';

const String _countriesRuJson = '''[
{"id": 36, "alpha2": "au", "alpha3": "aus", "name": "Австралия", "phoneCode": "+61", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 40, "alpha2": "at", "alpha3": "aut", "name": "Австрия", "phoneCode": "+43", "phoneDigits": 10, "phoneMask": "### ######", "phoneGroupSizes": [3, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 31, "alpha2": "az", "alpha3": "aze", "name": "Азербайджан", "phoneCode": "+994", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 8, "alpha2": "al", "alpha3": "alb", "name": "Албания", "phoneCode": "+355", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 12, "alpha2": "dz", "alpha3": "dza", "name": "Алжир", "phoneCode": "+213", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 24, "alpha2": "ao", "alpha3": "ago", "name": "Ангола", "phoneCode": "+244", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 20, "alpha2": "ad", "alpha3": "and", "name": "Андорра", "phoneCode": "+376", "phoneDigits": 6, "phoneMask": "######", "phoneGroupSizes": [6], "phoneGroupSeparators": ["", ""]}
{"id": 28, "alpha2": "ag", "alpha3": "atg", "name": "Антигуа и Барбуда", "phoneCode": "+1268", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 32, "alpha2": "ar", "alpha3": "arg", "name": "Аргентина", "phoneCode": "+54", "phoneDigits": 10, "phoneMask": "(##) ####-####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 51, "alpha2": "am", "alpha3": "arm", "name": "Армения", "phoneCode": "+374", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 4, "alpha2": "af", "alpha3": "afg", "name": "Афганистан", "phoneCode": "+93", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 44, "alpha2": "bs", "alpha3": "bhs", "name": "Багамские Острова", "phoneCode": "+1242", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 50, "alpha2": "bd", "alpha3": "bgd", "name": "Бангладеш", "phoneCode": "+880", "phoneDigits": 10, "phoneMask": "####-######", "phoneGroupSizes": [4, 6], "phoneGroupSeparators": ["", "-", ""]}
{"id": 52, "alpha2": "bb", "alpha3": "brb", "name": "Барбадос", "phoneCode": "+1246", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 48, "alpha2": "bh", "alpha3": "bhr", "name": "Бахрейн", "phoneCode": "+973", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 84, "alpha2": "bz", "alpha3": "blz", "name": "Белиз", "phoneCode": "+501", "phoneDigits": 7, "phoneMask": "###-####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", "-", ""]}
{"id": 112, "alpha2": "by", "alpha3": "blr", "name": "Беларусь", "phoneCode": "+375", "phoneDigits": 9, "phoneMask": "## ###-##-##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", "-", "-", ""]}
{"id": 56, "alpha2": "be", "alpha3": "bel", "name": "Бельгия", "phoneCode": "+32", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 204, "alpha2": "bj", "alpha3": "ben", "name": "Бенин", "phoneCode": "+229", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 100, "alpha2": "bg", "alpha3": "bgr", "name": "Болгария", "phoneCode": "+359", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 68, "alpha2": "bo", "alpha3": "bol", "name": "Боливия", "phoneCode": "+591", "phoneDigits": 8, "phoneMask": "########", "phoneGroupSizes": [8], "phoneGroupSeparators": ["", ""]}
{"id": 70, "alpha2": "ba", "alpha3": "bih", "name": "Босния и Герцеговина", "phoneCode": "+387", "phoneDigits": 8, "phoneMask": "## ###-###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", "-", ""]}
{"id": 72, "alpha2": "bw", "alpha3": "bwa", "name": "Ботсвана", "phoneCode": "+267", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 76, "alpha2": "br", "alpha3": "bra", "name": "Бразилия", "phoneCode": "+55", "phoneDigits": 11, "phoneMask": "(##) #####-####", "phoneGroupSizes": [2, 5, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 96, "alpha2": "bn", "alpha3": "brn", "name": "Бруней", "phoneCode": "+673", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 854, "alpha2": "bf", "alpha3": "bfa", "name": "Буркина-Фасо", "phoneCode": "+226", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 108, "alpha2": "bi", "alpha3": "bdi", "name": "Бурунди", "phoneCode": "+257", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 64, "alpha2": "bt", "alpha3": "btn", "name": "Бутан", "phoneCode": "+975", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 548, "alpha2": "vu", "alpha3": "vut", "name": "Вануату", "phoneCode": "+678", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 826, "alpha2": "gb", "alpha3": "gbr", "name": "Великобритания", "phoneCode": "+44", "phoneDigits": 10, "phoneMask": "#### ######", "phoneGroupSizes": [4, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 348, "alpha2": "hu", "alpha3": "hun", "name": "Венгрия", "phoneCode": "+36", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 862, "alpha2": "ve", "alpha3": "ven", "name": "Венесуэла", "phoneCode": "+58", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 626, "alpha2": "tl", "alpha3": "tls", "name": "Восточный Тимор", "phoneCode": "+670", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 704, "alpha2": "vn", "alpha3": "vnm", "name": "Вьетнам", "phoneCode": "+84", "phoneDigits": 10, "phoneMask": "## #### ####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 266, "alpha2": "ga", "alpha3": "gab", "name": "Габон", "phoneCode": "+241", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 332, "alpha2": "ht", "alpha3": "hti", "name": "Гаити", "phoneCode": "+509", "phoneDigits": 8, "phoneMask": "## ## ####", "phoneGroupSizes": [2, 2, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 328, "alpha2": "gy", "alpha3": "guy", "name": "Гайана", "phoneCode": "+592", "phoneDigits": 7, "phoneMask": "###-####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", "-", ""]}
{"id": 270, "alpha2": "gm", "alpha3": "gmb", "name": "Гамбия", "phoneCode": "+220", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 288, "alpha2": "gh", "alpha3": "gha", "name": "Гана", "phoneCode": "+233", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 320, "alpha2": "gt", "alpha3": "gtm", "name": "Гватемала", "phoneCode": "+502", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 324, "alpha2": "gn", "alpha3": "gin", "name": "Гвинея", "phoneCode": "+224", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 624, "alpha2": "gw", "alpha3": "gnb", "name": "Гвинея-Бисау", "phoneCode": "+245", "phoneDigits": 9, "phoneMask": "### ######", "phoneGroupSizes": [3, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 276, "alpha2": "de", "alpha3": "deu", "name": "Германия", "phoneCode": "+49", "phoneDigits": 10, "phoneMask": "#### #######", "phoneGroupSizes": [4, 7], "phoneGroupSeparators": ["", " ", ""]}
{"id": 340, "alpha2": "hn", "alpha3": "hnd", "name": "Гондурас", "phoneCode": "+504", "phoneDigits": 8, "phoneMask": "####-####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", "-", ""]}
{"id": 308, "alpha2": "gd", "alpha3": "grd", "name": "Гренада", "phoneCode": "+1473", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 300, "alpha2": "gr", "alpha3": "grc", "name": "Греция", "phoneCode": "+30", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 268, "alpha2": "ge", "alpha3": "geo", "name": "Грузия", "phoneCode": "+995", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 208, "alpha2": "dk", "alpha3": "dnk", "name": "Дания", "phoneCode": "+45", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 262, "alpha2": "dj", "alpha3": "dji", "name": "Джибути", "phoneCode": "+253", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 212, "alpha2": "dm", "alpha3": "dma", "name": "Доминика", "phoneCode": "+1767", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 214, "alpha2": "do", "alpha3": "dom", "name": "Доминиканская Республика", "phoneCode": "+1809", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 180, "alpha2": "cd", "alpha3": "cod", "name": "ДР Конго", "phoneCode": "+243", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 818, "alpha2": "eg", "alpha3": "egy", "name": "Египет", "phoneCode": "+20", "phoneDigits": 10, "phoneMask": "## #### ####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 894, "alpha2": "zm", "alpha3": "zmb", "name": "Замбия", "phoneCode": "+260", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 716, "alpha2": "zw", "alpha3": "zwe", "name": "Зимбабве", "phoneCode": "+263", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 376, "alpha2": "il", "alpha3": "isr", "name": "Израиль", "phoneCode": "+972", "phoneDigits": 9, "phoneMask": "##-###-####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", "-", "-", ""]}
{"id": 356, "alpha2": "in", "alpha3": "ind", "name": "Индия", "phoneCode": "+91", "phoneDigits": 10, "phoneMask": "##### #####", "phoneGroupSizes": [5, 5], "phoneGroupSeparators": ["", " ", ""]}
{"id": 360, "alpha2": "id", "alpha3": "idn", "name": "Индонезия", "phoneCode": "+62", "phoneDigits": 10, "phoneMask": "### #### ####", "phoneGroupSizes": [3, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 400, "alpha2": "jo", "alpha3": "jor", "name": "Иордания", "phoneCode": "+962", "phoneDigits": 9, "phoneMask": "# #### ####", "phoneGroupSizes": [1, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 368, "alpha2": "iq", "alpha3": "irq", "name": "Ирак", "phoneCode": "+964", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 364, "alpha2": "ir", "alpha3": "irn", "name": "Иран", "phoneCode": "+98", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 372, "alpha2": "ie", "alpha3": "irl", "name": "Ирландия", "phoneCode": "+353", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 352, "alpha2": "is", "alpha3": "isl", "name": "Исландия", "phoneCode": "+354", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 724, "alpha2": "es", "alpha3": "esp", "name": "Испания", "phoneCode": "+34", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 380, "alpha2": "it", "alpha3": "ita", "name": "Италия", "phoneCode": "+39", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 887, "alpha2": "ye", "alpha3": "yem", "name": "Йемен", "phoneCode": "+967", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 132, "alpha2": "cv", "alpha3": "cpv", "name": "Кабо-Верде", "phoneCode": "+238", "phoneDigits": 7, "phoneMask": "### ## ##", "phoneGroupSizes": [3, 2, 2], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 398, "alpha2": "kz", "alpha3": "kaz", "name": "Казахстан", "phoneCode": "+7", "phoneDigits": 10, "phoneMask": "(###) ###-##-##", "phoneGroupSizes": [3, 3, 2, 2], "phoneGroupSeparators": ["(", ") ", "-", "-", ""]}
{"id": 116, "alpha2": "kh", "alpha3": "khm", "name": "Камбоджа", "phoneCode": "+855", "phoneDigits": 9, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 120, "alpha2": "cm", "alpha3": "cmr", "name": "Камерун", "phoneCode": "+237", "phoneDigits": 9, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 124, "alpha2": "ca", "alpha3": "can", "name": "Канада", "phoneCode": "+1", "phoneDigits": 10, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 634, "alpha2": "qa", "alpha3": "qat", "name": "Катар", "phoneCode": "+974", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 404, "alpha2": "ke", "alpha3": "ken", "name": "Кения", "phoneCode": "+254", "phoneDigits": 9, "phoneMask": "### ######", "phoneGroupSizes": [3, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 196, "alpha2": "cy", "alpha3": "cyp", "name": "Кипр", "phoneCode": "+357", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 417, "alpha2": "kg", "alpha3": "kgz", "name": "Кыргызстан", "phoneCode": "+996", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 296, "alpha2": "ki", "alpha3": "kir", "name": "Кирибати", "phoneCode": "+686", "phoneDigits": 8, "phoneMask": "## ######", "phoneGroupSizes": [2, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 408, "alpha2": "kp", "alpha3": "prk", "name": "КНДР (Корейская Народно-Демократическая Республика)", "phoneCode": "+850", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 156, "alpha2": "cn", "alpha3": "chn", "name": "Китай (Китайская Народная Республика)", "phoneCode": "+86", "phoneDigits": 11, "phoneMask": "### #### ####", "phoneGroupSizes": [3, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 170, "alpha2": "co", "alpha3": "col", "name": "Колумбия", "phoneCode": "+57", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 174, "alpha2": "km", "alpha3": "com", "name": "Коморы", "phoneCode": "+269", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 188, "alpha2": "cr", "alpha3": "cri", "name": "Коста-Рика", "phoneCode": "+506", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 384, "alpha2": "ci", "alpha3": "civ", "name": "Кот-д’Ивуар", "phoneCode": "+225", "phoneDigits": 10, "phoneMask": "## ## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", " ", ""]}
{"id": 192, "alpha2": "cu", "alpha3": "cub", "name": "Куба", "phoneCode": "+53", "phoneDigits": 8, "phoneMask": "########", "phoneGroupSizes": [8], "phoneGroupSeparators": ["", ""]}
{"id": 414, "alpha2": "kw", "alpha3": "kwt", "name": "Кувейт", "phoneCode": "+965", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 418, "alpha2": "la", "alpha3": "lao", "name": "Лаос", "phoneCode": "+856", "phoneDigits": 9, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 428, "alpha2": "lv", "alpha3": "lva", "name": "Латвия", "phoneCode": "+371", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 426, "alpha2": "ls", "alpha3": "lso", "name": "Лесото", "phoneCode": "+266", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 430, "alpha2": "lr", "alpha3": "lbr", "name": "Либерия", "phoneCode": "+231", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 422, "alpha2": "lb", "alpha3": "lbn", "name": "Ливан", "phoneCode": "+961", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 434, "alpha2": "ly", "alpha3": "lby", "name": "Ливия", "phoneCode": "+218", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 440, "alpha2": "lt", "alpha3": "ltu", "name": "Литва", "phoneCode": "+370", "phoneDigits": 8, "phoneMask": "### #####", "phoneGroupSizes": [3, 5], "phoneGroupSeparators": ["", " ", ""]}
{"id": 438, "alpha2": "li", "alpha3": "lie", "name": "Лихтенштейн", "phoneCode": "+423", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 442, "alpha2": "lu", "alpha3": "lux", "name": "Люксембург", "phoneCode": "+352", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 480, "alpha2": "mu", "alpha3": "mus", "name": "Маврикий", "phoneCode": "+230", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 478, "alpha2": "mr", "alpha3": "mrt", "name": "Мавритания", "phoneCode": "+222", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 450, "alpha2": "mg", "alpha3": "mdg", "name": "Мадагаскар", "phoneCode": "+261", "phoneDigits": 9, "phoneMask": "## ## ### ##", "phoneGroupSizes": [2, 2, 3, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 807, "alpha2": "mk", "alpha3": "mkd", "name": "Северная Македония", "phoneCode": "+389", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 454, "alpha2": "mw", "alpha3": "mwi", "name": "Малави", "phoneCode": "+265", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 458, "alpha2": "my", "alpha3": "mys", "name": "Малайзия", "phoneCode": "+60", "phoneDigits": 10, "phoneMask": "##-#### ####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", "-", " ", ""]}
{"id": 466, "alpha2": "ml", "alpha3": "mli", "name": "Мали", "phoneCode": "+223", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 462, "alpha2": "mv", "alpha3": "mdv", "name": "Мальдивы", "phoneCode": "+960", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 470, "alpha2": "mt", "alpha3": "mlt", "name": "Мальта", "phoneCode": "+356", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 504, "alpha2": "ma", "alpha3": "mar", "name": "Марокко", "phoneCode": "+212", "phoneDigits": 9, "phoneMask": "###-###-###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", "-", "-", ""]}
{"id": 584, "alpha2": "mh", "alpha3": "mhl", "name": "Маршалловы Острова", "phoneCode": "+692", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 484, "alpha2": "mx", "alpha3": "mex", "name": "Мексика", "phoneCode": "+52", "phoneDigits": 10, "phoneMask": "## #### ####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 583, "alpha2": "fm", "alpha3": "fsm", "name": "Микронезия", "phoneCode": "+691", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 508, "alpha2": "mz", "alpha3": "moz", "name": "Мозамбик", "phoneCode": "+258", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 498, "alpha2": "md", "alpha3": "mda", "name": "Молдова", "phoneCode": "+373", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 492, "alpha2": "mc", "alpha3": "mco", "name": "Монако", "phoneCode": "+377", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 496, "alpha2": "mn", "alpha3": "mng", "name": "Монголия", "phoneCode": "+976", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 104, "alpha2": "mm", "alpha3": "mmr", "name": "Мьянма", "phoneCode": "+95", "phoneDigits": 9, "phoneMask": "# ### ####", "phoneGroupSizes": [1, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 516, "alpha2": "na", "alpha3": "nam", "name": "Намибия", "phoneCode": "+264", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 520, "alpha2": "nr", "alpha3": "nru", "name": "Науру", "phoneCode": "+674", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 524, "alpha2": "np", "alpha3": "npl", "name": "Непал", "phoneCode": "+977", "phoneDigits": 10, "phoneMask": "##-### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", "-", " ", ""]}
{"id": 562, "alpha2": "ne", "alpha3": "ner", "name": "Нигер", "phoneCode": "+227", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 566, "alpha2": "ng", "alpha3": "nga", "name": "Нигерия", "phoneCode": "+234", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 528, "alpha2": "nl", "alpha3": "nld", "name": "Нидерланды", "phoneCode": "+31", "phoneDigits": 9, "phoneMask": "# ## ## ## ##", "phoneGroupSizes": [1, 2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", " ", ""]}
{"id": 558, "alpha2": "ni", "alpha3": "nic", "name": "Никарагуа", "phoneCode": "+505", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 554, "alpha2": "nz", "alpha3": "nzl", "name": "Новая Зеландия", "phoneCode": "+64", "phoneDigits": 9, "phoneMask": "##-### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", "-", " ", ""]}
{"id": 578, "alpha2": "no", "alpha3": "nor", "name": "Норвегия", "phoneCode": "+47", "phoneDigits": 8, "phoneMask": "### ## ###", "phoneGroupSizes": [3, 2, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 784, "alpha2": "ae", "alpha3": "are", "name": "ОАЭ", "phoneCode": "+971", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 512, "alpha2": "om", "alpha3": "omn", "name": "Оман", "phoneCode": "+968", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 586, "alpha2": "pk", "alpha3": "pak", "name": "Пакистан", "phoneCode": "+92", "phoneDigits": 10, "phoneMask": "### #######", "phoneGroupSizes": [3, 7], "phoneGroupSeparators": ["", " ", ""]}
{"id": 585, "alpha2": "pw", "alpha3": "plw", "name": "Палау", "phoneCode": "+680", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 591, "alpha2": "pa", "alpha3": "pan", "name": "Панама", "phoneCode": "+507", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 598, "alpha2": "pg", "alpha3": "png", "name": "Папуа — Новая Гвинея", "phoneCode": "+675", "phoneDigits": 8, "phoneMask": "### ## ###", "phoneGroupSizes": [3, 2, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 600, "alpha2": "py", "alpha3": "pry", "name": "Парагвай", "phoneCode": "+595", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 604, "alpha2": "pe", "alpha3": "per", "name": "Перу", "phoneCode": "+51", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 616, "alpha2": "pl", "alpha3": "pol", "name": "Польша", "phoneCode": "+48", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 620, "alpha2": "pt", "alpha3": "prt", "name": "Португалия", "phoneCode": "+351", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 178, "alpha2": "cg", "alpha3": "cog", "name": "Республика Конго", "phoneCode": "+242", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 410, "alpha2": "kr", "alpha3": "kor", "name": "Республика Корея", "phoneCode": "+82", "phoneDigits": 10, "phoneMask": "##-####-####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", "-", "-", ""]}
{"id": 643, "alpha2": "ru", "alpha3": "rus", "name": "Россия", "phoneCode": "+7", "phoneDigits": 10, "phoneMask": "(###) ###-##-##", "phoneGroupSizes": [3, 3, 2, 2], "phoneGroupSeparators": ["(", ") ", "-", "-", ""]}
{"id": 646, "alpha2": "rw", "alpha3": "rwa", "name": "Руанда", "phoneCode": "+250", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 642, "alpha2": "ro", "alpha3": "rou", "name": "Румыния", "phoneCode": "+40", "phoneDigits": 10, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 222, "alpha2": "sv", "alpha3": "slv", "name": "Сальвадор", "phoneCode": "+503", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 882, "alpha2": "ws", "alpha3": "wsm", "name": "Самоа", "phoneCode": "+685", "phoneDigits": 7, "phoneMask": "## #####", "phoneGroupSizes": [2, 5], "phoneGroupSeparators": ["", " ", ""]}
{"id": 674, "alpha2": "sm", "alpha3": "smr", "name": "Сан-Марино", "phoneCode": "+378", "phoneDigits": 10, "phoneMask": "## ## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", " ", ""]}
{"id": 678, "alpha2": "st", "alpha3": "stp", "name": "Сан-Томе и Принсипи", "phoneCode": "+239", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 682, "alpha2": "sa", "alpha3": "sau", "name": "Саудовская Аравия", "phoneCode": "+966", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 690, "alpha2": "sc", "alpha3": "syc", "name": "Сейшельские Острова", "phoneCode": "+248", "phoneDigits": 7, "phoneMask": "# ### ###", "phoneGroupSizes": [1, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 686, "alpha2": "sn", "alpha3": "sen", "name": "Сенегал", "phoneCode": "+221", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 670, "alpha2": "vc", "alpha3": "vct", "name": "Сент-Винсент и Гренадины", "phoneCode": "+1784", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 659, "alpha2": "kn", "alpha3": "kna", "name": "Сент-Китс и Невис", "phoneCode": "+1869", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 662, "alpha2": "lc", "alpha3": "lca", "name": "Сент-Люсия", "phoneCode": "+1758", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 688, "alpha2": "rs", "alpha3": "srb", "name": "Сербия", "phoneCode": "+381", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 702, "alpha2": "sg", "alpha3": "sgp", "name": "Сингапур", "phoneCode": "+65", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 760, "alpha2": "sy", "alpha3": "syr", "name": "Сирия", "phoneCode": "+963", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 703, "alpha2": "sk", "alpha3": "svk", "name": "Словакия", "phoneCode": "+421", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 705, "alpha2": "si", "alpha3": "svn", "name": "Словения", "phoneCode": "+386", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 90, "alpha2": "sb", "alpha3": "slb", "name": "Соломоновы Острова", "phoneCode": "+677", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 706, "alpha2": "so", "alpha3": "som", "name": "Сомали", "phoneCode": "+252", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 729, "alpha2": "sd", "alpha3": "sdn", "name": "Судан", "phoneCode": "+249", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 740, "alpha2": "sr", "alpha3": "sur", "name": "Суринам", "phoneCode": "+597", "phoneDigits": 7, "phoneMask": "###-####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", "-", ""]}
{"id": 840, "alpha2": "us", "alpha3": "usa", "name": "США", "phoneCode": "+1", "phoneDigits": 10, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 694, "alpha2": "sl", "alpha3": "sle", "name": "Сьерра-Леоне", "phoneCode": "+232", "phoneDigits": 8, "phoneMask": "## ######", "phoneGroupSizes": [2, 6], "phoneGroupSeparators": ["", " ", ""]}
{"id": 762, "alpha2": "tj", "alpha3": "tjk", "name": "Таджикистан", "phoneCode": "+992", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 764, "alpha2": "th", "alpha3": "tha", "name": "Таиланд", "phoneCode": "+66", "phoneDigits": 9, "phoneMask": "##-### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", "-", " ", ""]}
{"id": 834, "alpha2": "tz", "alpha3": "tza", "name": "Танзания", "phoneCode": "+255", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 768, "alpha2": "tg", "alpha3": "tgo", "name": "Того", "phoneCode": "+228", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 776, "alpha2": "to", "alpha3": "ton", "name": "Тонга", "phoneCode": "+676", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 780, "alpha2": "tt", "alpha3": "tto", "name": "Тринидад и Тобаго", "phoneCode": "+1868", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 798, "alpha2": "tv", "alpha3": "tuv", "name": "Тувалу", "phoneCode": "+688", "phoneDigits": 6, "phoneMask": "######", "phoneGroupSizes": [6], "phoneGroupSeparators": ["", ""]}
{"id": 788, "alpha2": "tn", "alpha3": "tun", "name": "Тунис", "phoneCode": "+216", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 795, "alpha2": "tm", "alpha3": "tkm", "name": "Туркменистан", "phoneCode": "+993", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 792, "alpha2": "tr", "alpha3": "tur", "name": "Турция", "phoneCode": "+90", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 800, "alpha2": "ug", "alpha3": "uga", "name": "Уганда", "phoneCode": "+256", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 860, "alpha2": "uz", "alpha3": "uzb", "name": "Узбекистан", "phoneCode": "+998", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 804, "alpha2": "ua", "alpha3": "ukr", "name": "Украина", "phoneCode": "+380", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 858, "alpha2": "uy", "alpha3": "ury", "name": "Уругвай", "phoneCode": "+598", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 242, "alpha2": "fj", "alpha3": "fji", "name": "Фиджи", "phoneCode": "+679", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 608, "alpha2": "ph", "alpha3": "phl", "name": "Филиппины", "phoneCode": "+63", "phoneDigits": 10, "phoneMask": "### ### ####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 246, "alpha2": "fi", "alpha3": "fin", "name": "Финляндия", "phoneCode": "+358", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 250, "alpha2": "fr", "alpha3": "fra", "name": "Франция", "phoneCode": "+33", "phoneDigits": 9, "phoneMask": "# ## ## ## ##", "phoneGroupSizes": [1, 2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", " ", ""]}
{"id": 191, "alpha2": "hr", "alpha3": "hrv", "name": "Хорватия", "phoneCode": "+385", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 140, "alpha2": "cf", "alpha3": "caf", "name": "ЦАР", "phoneCode": "+236", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 148, "alpha2": "td", "alpha3": "tcd", "name": "Чад", "phoneCode": "+235", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 499, "alpha2": "me", "alpha3": "mne", "name": "Черногория", "phoneCode": "+382", "phoneDigits": 8, "phoneMask": "## ### ###", "phoneGroupSizes": [2, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 203, "alpha2": "cz", "alpha3": "cze", "name": "Чехия", "phoneCode": "+420", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 152, "alpha2": "cl", "alpha3": "chl", "name": "Чили", "phoneCode": "+56", "phoneDigits": 9, "phoneMask": "# #### ####", "phoneGroupSizes": [1, 4, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 756, "alpha2": "ch", "alpha3": "che", "name": "Швейцария", "phoneCode": "+41", "phoneDigits": 9, "phoneMask": "## ### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 752, "alpha2": "se", "alpha3": "swe", "name": "Швеция", "phoneCode": "+46", "phoneDigits": 9, "phoneMask": "##-### ## ##", "phoneGroupSizes": [2, 3, 2, 2], "phoneGroupSeparators": ["", "-", " ", " ", ""]}
{"id": 144, "alpha2": "lk", "alpha3": "lka", "name": "Шри-Ланка", "phoneCode": "+94", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 218, "alpha2": "ec", "alpha3": "ecu", "name": "Эквадор", "phoneCode": "+593", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 226, "alpha2": "gq", "alpha3": "gnq", "name": "Экваториальная Гвинея", "phoneCode": "+240", "phoneDigits": 9, "phoneMask": "### ## ## ##", "phoneGroupSizes": [3, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 232, "alpha2": "er", "alpha3": "eri", "name": "Эритрея", "phoneCode": "+291", "phoneDigits": 7, "phoneMask": "### ####", "phoneGroupSizes": [3, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 748, "alpha2": "sz", "alpha3": "swz", "name": "Эсватини", "phoneCode": "+268", "phoneDigits": 8, "phoneMask": "## ## ## ##", "phoneGroupSizes": [2, 2, 2, 2], "phoneGroupSeparators": ["", " ", " ", " ", ""]}
{"id": 233, "alpha2": "ee", "alpha3": "est", "name": "Эстония", "phoneCode": "+372", "phoneDigits": 8, "phoneMask": "#### ####", "phoneGroupSizes": [4, 4], "phoneGroupSeparators": ["", " ", ""]}
{"id": 231, "alpha2": "et", "alpha3": "eth", "name": "Эфиопия", "phoneCode": "+251", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 710, "alpha2": "za", "alpha3": "zaf", "name": "ЮАР", "phoneCode": "+27", "phoneDigits": 9, "phoneMask": "## ### ####", "phoneGroupSizes": [2, 3, 4], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 728, "alpha2": "ss", "alpha3": "ssd", "name": "Южный Судан", "phoneCode": "+211", "phoneDigits": 9, "phoneMask": "### ### ###", "phoneGroupSizes": [3, 3, 3], "phoneGroupSeparators": ["", " ", " ", ""]}
{"id": 388, "alpha2": "jm", "alpha3": "jam", "name": "Ямайка", "phoneCode": "+1876", "phoneDigits": 7, "phoneMask": "(###) ###-####", "phoneGroupSizes": [3, 3, 4], "phoneGroupSeparators": ["(", ") ", "-", ""]}
{"id": 392, "alpha2": "jp", "alpha3": "jpn", "name": "Япония", "phoneCode": "+81", "phoneDigits": 10, "phoneMask": "##-####-####", "phoneGroupSizes": [2, 4, 4], "phoneGroupSeparators": ["", "-", "-", ""]}
]''';

import 'package:flutter/services.dart';

import '../../../core/config/countries.dart';

class PhoneInputFormatter extends TextInputFormatter {
  final CountryName country;
  PhoneInputFormatter(this.country);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (newValue.text.length < oldValue.text.length) {
      final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
      if (text.length == oldDigits.length && text.isNotEmpty) {
        text = text.substring(0, text.length - 1);
      }
    }

    if (text.length > country.phoneDigits) {
      text = text.substring(0, country.phoneDigits);
    }

    final buffer = StringBuffer();
    int digitIdx = 0;

    for (int i = 0; i < country.phoneGroupSizes.length; i++) {
      if (digitIdx >= text.length) break;

      buffer.write(country.phoneGroupSeparators[i]);

      final groupSize = country.phoneGroupSizes[i];
      final remainingDigits = text.length - digitIdx;
      final digitsToTake = remainingDigits < groupSize
          ? remainingDigits
          : groupSize;

      buffer.write(text.substring(digitIdx, digitIdx + digitsToTake));
      digitIdx += digitsToTake;
    }

    if (digitIdx == text.length && text.length == country.phoneDigits) {
      if (country.phoneGroupSeparators.length >
          country.phoneGroupSizes.length) {
        buffer.write(country.phoneGroupSeparators.last);
      }
    }

    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

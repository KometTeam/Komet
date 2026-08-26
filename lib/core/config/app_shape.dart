import 'package:flutter/material.dart';

class AppShape {
  static const double card = 20;
  static const double button = 14;
  static const double sheet = 24;
  static const double dialog = 24;
  static const double pill = 100;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );

  static const RoundedRectangleBorder buttonBorder = RoundedRectangleBorder(
    borderRadius: buttonRadius,
  );
  static const RoundedRectangleBorder dialogBorder = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(dialog)),
  );
  static const RoundedRectangleBorder sheetBorder = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(sheet)),
  );
}

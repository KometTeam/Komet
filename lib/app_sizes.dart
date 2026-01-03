import 'package:flutter/material.dart';

/// скругление🔴🔴🔴 углов
class AppRadius {
  AppRadius._();

  ///прогресс-бары
  static const double xs = 2.0;

  ///элементы, чипы, теги
  static const double sm = 8.0;

  ///карточки, поля ввода, кнопки
  static const double md = 12.0;

  ///модальные окна, большие карточки
  static const double lg = 16.0;

  ///панели, всплывающие меню
  static const double xl = 20.0;

  ///почему не ххх
  static const double xxl = 24.0;

  ///скруглённые контейнеры
  static const double round = 28.0;

  /// круг
  static const double circle = 999.0;

  static BorderRadius get xsBorder => BorderRadius.circular(xs);
  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
  static BorderRadius get xxlBorder => BorderRadius.circular(xxl);
  static BorderRadius get roundBorder => BorderRadius.circular(round);
  static BorderRadius get circleBorder => BorderRadius.circular(circle);
}

/// Accessibility constants (WCAG 2.1 compliance)
class AppAccessibility {
  AppAccessibility._();

  /// Minimum touch target size (WCAG 2.1 AAA - 44x44 dp)
  static const double minTouchTarget = 44.0;

  /// Minimum interactive element size
  static const double minInteractiveSize = 48.0;

  /// Button minimum height
  static const double buttonMinHeight = 48.0;

  /// IconButton minimum size
  static const double iconButtonMinSize = 48.0;

  /// ListTile minimum height
  static const double listTileMinHeight = 56.0;

  /// Chip minimum height
  static const double chipMinHeight = 32.0;

  /// Constraint for minimum touch target
  static const BoxConstraints touchTargetConstraints = BoxConstraints(
    minWidth: minTouchTarget,
    minHeight: minTouchTarget,
  );

  /// Constraint for interactive elements
  static const BoxConstraints interactiveConstraints = BoxConstraints(
    minWidth: minInteractiveSize,
    minHeight: minInteractiveSize,
  );
}

/// Elevation values (Material 3 elevation system)
class AppElevation {
  AppElevation._();

  /// Level 0: no elevation
  static const double level0 = 0.0;

  /// Level 1: subtle elevation (cards, chips)
  static const double level1 = 1.0;

  /// Level 2: standard elevation (buttons, FAB resting)
  static const double level2 = 3.0;

  /// Level 3: raised elevation (app bar, navigation rail)
  static const double level3 = 6.0;

  /// Level 4: high elevation (navigation drawer)
  static const double level4 = 8.0;

  /// Level 5: highest elevation (dialogs, modals)
  static const double level5 = 12.0;
}

/// отсуты и промежутки
class AppSpacing {
  AppSpacing._();

  ///отступ между иконкой и текстом
  static const double xxs = 2.0;

  ///отступ внутри компактных элементов(каких не ебу)
  static const double xs = 4.0;

  ///отступ в кнопках/между строками
  static const double sm = 6.0;

  ///стандартный отступ
  static const double md = 8.0;

  ///отступ где то блять у меня амнезия
  static const double lg = 10.0;

  ///отступ в карточках и списках
  static const double xl = 12.0;

  ///отступ экрана
  static const double xxl = 16.0;

  ///отступ между секциями
  static const double xxxl = 20.0;

  static const EdgeInsets allXs = EdgeInsets.all(xs);
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  static const EdgeInsets allXl = EdgeInsets.all(xl);
  static const EdgeInsets allXxl = EdgeInsets.all(xxl);
  static const EdgeInsets allXxxl = EdgeInsets.all(xxxl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets horizontalXxl = EdgeInsets.symmetric(horizontal: xxl);
  static const EdgeInsets horizontalXxxl = EdgeInsets.symmetric(
    horizontal: xxxl,
  );

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

///размеры шрифтов
class AppFontSize {
  AppFontSize._();

  ///метки времени, статусы
  static const double xs = 10.0;

  ///вторичный текст, подписи
  static const double sm = 11.0;

  ///мелкий текст, версия приложения
  static const double md = 12.0;

  ///основной текст сообщений
  static const double body = 13.0;

  ///текст кнопок, заголовки списков
  static const double lg = 14.0;

  ///заголовки карточек
  static const double xl = 16.0;

  ///заголовки экранов
  static const double title = 22.0;

  ///заголовки, эмодзи
  static const double headline = 24.0;
}

/// размеры иконок
class AppIconSize {
  AppIconSize._();

  ///мини иконо4ки
  static const double xs = 14.0;

  /// иконки статусов
  static const double sm = 16.0;

  /// иконки в списках
  static const double md = 20.0;

  ///иконки в AppBar и кнопках
  static const double lg = 24.0;

  ///акцентные иконки
  static const double xl = 28.0;

  ///большие иконки
  static const double xxl = 32.0;
}
